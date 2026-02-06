///|
/// Parse a Gherkin document from a string.
/// The optional `uri` identifies the source (file path or URL).
#declaration_only
pub fn parse(input : String, uri? : String) -> GherkinDocument raise ParseError {
  ...
}
