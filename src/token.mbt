///|
/// A token produced by the lexer, representing a classified source line.
/// Each variant carries its Location and the relevant parsed fragments.
pub enum Token {
  FeatureLine(Location, String, String)
  RuleLine(Location, String, String)
  BackgroundLine(Location, String, String)
  ScenarioLine(Location, String, String)
  ExamplesLine(Location, String, String)
  StepLine(Location, String, KeywordType, String)
  DocStringSeparator(Location, String, String?)
  TableRow(Location, Array[String])
  TagLine(Location, Array[String])
  Comment(Location, String)
  Language(Location, String)
  Empty(Location)
  Other(Location, String)
  Eof(Location)
} derive(Show, Eq)

///|
/// Internal state tracked between lines during tokenization.
/// Gherkin is mostly stateless line-by-line except inside doc strings.
pub enum LexerState {
  Normal
  InDocString(String)
} derive(Show, Eq)
