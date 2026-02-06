///|
test "GherkinDocument with no feature" {
  let doc : GherkinDocument = { uri: None, feature: None, comments: [] }
  inspect(doc.feature, content="None")
}

///|
test "Location creation" {
  let loc : Location = { line: 1, column: Some(5) }
  inspect(loc.line, content="1")
}

///|
test "KeywordType variants" {
  inspect(Context, content="Context")
  inspect(Action, content="Action")
  inspect(Outcome, content="Outcome")
  inspect(Conjunction, content="Conjunction")
  inspect(Unknown, content="Unknown")
}

///|
test "FeatureChild pattern matching" {
  let s : Scenario = {
    location: { line: 3, column: None },
    tags: [],
    keyword: "Scenario",
    name: "test",
    description: "",
    id: "1",
    steps: [],
    examples: [],
  }
  match FeatureChild::Scenario(s) {
    Scenario(s) => inspect(s.name, content="test")
    _ => abort("unexpected")
  }
}

///|
test "FoldAction::value extracts inner value" {
  inspect(Continue(42).value(), content="42")
  inspect(SkipChildren("hello").value(), content="hello")
  inspect(Stop(true).value(), content="true")
}

///|
test "FoldAction::is_stop" {
  inspect(Continue(0).is_stop(), content="false")
  inspect(SkipChildren(0).is_stop(), content="false")
  inspect(Stop(0).is_stop(), content="true")
}

///|
test "GherkinFold::default passes state through" {
  let folder : GherkinFold[Int] = GherkinFold::default()
  let loc : Location = { line: 1, column: None }
  let doc : GherkinDocument = { uri: None, feature: None, comments: [] }
  let tag : Tag = { location: loc, name: "@smoke", id: "1" }
  inspect((folder.visit_document)(99, doc), content="Continue(99)")
  inspect((folder.visit_tag)(42, tag), content="Continue(42)")
}

///|
test "continuing helper wraps in Continue" {
  let f = continuing(fn(n : Int, _s : Scenario) { n + 1 })
  let s : Scenario = {
    location: { line: 1, column: None },
    tags: [],
    keyword: "Scenario",
    name: "test",
    description: "",
    id: "1",
    steps: [],
    examples: [],
  }
  inspect(f(0, s), content="Continue(1)")
  inspect(f(5, s), content="Continue(6)")
}
