///|
/// Convert a JSON AST back to formatted Gherkin text.
/// Returns the Gherkin string on success, or an error message on failure.
pub fn write(json_ast : String) -> Result[String, String] {
  try {
    let json = @json.parse(json_ast)
    let doc : @lib.GherkinDocument = @json.from_json(json)
    Ok(@lib.write(doc))
  } catch {
    @json.JsonDecodeError(e) => Err(e.1)
    _ => Err("invalid JSON input")
  }
}
