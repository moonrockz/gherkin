///|
/// A location in the source text.
pub(all) struct Location {
  line : Int
  column : Int?
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Distinguishes a Scenario from a Scenario Outline.
pub(all) enum ScenarioKind {
  Scenario
  ScenarioOutline
} derive(Debug, Eq, ToJson, FromJson)

///|
/// The type of a step keyword, classifying its semantic role.
pub(all) enum KeywordType {
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
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A tag as it appears in source.
/// The `name` field includes the '@' prefix (e.g., "@smoke").
pub(all) struct Tag {
  location : Location
  name : String
  id : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A comment line in the source.
pub(all) struct Comment {
  location : Location
  text : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A single cell in a data table row.
pub(all) struct TableCell {
  location : Location
  value : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A row in a data table or examples table.
pub(all) struct TableRow {
  location : Location
  id : String
  cells : Array[TableCell]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A doc string step argument.
pub(all) struct DocString {
  location : Location
  media_type : String?
  content : String
  delimiter : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A data table step argument.
pub(all) struct DataTable {
  location : Location
  rows : Array[TableRow]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A step argument is either a DocString or a DataTable.
pub(all) enum StepArgument {
  DocString(DocString)
  DataTable(DataTable)
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A single step within a scenario or background.
pub(all) struct Step {
  location : Location
  keyword : String
  keyword_type : KeywordType
  text : String
  id : String
  argument : StepArgument?
} derive(Debug, Eq, ToJson, FromJson)

///|
/// An examples table attached to a scenario outline.
pub(all) struct Examples {
  location : Location
  tags : Array[Tag]
  keyword : String
  name : String
  description : String
  id : String
  table_header : TableRow?
  table_body : Array[TableRow]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A background section providing shared setup steps.
pub(all) struct Background {
  location : Location
  keyword : String
  name : String
  description : String
  id : String
  steps : Array[Step]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A scenario (or scenario outline) within a feature or rule.
pub(all) struct Scenario {
  location : Location
  tags : Array[Tag]
  kind : ScenarioKind
  keyword : String
  name : String
  description : String
  id : String
  steps : Array[Step]
  examples : Array[Examples]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A child element of a Rule: either a Background or a Scenario.
pub(all) enum RuleChild {
  Background(Background)
  Scenario(Scenario)
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A rule grouping related scenarios under a business rule.
pub(all) struct Rule {
  location : Location
  tags : Array[Tag]
  keyword : String
  name : String
  description : String
  id : String
  children : Array[RuleChild]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A child element of a Feature: Background, Scenario, or Rule.
pub(all) enum FeatureChild {
  Background(Background)
  Scenario(Scenario)
  Rule(Rule)
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A feature, the top-level structural element in a Gherkin document.
pub(all) struct Feature {
  location : Location
  tags : Array[Tag]
  language : String
  keyword : String
  name : String
  description : String
  children : Array[FeatureChild]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// The root of a parsed Gherkin document.
pub(all) struct GherkinDocument {
  source : Source
  feature : Feature?
  comments : Array[Comment]
} derive(Debug, Eq, ToJson, FromJson)

///|
/// Create an empty `GherkinDocument` with no feature and no comments.
pub fn GherkinDocument::empty() -> GherkinDocument {
  { source: Source::from_string(""), feature: None, comments: [], }
}

///|
pub extend Location with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Location with Eq::{not_equal, equal}

///|
pub extend Location with ToJson::{to_json}

///|
pub extend Location with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend ScenarioKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ScenarioKind with Eq::{not_equal, equal}

///|
pub extend ScenarioKind with ToJson::{to_json}

///|
pub extend ScenarioKind with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend KeywordType with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend KeywordType with Eq::{not_equal, equal}

///|
pub extend KeywordType with ToJson::{to_json}

///|
pub extend KeywordType with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend Tag with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Tag with Eq::{not_equal, equal}

///|
pub extend Tag with ToJson::{to_json}

///|
pub extend Tag with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend Comment with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Comment with Eq::{not_equal, equal}

///|
pub extend Comment with ToJson::{to_json}

///|
pub extend Comment with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend TableCell with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TableCell with Eq::{not_equal, equal}

///|
pub extend TableCell with ToJson::{to_json}

///|
pub extend TableCell with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend TableRow with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TableRow with Eq::{not_equal, equal}

///|
pub extend TableRow with ToJson::{to_json}

///|
pub extend TableRow with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend DocString with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DocString with Eq::{not_equal, equal}

///|
pub extend DocString with ToJson::{to_json}

///|
pub extend DocString with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend DataTable with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DataTable with Eq::{not_equal, equal}

///|
pub extend DataTable with ToJson::{to_json}

///|
pub extend DataTable with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend StepArgument with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend StepArgument with Eq::{not_equal, equal}

///|
pub extend StepArgument with ToJson::{to_json}

///|
pub extend StepArgument with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend Step with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Step with Eq::{not_equal, equal}

///|
pub extend Step with ToJson::{to_json}

///|
pub extend Step with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend Examples with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Examples with Eq::{not_equal, equal}

///|
pub extend Examples with ToJson::{to_json}

///|
pub extend Examples with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend Background with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Background with Eq::{not_equal, equal}

///|
pub extend Background with ToJson::{to_json}

///|
pub extend Background with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend Scenario with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Scenario with Eq::{not_equal, equal}

///|
pub extend Scenario with ToJson::{to_json}

///|
pub extend Scenario with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend RuleChild with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RuleChild with Eq::{not_equal, equal}

///|
pub extend RuleChild with ToJson::{to_json}

///|
pub extend RuleChild with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend Rule with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Rule with Eq::{not_equal, equal}

///|
pub extend Rule with ToJson::{to_json}

///|
pub extend Rule with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend FeatureChild with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FeatureChild with Eq::{not_equal, equal}

///|
pub extend FeatureChild with ToJson::{to_json}

///|
pub extend FeatureChild with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend Feature with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Feature with Eq::{not_equal, equal}

///|
pub extend Feature with ToJson::{to_json}

///|
pub extend Feature with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend GherkinDocument with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend GherkinDocument with Eq::{not_equal, equal}

///|
pub extend GherkinDocument with ToJson::{to_json}

///|
pub extend GherkinDocument with @moonbitlang/core/json.FromJson::{from_json}
