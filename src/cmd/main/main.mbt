///|
enum Input {
  Stdin
  File(String)
}

///|
fn main {
  let args = @env.args()
  let input = if args.length() > 1 {
    match args[1] {
      "-" => Stdin
      path => File(path)
    }
  } else {
    Stdin
  }
  let (content, uri) = match input {
    Stdin => {
      let content = try {
        @fs.read_file_to_string("/dev/stdin")
      } catch {
        @fs.IOError(msg) => {
          println("Error reading stdin: \{msg}")
          return
        }
      }
      (content, "stdin")
    }
    File(path) => {
      let content = try {
        @fs.read_file_to_string(path)
      } catch {
        @fs.IOError(msg) => {
          println("Error reading \{path}: \{msg}")
          return
        }
      }
      (content, path)
    }
  }
  let src = @lib.Source::from_string(content, uri=uri)
  let doc = try {
    @lib.parse(src)
  } catch {
    @lib.UnexpectedToken(message~, ..) => {
      println(message)
      return
    }
    @lib.UnexpectedEof(message~, ..) => {
      println(message)
      return
    }
    @lib.InconsistentTableCells(message~, ..) => {
      println(message)
      return
    }
    @lib.CompositeError(errors~) => {
      for e in errors {
        match e {
          @lib.UnexpectedToken(message~, ..)
          | @lib.UnexpectedEof(message~, ..)
          | @lib.InconsistentTableCells(message~, ..) => println(message)
          _ => ()
        }
      }
      return
    }
  }
  println(doc.to_json().stringify(indent=2))
}
