///|
/// A location in the source text.
pub(all) struct Location {
  line : Int
  column : Int?
} derive(Show, Eq, ToJson)

///|
/// Distinguishes a Scenario from a Scenario Outline.
pub enum ScenarioKind {
  Scenario
  ScenarioOutline
} derive(Show, Eq, ToJson)

///|
/// The type of a step keyword, classifying its semantic role.
pub enum KeywordType {
  /// "Given" -- establishes context
  Context
  /// "When" -- describes an action
  Action
  /// "Then" -- asserts an outcome
  Outcome
  /// "And", "But" -- continues the previous keyword type
  Conjunction
  /// "*" or unrecognized
  Unknown
} derive(Show, Eq, ToJson)

///|
/// A tag as it appears in source.
/// The `name` field includes the '@' prefix (e.g., "@smoke").
pub struct Tag {
  location : Location
  name : String
  id : String
} derive(Show, Eq, ToJson)

///|
/// A comment line in the source.
pub struct Comment {
  location : Location
  text : String
} derive(Show, Eq, ToJson)

///|
/// A single cell in a data table row.
pub struct TableCell {
  location : Location
  value : String
} derive(Show, Eq, ToJson)

///|
/// A row in a data table or examples table.
pub struct TableRow {
  location : Location
  id : String
  cells : Array[TableCell]
} derive(Show, Eq, ToJson)

///|
/// A doc string step argument.
pub struct DocString {
  location : Location
  media_type : String?
  content : String
  delimiter : String
} derive(Show, Eq, ToJson)

///|
/// A data table step argument.
pub struct DataTable {
  location : Location
  rows : Array[TableRow]
} derive(Show, Eq, ToJson)

///|
/// A step argument is either a DocString or a DataTable.
pub enum StepArgument {
  DocString(DocString)
  DataTable(DataTable)
} derive(Show, Eq, ToJson)

///|
/// A single step within a scenario or background.
pub struct Step {
  location : Location
  keyword : String
  keyword_type : KeywordType
  text : String
  id : String
  argument : StepArgument?
} derive(Show, Eq, ToJson)

///|
/// An examples table attached to a scenario outline.
pub struct Examples {
  location : Location
  tags : Array[Tag]
  keyword : String
  name : String
  description : String
  id : String
  table_header : TableRow?
  table_body : Array[TableRow]
} derive(Show, Eq, ToJson)

///|
/// A background section providing shared setup steps.
pub struct Background {
  location : Location
  keyword : String
  name : String
  description : String
  id : String
  steps : Array[Step]
} derive(Show, Eq, ToJson)

///|
/// A scenario (or scenario outline) within a feature or rule.
pub struct Scenario {
  location : Location
  tags : Array[Tag]
  kind : ScenarioKind
  keyword : String
  name : String
  description : String
  id : String
  steps : Array[Step]
  examples : Array[Examples]
} derive(Show, Eq, ToJson)

///|
/// A child element of a Rule: either a Background or a Scenario.
pub enum RuleChild {
  Background(Background)
  Scenario(Scenario)
} derive(Show, Eq, ToJson)

///|
/// A rule grouping related scenarios under a business rule.
pub struct Rule {
  location : Location
  tags : Array[Tag]
  keyword : String
  name : String
  description : String
  id : String
  children : Array[RuleChild]
} derive(Show, Eq, ToJson)

///|
/// A child element of a Feature: Background, Scenario, or Rule.
pub enum FeatureChild {
  Background(Background)
  Scenario(Scenario)
  Rule(Rule)
} derive(Show, Eq, ToJson)

///|
/// A feature, the top-level structural element in a Gherkin document.
pub struct Feature {
  location : Location
  tags : Array[Tag]
  language : String
  keyword : String
  name : String
  description : String
  children : Array[FeatureChild]
} derive(Show, Eq, ToJson)

///|
/// The root of a parsed Gherkin document.
pub struct GherkinDocument {
  source : Source
  feature : Feature?
  comments : Array[Comment]
} derive(Show, Eq, ToJson)

///|
/// Create an empty `GherkinDocument` with no feature and no comments.
pub fn GherkinDocument::empty() -> GherkinDocument {
  { source: Source::from_string(""), feature: None, comments: [] }
}
