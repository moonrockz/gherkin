///|
enum Input {
  Stdin
  File(String)
}

///|
fn eprintln(msg : String) -> Unit {
  @fs.write_string_to_file("/dev/stderr", msg + "\n") catch {
    _ => println(msg)
  }
}

///|
fn die(msg : String) -> Unit {
  eprintln(msg)
  @sys.exit(1)
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
      let content = @fs.read_file_to_string("/dev/stdin") catch {
        @fs.IOError(msg) => {
          die("Error reading stdin: \{msg}")
          return
        }
      }
      (content, "stdin")
    }
    File(path) => {
      let content = @fs.read_file_to_string(path) catch {
        @fs.IOError(msg) => {
          die("Error reading \{path}: \{msg}")
          return
        }
      }
      (content, path)
    }
  }
  let src = @lib.Source::from_string(content, uri~)
  let doc = @lib.parse(src) catch {
    @lib.UnexpectedToken(message~, ..) => {
      die(message)
      return
    }
    @lib.UnexpectedEof(message~, ..) => {
      die(message)
      return
    }
    @lib.InconsistentTableCells(message~, ..) => {
      die(message)
      return
    }
    @lib.CompositeError(errors~) => {
      for e in errors {
        match e {
          @lib.UnexpectedToken(message~, ..)
          | @lib.UnexpectedEof(message~, ..)
          | @lib.InconsistentTableCells(message~, ..) => eprintln(message)
          _ => ()
        }
      }
      @sys.exit(1)
      return
    }
  }
  println(doc.to_json().stringify(indent=2))
}
