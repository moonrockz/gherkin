///|
/// Control flow for fold traversal.
///
/// - `Continue(a)` — proceed into children with updated state
/// - `SkipChildren(a)` — skip children, continue with siblings
/// - `Stop(a)` — halt traversal immediately, return final state
pub enum FoldAction[A] {
  Continue(A)
  SkipChildren(A)
  Stop(A)
} derive(Show, Eq)

///|
/// Extract the accumulated value from a `FoldAction`.
pub fn[A] FoldAction::value(self : FoldAction[A]) -> A {
  match self {
    Continue(a) => a
    SkipChildren(a) => a
    Stop(a) => a
  }
}

///|
/// Returns `true` if this action is `Stop`.
pub fn[A] FoldAction::is_stop(self : FoldAction[A]) -> Bool {
  match self {
    Stop(_) => true
    _ => false
  }
}

///|
/// A fold visitor record for functional accumulation over a Gherkin AST.
///
/// Each field is a callback `(A, Node) -> FoldAction[A]` that receives
/// the current accumulator and a node, and returns the next accumulator
/// wrapped in a flow-control directive.
///
/// Use `GherkinFold::default()` to get a fold where every callback
/// passes state through unchanged, then override the ones you need
/// via struct update syntax:
///
/// ```
/// let count = doc.fold(0, { ..GherkinFold::default(),
///   visit_scenario: fn(n, _) { Continue(n + 1) }
/// })
/// ```
pub(all) struct GherkinFold[A] {
  visit_document : (A, GherkinDocument) -> FoldAction[A]
  visit_feature : (A, Feature) -> FoldAction[A]
  visit_rule : (A, Rule) -> FoldAction[A]
  visit_background : (A, Background) -> FoldAction[A]
  visit_scenario : (A, Scenario) -> FoldAction[A]
  visit_step : (A, Step) -> FoldAction[A]
  visit_doc_string : (A, DocString) -> FoldAction[A]
  visit_data_table : (A, DataTable) -> FoldAction[A]
  visit_examples : (A, Examples) -> FoldAction[A]
  visit_tag : (A, Tag) -> FoldAction[A]
  visit_comment : (A, Comment) -> FoldAction[A]
  visit_table_row : (A, TableRow) -> FoldAction[A]
}

///|
/// Create a `GherkinFold` where every callback passes state through unchanged.
pub fn[A] GherkinFold::default() -> GherkinFold[A] {
  {
    visit_document: fn(a, _) { Continue(a) },
    visit_feature: fn(a, _) { Continue(a) },
    visit_rule: fn(a, _) { Continue(a) },
    visit_background: fn(a, _) { Continue(a) },
    visit_scenario: fn(a, _) { Continue(a) },
    visit_step: fn(a, _) { Continue(a) },
    visit_doc_string: fn(a, _) { Continue(a) },
    visit_data_table: fn(a, _) { Continue(a) },
    visit_examples: fn(a, _) { Continue(a) },
    visit_tag: fn(a, _) { Continue(a) },
    visit_comment: fn(a, _) { Continue(a) },
    visit_table_row: fn(a, _) { Continue(a) },
  }
}

///|
/// Lift a plain `(A, N) -> A` function into a `FoldAction`-returning
/// callback that always continues into children.
///
/// This reduces boilerplate when you don't need flow control:
///
/// ```
/// // Without continuing:
/// visit_scenario: fn(n, _) { Continue(n + 1) }
///
/// // With continuing:
/// visit_scenario: continuing(fn(n, _) { n + 1 })
/// ```
pub fn[A, N] continuing(f : (A, N) -> A) -> (A, N) -> FoldAction[A] {
  fn(a, n) { Continue(f(a, n)) }
}

///|
/// Fold over a GherkinDocument AST, threading an accumulator through
/// each node in depth-first document order.
///
/// Respects `FoldAction` flow control:
/// - `Continue` descends into children
/// - `SkipChildren` skips children, continues with siblings
/// - `Stop` halts traversal and returns immediately
#declaration_only
pub fn[A] GherkinDocument::fold(
  self : GherkinDocument,
  init : A,
  folder : GherkinFold[A],
) -> A {
  ...
}
