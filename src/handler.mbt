///|
/// A handler for push-based (SAX-style) parsing events.
///
/// All methods have default no-op implementations.
/// Override only the methods for events you want to handle.
///
/// The parser drives the process, calling handler methods
/// as it encounters structural elements.
pub(open) trait GherkinHandler {
  on_document(Self) -> Unit = _
  on_end_document(Self) -> Unit = _
  on_feature(Self, FeatureEvent) -> Unit = _
  on_end_feature(Self) -> Unit = _
  on_rule(Self, RuleEvent) -> Unit = _
  on_end_rule(Self) -> Unit = _
  on_background(Self, BackgroundEvent) -> Unit = _
  on_end_background(Self) -> Unit = _
  on_scenario(Self, ScenarioEvent) -> Unit = _
  on_end_scenario(Self) -> Unit = _
  on_step(Self, StepEvent) -> Unit = _
  on_examples(Self, ExamplesEvent) -> Unit = _
  on_tag(Self, TagEvent) -> Unit = _
  on_comment(Self, CommentEvent) -> Unit = _
  on_doc_string(Self, DocStringEvent) -> Unit = _
  on_data_table(Self, DataTableEvent) -> Unit = _
}

///|
impl GherkinHandler with on_document(_self) {
  ()
}

///|
impl GherkinHandler with on_end_document(_self) {
  ()
}

///|
impl GherkinHandler with on_feature(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_end_feature(_self) {
  ()
}

///|
impl GherkinHandler with on_rule(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_end_rule(_self) {
  ()
}

///|
impl GherkinHandler with on_background(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_end_background(_self) {
  ()
}

///|
impl GherkinHandler with on_scenario(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_end_scenario(_self) {
  ()
}

///|
impl GherkinHandler with on_step(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_examples(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_tag(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_comment(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_doc_string(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_data_table(_self, _e) {
  ()
}

///|
/// Parse Gherkin input, pushing events to a handler.
#declaration_only
pub fn parse_with_handler(
  input : String,
  handler : &GherkinHandler,
  uri? : String,
) -> Unit raise ParseError {
  ...
}
