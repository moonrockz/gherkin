///|
test "GherkinDocument with no feature" {
  let doc = GherkinDocument::empty()
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
  let doc = GherkinDocument::empty()
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

///|
test "Source::from_string splits lines" {
  let src = Source::from_string("line1\nline2\nline3")
  inspect(src.line_count(), content="3")
  inspect(src.line(1), content="Some(\"line1\")")
  inspect(src.line(2), content="Some(\"line2\")")
  inspect(src.line(3), content="Some(\"line3\")")
}

///|
test "Source::from_string handles CRLF" {
  let src = Source::from_string("a\r\nb\r\nc")
  inspect(src.line_count(), content="3")
  inspect(src.line(1), content="Some(\"a\")")
  inspect(src.line(2), content="Some(\"b\")")
  inspect(src.line(3), content="Some(\"c\")")
}

///|
test "Source::from_string empty string" {
  let src = Source::from_string("")
  inspect(src.line_count(), content="1")
  inspect(src.line(1), content="Some(\"\")")
}

///|
test "Source::from_string trailing newline" {
  let src = Source::from_string("hello\n")
  inspect(src.line_count(), content="2")
  inspect(src.line(1), content="Some(\"hello\")")
  inspect(src.line(2), content="Some(\"\")")
}

///|
test "Source::uri" {
  let src = Source::from_string("content", uri="test.feature")
  inspect(src.uri(), content="Some(\"test.feature\")")
  let no_uri = Source::from_string("content")
  inspect(no_uri.uri(), content="None")
}

///|
test "Source::content round-trips" {
  let original = "Feature: Login\n  Scenario: Success"
  let src = Source::from_string(original)
  inspect(src.content(), content="Feature: Login\n  Scenario: Success")
}

///|
test "Source::line out of range" {
  let src = Source::from_string("one\ntwo")
  inspect(src.line(0), content="None")
  inspect(src.line(3), content="None")
  inspect(src.line(-1), content="None")
}
