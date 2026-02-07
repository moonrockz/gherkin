///|
/// Parse Gherkin source text into a JSON AST.
/// Returns the JSON string on success, or an error message on failure.
pub fn parse(source : String) -> Result[String, String] {
  let src = @lib.Source::from_string(source)
  try {
    let doc = @lib.parse(src)
    Ok(doc.to_json().stringify())
  } catch {
    @lib.UnexpectedToken(message~, ..) => Err(message)
    @lib.UnexpectedEof(message~, ..) => Err(message)
    @lib.InconsistentTableCells(message~, ..) => Err(message)
    @lib.CompositeError(errors~) => {
      let msgs : Array[String] = []
      for e in errors {
        match e {
          @lib.UnexpectedToken(message~, ..)
          | @lib.UnexpectedEof(message~, ..)
          | @lib.InconsistentTableCells(message~, ..) => msgs.push(message)
          _ => msgs.push("unknown error")
        }
      }
      Err(msgs.join("\n"))
    }
  }
}
