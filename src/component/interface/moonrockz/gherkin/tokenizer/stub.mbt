///|
/// Tokenize Gherkin source text into a JSON token array.
/// Returns the JSON string on success, or an error message on failure.
pub fn tokenize(source : String) -> Result[String, String] {
  let src = @lib.Source::from_string(source)
  let tokens = @lib.tokenize(src)
  Ok(tokens.to_json().stringify())
}
