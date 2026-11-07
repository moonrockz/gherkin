///|
/// A feature start event. Children arrive as subsequent events.
#derive(Debug, Eq)
pub(all) struct FeatureEvent {
  location : Location
  tags : Array[Tag]
  language : String
  keyword : String
  name : String
  description : String
}

///|
/// A rule start event. Children arrive as subsequent events.
#derive(Debug, Eq)
pub(all) struct RuleEvent {
  location : Location
  tags : Array[Tag]
  keyword : String
  name : String
  description : String
}

///|
/// A background start event. Steps arrive as subsequent events.
#derive(Debug, Eq)
pub(all) struct BackgroundEvent {
  location : Location
  keyword : String
  name : String
  description : String
}

///|
/// A scenario start event. Steps/examples arrive as subsequent events.
#derive(Debug, Eq)
pub(all) struct ScenarioEvent {
  location : Location
  tags : Array[Tag]
  kind : ScenarioKind
  keyword : String
  name : String
  description : String
}

///|
/// A step event (leaf -- no children).
#derive(Debug, Eq)
pub(all) struct StepEvent {
  location : Location
  keyword : String
  keyword_type : KeywordType
  text : String
}

///|
/// A doc string event (leaf).
#derive(Debug, Eq)
pub(all) struct DocStringEvent {
  location : Location
  media_type : String?
  content : String
  delimiter : String
}

///|
/// A data table event (self-contained with all rows).
#derive(Debug, Eq)
pub(all) struct DataTableEvent {
  location : Location
  rows : Array[TableRow]
}

///|
/// An examples table event (self-contained with header + body).
#derive(Debug, Eq)
pub(all) struct ExamplesEvent {
  location : Location
  tags : Array[Tag]
  keyword : String
  name : String
  description : String
  table_header : TableRow?
  table_body : Array[TableRow]
}

///|
/// A tag event (leaf).
#derive(Debug, Eq)
pub(all) struct TagEvent {
  location : Location
  name : String
}

///|
/// A comment event (leaf).
#derive(Debug, Eq)
pub(all) struct CommentEvent {
  location : Location
  text : String
}

///|
/// Events emitted during pull-based parsing.
/// Follows nested lifecycle: Document -> Feature -> (Background|Scenario|Rule) -> Steps -> End*
#derive(Debug, Eq)
pub(all) enum GherkinEvent {
  DocumentStart
  DocumentEnd
  FeatureStart(FeatureEvent)
  FeatureEnd
  RuleStart(RuleEvent)
  RuleEnd
  BackgroundStart(BackgroundEvent)
  BackgroundEnd
  ScenarioStart(ScenarioEvent)
  ScenarioEnd
  Step(StepEvent)
  DocString(DocStringEvent)
  DataTable(DataTableEvent)
  Examples(ExamplesEvent)
  Tag(TagEvent)
  Comment(CommentEvent)
}

///|
pub extend FeatureEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FeatureEvent with Eq::{not_equal, equal}

///|
pub extend RuleEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RuleEvent with Eq::{not_equal, equal}

///|
pub extend BackgroundEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BackgroundEvent with Eq::{not_equal, equal}

///|
pub extend ScenarioEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ScenarioEvent with Eq::{not_equal, equal}

///|
pub extend StepEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend StepEvent with Eq::{not_equal, equal}

///|
pub extend DocStringEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DocStringEvent with Eq::{not_equal, equal}

///|
pub extend DataTableEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DataTableEvent with Eq::{not_equal, equal}

///|
pub extend ExamplesEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ExamplesEvent with Eq::{not_equal, equal}

///|
pub extend TagEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TagEvent with Eq::{not_equal, equal}

///|
pub extend CommentEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CommentEvent with Eq::{not_equal, equal}

///|
pub extend GherkinEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend GherkinEvent with Eq::{not_equal, equal}
