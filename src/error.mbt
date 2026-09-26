///|
/// Errors that can occur during Gherkin parsing.
// `CompositeError` is part of the public error API for callers that aggregate
// several parse failures.
#warnings("-unused_constructor")
pub suberror ParseError {
  /// Unexpected token encountered during parsing.
  UnexpectedToken(message~ : String, location~ : Location)
  /// Unexpected end of file.
  UnexpectedEof(message~ : String, location~ : Location)
  /// Inconsistent cell count in a data table.
  InconsistentTableCells(message~ : String, location~ : Location)
  /// A composite of multiple parse errors from a single document.
  CompositeError(errors~ : Array[ParseError])
}
