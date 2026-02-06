///|
/// A visitor for traversing a GherkinDocument AST.
///
/// All methods have default no-op implementations.
/// Override only the methods for node types you want to process.
///
/// The data structure controls traversal order (depth-first, document order).
/// Use `GherkinDocument::accept` to begin traversal.
pub(open) trait GherkinVisitor {
  visit_document(Self, GherkinDocument) -> Unit = _
  visit_feature(Self, Feature) -> Unit = _
  visit_rule(Self, Rule) -> Unit = _
  visit_background(Self, Background) -> Unit = _
  visit_scenario(Self, Scenario) -> Unit = _
  visit_step(Self, Step) -> Unit = _
  visit_doc_string(Self, DocString) -> Unit = _
  visit_data_table(Self, DataTable) -> Unit = _
  visit_examples(Self, Examples) -> Unit = _
  visit_tag(Self, Tag) -> Unit = _
  visit_comment(Self, Comment) -> Unit = _
  visit_table_row(Self, TableRow) -> Unit = _
}

///|
impl GherkinVisitor with visit_document(_self, _doc) {
  ()
}

///|
impl GherkinVisitor with visit_feature(_self, _f) {
  ()
}

///|
impl GherkinVisitor with visit_rule(_self, _r) {
  ()
}

///|
impl GherkinVisitor with visit_background(_self, _bg) {
  ()
}

///|
impl GherkinVisitor with visit_scenario(_self, _s) {
  ()
}

///|
impl GherkinVisitor with visit_step(_self, _s) {
  ()
}

///|
impl GherkinVisitor with visit_doc_string(_self, _ds) {
  ()
}

///|
impl GherkinVisitor with visit_data_table(_self, _dt) {
  ()
}

///|
impl GherkinVisitor with visit_examples(_self, _e) {
  ()
}

///|
impl GherkinVisitor with visit_tag(_self, _t) {
  ()
}

///|
impl GherkinVisitor with visit_comment(_self, _c) {
  ()
}

///|
impl GherkinVisitor with visit_table_row(_self, _r) {
  ()
}

///|
/// Accept a visitor on a GherkinDocument, traversing the entire tree
/// in depth-first document order.
#declaration_only
pub fn GherkinDocument::accept(
  self : GherkinDocument,
  visitor : &GherkinVisitor,
) -> Unit {
  ...
}

///|
#declaration_only
pub fn Feature::accept(self : Feature, visitor : &GherkinVisitor) -> Unit {
  ...
}

///|
#declaration_only
pub fn Rule::accept(self : Rule, visitor : &GherkinVisitor) -> Unit {
  ...
}

///|
#declaration_only
pub fn Background::accept(self : Background, visitor : &GherkinVisitor) -> Unit {
  ...
}

///|
#declaration_only
pub fn Scenario::accept(self : Scenario, visitor : &GherkinVisitor) -> Unit {
  ...
}

///|
#declaration_only
pub fn Step::accept(self : Step, visitor : &GherkinVisitor) -> Unit {
  ...
}

///|
#declaration_only
pub fn Examples::accept(self : Examples, visitor : &GherkinVisitor) -> Unit {
  ...
}

///|
#declaration_only
pub fn DataTable::accept(self : DataTable, visitor : &GherkinVisitor) -> Unit {
  ...
}

///|
#declaration_only
pub fn DocString::accept(self : DocString, visitor : &GherkinVisitor) -> Unit {
  ...
}

///|
#declaration_only
pub fn Tag::accept(self : Tag, visitor : &GherkinVisitor) -> Unit {
  ...
}

///|
#declaration_only
pub fn Comment::accept(self : Comment, visitor : &GherkinVisitor) -> Unit {
  ...
}

///|
#declaration_only
pub fn TableRow::accept(self : TableRow, visitor : &GherkinVisitor) -> Unit {
  ...
}
