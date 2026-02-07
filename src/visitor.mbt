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
pub fn GherkinDocument::accept(
  self : GherkinDocument,
  visitor : &GherkinVisitor,
) -> Unit {
  visitor.visit_document(self)
  for c in self.comments {
    c.accept(visitor)
  }
  match self.feature {
    Some(f) => f.accept(visitor)
    None => ()
  }
}

///|
pub fn Feature::accept(self : Feature, visitor : &GherkinVisitor) -> Unit {
  visitor.visit_feature(self)
  for t in self.tags {
    t.accept(visitor)
  }
  for child in self.children {
    match child {
      FeatureChild::Background(bg) => bg.accept(visitor)
      FeatureChild::Scenario(s) => s.accept(visitor)
      FeatureChild::Rule(r) => r.accept(visitor)
    }
  }
}

///|
pub fn Rule::accept(self : Rule, visitor : &GherkinVisitor) -> Unit {
  visitor.visit_rule(self)
  for t in self.tags {
    t.accept(visitor)
  }
  for child in self.children {
    match child {
      RuleChild::Background(bg) => bg.accept(visitor)
      RuleChild::Scenario(s) => s.accept(visitor)
    }
  }
}

///|
pub fn Background::accept(self : Background, visitor : &GherkinVisitor) -> Unit {
  visitor.visit_background(self)
  for s in self.steps {
    s.accept(visitor)
  }
}

///|
pub fn Scenario::accept(self : Scenario, visitor : &GherkinVisitor) -> Unit {
  visitor.visit_scenario(self)
  for t in self.tags {
    t.accept(visitor)
  }
  for s in self.steps {
    s.accept(visitor)
  }
  for e in self.examples {
    e.accept(visitor)
  }
}

///|
pub fn Step::accept(self : Step, visitor : &GherkinVisitor) -> Unit {
  visitor.visit_step(self)
  match self.argument {
    Some(StepArgument::DocString(ds)) => ds.accept(visitor)
    Some(StepArgument::DataTable(dt)) => dt.accept(visitor)
    None => ()
  }
}

///|
pub fn Examples::accept(self : Examples, visitor : &GherkinVisitor) -> Unit {
  visitor.visit_examples(self)
  for t in self.tags {
    t.accept(visitor)
  }
  match self.table_header {
    Some(h) => h.accept(visitor)
    None => ()
  }
  for r in self.table_body {
    r.accept(visitor)
  }
}

///|
pub fn DataTable::accept(self : DataTable, visitor : &GherkinVisitor) -> Unit {
  visitor.visit_data_table(self)
  for r in self.rows {
    r.accept(visitor)
  }
}

///|
pub fn DocString::accept(self : DocString, visitor : &GherkinVisitor) -> Unit {
  visitor.visit_doc_string(self)
}

///|
pub fn Tag::accept(self : Tag, visitor : &GherkinVisitor) -> Unit {
  visitor.visit_tag(self)
}

///|
pub fn Comment::accept(self : Comment, visitor : &GherkinVisitor) -> Unit {
  visitor.visit_comment(self)
}

///|
pub fn TableRow::accept(self : TableRow, visitor : &GherkinVisitor) -> Unit {
  visitor.visit_table_row(self)
}
