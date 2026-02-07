///|
/// A feature start event. Children arrive as subsequent events.
pub struct FeatureEvent {
  location : Location
  tags : Array[Tag]
  language : String
  keyword : String
  name : String
  description : String
} derive(Show, Eq)

///|
/// A rule start event. Children arrive as subsequent events.
pub struct RuleEvent {
  location : Location
  tags : Array[Tag]
  keyword : String
  name : String
  description : String
} derive(Show, Eq)

///|
/// A background start event. Steps arrive as subsequent events.
pub struct BackgroundEvent {
  location : Location
  keyword : String
  name : String
  description : String
} derive(Show, Eq)

///|
/// A scenario start event. Steps/examples arrive as subsequent events.
pub struct ScenarioEvent {
  location : Location
  tags : Array[Tag]
  kind : ScenarioKind
  keyword : String
  name : String
  description : String
} derive(Show, Eq)

///|
/// A step event (leaf -- no children).
pub struct StepEvent {
  location : Location
  keyword : String
  keyword_type : KeywordType
  text : String
} derive(Show, Eq)

///|
/// A doc string event (leaf).
pub struct DocStringEvent {
  location : Location
  media_type : String?
  content : String
  delimiter : String
} derive(Show, Eq)

///|
/// A data table event (self-contained with all rows).
pub struct DataTableEvent {
  location : Location
  rows : Array[TableRow]
} derive(Show, Eq)

///|
/// An examples table event (self-contained with header + body).
pub struct ExamplesEvent {
  location : Location
  tags : Array[Tag]
  keyword : String
  name : String
  description : String
  table_header : TableRow?
  table_body : Array[TableRow]
} derive(Show, Eq)

///|
/// A tag event (leaf).
pub struct TagEvent {
  location : Location
  name : String
} derive(Show, Eq)

///|
/// A comment event (leaf).
pub struct CommentEvent {
  location : Location
  text : String
} derive(Show, Eq)

///|
/// Events emitted during pull-based parsing.
/// Follows nested lifecycle: Document -> Feature -> (Background|Scenario|Rule) -> Steps -> End*
pub enum GherkinEvent {
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
} derive(Show, Eq)
