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
