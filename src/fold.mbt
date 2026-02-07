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
pub fn[A] GherkinDocument::fold(
  self : GherkinDocument,
  init : A,
  folder : GherkinFold[A],
) -> A {
  let mut acc = init
  match (folder.visit_document)(acc, self) {
    Stop(a) => return a
    SkipChildren(a) => return a
    Continue(a) => acc = a
  }
  for c in self.comments {
    match (folder.visit_comment)(acc, c) {
      Stop(a) => return a
      Continue(a) | SkipChildren(a) => acc = a
    }
  }
  match self.feature {
    Some(f) => acc = fold_feature(acc, f, folder)
    None => ()
  }
  acc
}

///|
fn[A] fold_feature(init : A, f : Feature, folder : GherkinFold[A]) -> A {
  let mut acc = init
  match (folder.visit_feature)(acc, f) {
    Stop(a) => return a
    SkipChildren(a) => return a
    Continue(a) => acc = a
  }
  for t in f.tags {
    match (folder.visit_tag)(acc, t) {
      Stop(a) => return a
      Continue(a) | SkipChildren(a) => acc = a
    }
  }
  for child in f.children {
    match child {
      FeatureChild::Background(bg) => acc = fold_background(acc, bg, folder)
      FeatureChild::Scenario(s) => acc = fold_scenario(acc, s, folder)
      FeatureChild::Rule(r) => acc = fold_rule(acc, r, folder)
    }
  }
  acc
}

///|
fn[A] fold_rule(init : A, r : Rule, folder : GherkinFold[A]) -> A {
  let mut acc = init
  match (folder.visit_rule)(acc, r) {
    Stop(a) => return a
    SkipChildren(a) => return a
    Continue(a) => acc = a
  }
  for t in r.tags {
    match (folder.visit_tag)(acc, t) {
      Stop(a) => return a
      Continue(a) | SkipChildren(a) => acc = a
    }
  }
  for child in r.children {
    match child {
      RuleChild::Background(bg) => acc = fold_background(acc, bg, folder)
      RuleChild::Scenario(s) => acc = fold_scenario(acc, s, folder)
    }
  }
  acc
}

///|
fn[A] fold_background(init : A, bg : Background, folder : GherkinFold[A]) -> A {
  let mut acc = init
  match (folder.visit_background)(acc, bg) {
    Stop(a) => return a
    SkipChildren(a) => return a
    Continue(a) => acc = a
  }
  for s in bg.steps {
    acc = fold_step(acc, s, folder)
  }
  acc
}

///|
fn[A] fold_scenario(init : A, s : Scenario, folder : GherkinFold[A]) -> A {
  let mut acc = init
  match (folder.visit_scenario)(acc, s) {
    Stop(a) => return a
    SkipChildren(a) => return a
    Continue(a) => acc = a
  }
  for t in s.tags {
    match (folder.visit_tag)(acc, t) {
      Stop(a) => return a
      Continue(a) | SkipChildren(a) => acc = a
    }
  }
  for step in s.steps {
    acc = fold_step(acc, step, folder)
  }
  for e in s.examples {
    acc = fold_examples(acc, e, folder)
  }
  acc
}

///|
fn[A] fold_step(init : A, s : Step, folder : GherkinFold[A]) -> A {
  let mut acc = init
  match (folder.visit_step)(acc, s) {
    Stop(a) => return a
    SkipChildren(a) => return a
    Continue(a) => acc = a
  }
  match s.argument {
    Some(StepArgument::DocString(ds)) =>
      match (folder.visit_doc_string)(acc, ds) {
        Stop(a) => return a
        Continue(a) | SkipChildren(a) => acc = a
      }
    Some(StepArgument::DataTable(dt)) =>
      match (folder.visit_data_table)(acc, dt) {
        Stop(a) => return a
        SkipChildren(a) => acc = a
        Continue(a) => {
          acc = a
          for r in dt.rows {
            match (folder.visit_table_row)(acc, r) {
              Stop(a) => return a
              Continue(a) | SkipChildren(a) => acc = a
            }
          }
        }
      }
    None => ()
  }
  acc
}

///|
fn[A] fold_examples(init : A, e : Examples, folder : GherkinFold[A]) -> A {
  let mut acc = init
  match (folder.visit_examples)(acc, e) {
    Stop(a) => return a
    SkipChildren(a) => return a
    Continue(a) => acc = a
  }
  for t in e.tags {
    match (folder.visit_tag)(acc, t) {
      Stop(a) => return a
      Continue(a) | SkipChildren(a) => acc = a
    }
  }
  match e.table_header {
    Some(h) =>
      match (folder.visit_table_row)(acc, h) {
        Stop(a) => return a
        Continue(a) | SkipChildren(a) => acc = a
      }
    None => ()
  }
  for r in e.table_body {
    match (folder.visit_table_row)(acc, r) {
      Stop(a) => return a
      Continue(a) | SkipChildren(a) => acc = a
    }
  }
  acc
}
