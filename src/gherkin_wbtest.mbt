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

// ── parse: minimal feature ──

///|
test "parse: simplest case" {
  let src = Source::from_string("Feature: X\n  Scenario: Y\n    Given z")
  let doc = parse(src)
  guard doc.feature is Some(f) else { abort("expected feature") }
  inspect(f.name, content="X")
}

///|
test "parse: minimal feature file" {
  let src = Source::from_string(
    "Feature: Minimal\n  A feature with a single scenario.\n\n  Scenario: First scenario\n    Given a precondition\n    When an action is performed\n    Then an outcome is observed\n",
  )
  let doc = parse(src)
  guard doc.feature is Some(feature) else { abort("expected feature") }
  inspect(feature.keyword, content="Feature")
  inspect(feature.name, content="Minimal")
  inspect(feature.language, content="en")
  inspect(feature.children.length(), content="1")
  guard feature.children[0] is FeatureChild::Scenario(scenario) else {
    abort("expected scenario")
  }
  inspect(scenario.keyword, content="Scenario")
  inspect(scenario.name, content="First scenario")
  inspect(scenario.steps.length(), content="3")
  inspect(scenario.steps[0].keyword, content="Given ")
  inspect(scenario.steps[0].keyword_type, content="Context")
  inspect(scenario.steps[0].text, content="a precondition")
  inspect(scenario.steps[1].keyword, content="When ")
  inspect(scenario.steps[1].keyword_type, content="Action")
  inspect(scenario.steps[1].text, content="an action is performed")
  inspect(scenario.steps[2].keyword, content="Then ")
  inspect(scenario.steps[2].keyword_type, content="Outcome")
  inspect(scenario.steps[2].text, content="an outcome is observed")
}

///|
test "parse: inline feature text" {
  let src = Source::from_string(
    "Feature: Login\n  Scenario: Basic\n    Given a user\n",
  )
  let doc = parse(src)
  guard doc.feature is Some(feature) else { abort("expected feature") }
  inspect(feature.name, content="Login")
  inspect(feature.children.length(), content="1")
  guard feature.children[0] is FeatureChild::Scenario(s) else {
    abort("expected scenario")
  }
  inspect(s.name, content="Basic")
  inspect(s.steps.length(), content="1")
  inspect(s.steps[0].keyword, content="Given ")
  inspect(s.steps[0].text, content="a user")
}

///|
test "parse: feature with description" {
  let src = Source::from_string(
    "Feature: Minimal\n  A feature with a single scenario.\n\n  Scenario: First scenario\n    Given a precondition\n",
  )
  let doc = parse(src)
  guard doc.feature is Some(feature) else { abort("expected feature") }
  inspect(feature.description, content="A feature with a single scenario.")
}

///|
test "parse: location tracking" {
  let src = Source::from_string(
    "Feature: Test\n  Scenario: S1\n    Given step one\n",
  )
  let doc = parse(src)
  guard doc.feature is Some(feature) else { abort("expected feature") }
  inspect(feature.location, content="{line: 1, column: Some(1)}")
  guard feature.children[0] is FeatureChild::Scenario(s) else {
    abort("expected scenario")
  }
  inspect(s.location, content="{line: 2, column: Some(3)}")
  inspect(s.steps[0].location, content="{line: 3, column: Some(5)}")
}

///|
test "parse: multiple scenarios" {
  let src = Source::from_string(
    "Feature: Multi\n  Scenario: First\n    Given a\n  Scenario: Second\n    When b\n",
  )
  let doc = parse(src)
  guard doc.feature is Some(feature) else { abort("expected feature") }
  inspect(feature.children.length(), content="2")
  guard feature.children[0] is FeatureChild::Scenario(s1) else {
    abort("expected scenario 1")
  }
  guard feature.children[1] is FeatureChild::Scenario(s2) else {
    abort("expected scenario 2")
  }
  inspect(s1.name, content="First")
  inspect(s2.name, content="Second")
  inspect(s1.steps.length(), content="1")
  inspect(s2.steps.length(), content="1")
}

///|
test "parse: error message for missing Feature keyword" {
  let src = Source::from_string("Scenario: Oops\n  Given a step\n")
  let mut msg = ""
  try parse(src) |> ignore catch {
    UnexpectedToken(message~, ..) => msg = message
    _ => abort("unexpected error type")
  }
  inspect(msg.contains("expected 'Feature:' keyword"), content="true")
  inspect(msg.contains("line 1"), content="true")
  inspect(msg.contains("'Scenario:' keyword"), content="true")
  inspect(msg.contains("Scenario: Oops"), content="true")
}

///|
test "parse: step keyword types" {
  let src = Source::from_string(
    "Feature: Steps\n  Scenario: All steps\n    Given context\n    When action\n    Then outcome\n    And more\n    But not this\n    * wildcard\n",
  )
  let doc = parse(src)
  guard doc.feature is Some(feature) else { abort("expected feature") }
  guard feature.children[0] is FeatureChild::Scenario(s) else {
    abort("expected scenario")
  }
  inspect(s.steps.length(), content="6")
  inspect(s.steps[0].keyword_type, content="Context")
  inspect(s.steps[1].keyword_type, content="Action")
  inspect(s.steps[2].keyword_type, content="Outcome")
  inspect(s.steps[3].keyword_type, content="Conjunction")
  inspect(s.steps[4].keyword_type, content="Conjunction")
  inspect(s.steps[5].keyword_type, content="Unknown")
}

// ── parse: comments ──

///|
test "parse: comments collected in document" {
  let src = Source::from_string(
    "# This is a file-level comment\nFeature: Comments\n  # This is a feature-level comment\n\n  # Pre-scenario comment\n  Scenario: Commented scenario\n    # Step comment\n    Given something\n    When action\n    Then result\n",
  )
  let doc = parse(src)
  // Comments should be collected in document.comments
  guard doc.feature is Some(feature) else { abort("expected feature") }
  inspect(feature.name, content="Comments")
  guard feature.children[0] is FeatureChild::Scenario(s) else {
    abort("expected scenario")
  }
  inspect(s.name, content="Commented scenario")
  inspect(s.steps.length(), content="3")
  // Comments should be in the document
  inspect(doc.comments.length() > 0, content="true")
  inspect(doc.comments[0].text, content="# This is a file-level comment")
}

// ── parse: tags ──

///|
test "parse: feature and scenario tags" {
  let src = Source::from_string(
    "@smoke @regression\nFeature: Tagged feature\n\n  @wip\n  Scenario: Tagged scenario\n    Given something\n    When action\n    Then result\n",
  )
  let doc = parse(src)
  guard doc.feature is Some(feature) else { abort("expected feature") }
  inspect(feature.name, content="Tagged feature")
  // Feature tags
  inspect(feature.tags.length(), content="2")
  inspect(feature.tags[0].name, content="@smoke")
  inspect(feature.tags[1].name, content="@regression")
  // Scenario tags
  guard feature.children[0] is FeatureChild::Scenario(s) else {
    abort("expected scenario")
  }
  inspect(s.tags.length(), content="1")
  inspect(s.tags[0].name, content="@wip")
}

// ── parse: background ──

///|
test "parse: feature with background" {
  let src = Source::from_string(
    "Feature: Background example\n\n  Background:\n    Given a common precondition\n    And another common setup step\n\n  Scenario: First scenario\n    When an action\n    Then a result\n\n  Scenario: Second scenario\n    When a different action\n    Then a different result\n",
  )
  let doc = parse(src)
  guard doc.feature is Some(feature) else { abort("expected feature") }
  inspect(feature.name, content="Background example")
  inspect(feature.children.length(), content="3")
  // First child should be Background
  guard feature.children[0] is FeatureChild::Background(bg) else {
    abort("expected background")
  }
  inspect(bg.keyword, content="Background")
  inspect(bg.steps.length(), content="2")
  inspect(bg.steps[0].text, content="a common precondition")
  inspect(bg.steps[1].text, content="another common setup step")
  // Second and third children should be Scenarios
  guard feature.children[1] is FeatureChild::Scenario(s1) else {
    abort("expected scenario 1")
  }
  guard feature.children[2] is FeatureChild::Scenario(s2) else {
    abort("expected scenario 2")
  }
  inspect(s1.name, content="First scenario")
  inspect(s2.name, content="Second scenario")
}

// ── parse: doc strings ──

///|
test "parse: step with doc string" {
  let src = Source::from_string(
    "Feature: Doc Strings\n\n  Scenario: A step with a doc string\n    Given the following text:\n      \"\"\"\n      This is a doc string.\n      It can span multiple lines.\n      \"\"\"\n    When I process the text\n    Then it should be captured\n",
  )
  let doc = parse(src)
  guard doc.feature is Some(feature) else { abort("expected feature") }
  guard feature.children[0] is FeatureChild::Scenario(s) else {
    abort("expected scenario")
  }
  inspect(s.steps.length(), content="3")
  inspect(s.steps[0].text, content="the following text:")
  // First step should have a doc string argument
  guard s.steps[0].argument is Some(StepArgument::DocString(ds)) else {
    abort("expected doc string argument")
  }
  inspect(ds.delimiter, content="\"\"\"")
  inspect(ds.content.contains("This is a doc string."), content="true")
  inspect(ds.content.contains("It can span multiple lines."), content="true")
}

// ── parse: data tables ──

///|
test "parse: step with data table" {
  let src = Source::from_string(
    "Feature: Data Tables\n\n  Scenario: A step with a data table\n    Given the following users exist:\n      | name  | email          | role  |\n      | Alice | alice@test.com | admin |\n      | Bob   | bob@test.com   | user  |\n    When I list all users\n    Then I should see 2 users\n",
  )
  let doc = parse(src)
  guard doc.feature is Some(feature) else { abort("expected feature") }
  guard feature.children[0] is FeatureChild::Scenario(s) else {
    abort("expected scenario")
  }
  inspect(s.steps.length(), content="3")
  inspect(s.steps[0].text, content="the following users exist:")
  // First step should have a data table argument
  guard s.steps[0].argument is Some(StepArgument::DataTable(dt)) else {
    abort("expected data table argument")
  }
  inspect(dt.rows.length(), content="3")
  inspect(dt.rows[0].cells.length(), content="3")
  inspect(dt.rows[0].cells[0].value, content="name")
  inspect(dt.rows[1].cells[0].value, content="Alice")
  inspect(dt.rows[2].cells[0].value, content="Bob")
}

// ── parse: scenario outline + examples ──

///|
test "parse: scenario outline with examples" {
  let src = Source::from_string(
    "Feature: Scenario Outline example\n\n  Scenario Outline: Eating cucumbers\n    Given there are <start> cucumbers\n    When I eat <eat> cucumbers\n    Then I should have <left> cucumbers\n\n    Examples:\n      | start | eat | left |\n      |    12 |   5 |    7 |\n      |    20 |   5 |   15 |\n",
  )
  let doc = parse(src)
  guard doc.feature is Some(feature) else { abort("expected feature") }
  inspect(feature.name, content="Scenario Outline example")
  inspect(feature.children.length(), content="1")
  guard feature.children[0] is FeatureChild::Scenario(s) else {
    abort("expected scenario")
  }
  inspect(s.keyword, content="Scenario Outline")
  inspect(s.name, content="Eating cucumbers")
  inspect(s.steps.length(), content="3")
  // Placeholder syntax should be preserved in step text
  inspect(s.steps[0].text, content="there are <start> cucumbers")
  // Examples should be parsed
  inspect(s.examples.length(), content="1")
  guard s.examples[0] is { keyword, name, table_header, table_body, .. } else {
    abort("expected examples")
  }
  inspect(keyword, content="Examples")
  inspect(name, content="")
  // Table header
  guard table_header is Some(header) else { abort("expected table header") }
  inspect(header.cells.length(), content="3")
  inspect(header.cells[0].value, content="start")
  inspect(header.cells[1].value, content="eat")
  inspect(header.cells[2].value, content="left")
  // Table body
  inspect(table_body.length(), content="2")
  inspect(table_body[0].cells[0].value, content="12")
  inspect(table_body[1].cells[0].value, content="20")
  inspect(table_body[1].cells[2].value, content="15")
}

// ── parse: rules ──

///|
test "parse: rule sections" {
  let src = Source::from_string(
    "Feature: Gherkin 6 Rules\n\n  Rule: Business rule one\n    Scenario: First rule scenario\n      Given a context\n      When an event\n      Then an outcome\n\n  Rule: Business rule two\n    Scenario: Second rule scenario\n      Given another context\n      When another event\n      Then another outcome\n",
  )
  let doc = parse(src)
  guard doc.feature is Some(feature) else { abort("expected feature") }
  inspect(feature.name, content="Gherkin 6 Rules")
  inspect(feature.children.length(), content="2")
  guard feature.children[0] is FeatureChild::Rule(r1) else {
    abort("expected rule 1")
  }
  guard feature.children[1] is FeatureChild::Rule(r2) else {
    abort("expected rule 2")
  }
  inspect(r1.keyword, content="Rule")
  inspect(r1.name, content="Business rule one")
  inspect(r1.children.length(), content="1")
  guard r1.children[0] is RuleChild::Scenario(s1) else {
    abort("expected scenario in rule 1")
  }
  inspect(s1.name, content="First rule scenario")
  inspect(s1.steps.length(), content="3")
  inspect(r2.keyword, content="Rule")
  inspect(r2.name, content="Business rule two")
  inspect(r2.children.length(), content="1")
  guard r2.children[0] is RuleChild::Scenario(s2) else {
    abort("expected scenario in rule 2")
  }
  inspect(s2.name, content="Second rule scenario")
  inspect(s2.steps.length(), content="3")
}

// ── visitor: accept traversal ──

///|
/// A recording visitor that tracks visit calls in order.
struct RecordingVisitor {
  events : Array[String]
}

///|
impl GherkinVisitor for RecordingVisitor with visit_document(_self, _doc) {
  _self.events.push("document")
}

///|
impl GherkinVisitor for RecordingVisitor with visit_feature(_self, f) {
  _self.events.push("feature:" + f.name)
}

///|
impl GherkinVisitor for RecordingVisitor with visit_scenario(_self, s) {
  _self.events.push("scenario:" + s.name)
}

///|
impl GherkinVisitor for RecordingVisitor with visit_step(_self, s) {
  _self.events.push("step:" + s.text)
}

///|
impl GherkinVisitor for RecordingVisitor with visit_tag(_self, t) {
  _self.events.push("tag:" + t.name)
}

///|
impl GherkinVisitor for RecordingVisitor with visit_comment(_self, c) {
  _self.events.push("comment:" + c.text)
}

///|
impl GherkinVisitor for RecordingVisitor with visit_background(_self, bg) {
  _self.events.push("background:" + bg.name)
}

///|
impl GherkinVisitor for RecordingVisitor with visit_rule(_self, r) {
  _self.events.push("rule:" + r.name)
}

///|
impl GherkinVisitor for RecordingVisitor with visit_examples(_self, e) {
  _self.events.push("examples:" + e.keyword)
}

///|
test "accept: visitor dispatches events in document order" {
  let src = Source::from_string(
    "# file comment\n@smoke\nFeature: Login\n  Background:\n    Given setup\n  Scenario: Basic\n    Given a user\n    When login\n    Then success\n",
  )
  let doc = parse(src)
  let v : RecordingVisitor = { events: [] }
  doc.accept(v)
  inspect(v.events[0], content="document")
  inspect(v.events[1], content="comment:# file comment")
  inspect(v.events[2], content="feature:Login")
  inspect(v.events[3], content="tag:@smoke")
  inspect(v.events[4], content="background:")
  inspect(v.events[5], content="step:setup")
  inspect(v.events[6], content="scenario:Basic")
  inspect(v.events[7], content="step:a user")
  inspect(v.events[8], content="step:login")
  inspect(v.events[9], content="step:success")
  inspect(v.events.length(), content="10")
}

// ── fold: accumulation ──

///|
test "fold: count scenarios" {
  let src = Source::from_string(
    "Feature: Multi\n  Scenario: First\n    Given a\n  Scenario: Second\n    When b\n  Scenario: Third\n    Then c\n",
  )
  let doc = parse(src)
  let count = doc.fold(0, {
    ..GherkinFold::default(),
    visit_scenario: continuing(fn(n, _s) { n + 1 }),
  })
  inspect(count, content="3")
}

///|
test "fold: collect step texts" {
  let src = Source::from_string(
    "Feature: Steps\n  Scenario: S1\n    Given a\n    When b\n    Then c\n",
  )
  let doc = parse(src)
  let texts : Array[String] = doc.fold([], {
    ..GherkinFold::default(),
    visit_step: fn(acc, s) {
      acc.push(s.text)
      Continue(acc)
    },
  })
  inspect(texts.length(), content="3")
  inspect(texts[0], content="a")
  inspect(texts[1], content="b")
  inspect(texts[2], content="c")
}

///|
test "fold: SkipChildren skips scenario steps" {
  let src = Source::from_string(
    "Feature: Skip\n  Scenario: S1\n    Given a\n    When b\n  Scenario: S2\n    Then c\n",
  )
  let doc = parse(src)
  let result : Array[String] = doc.fold([], {
    ..GherkinFold::default(),
    visit_scenario: fn(acc, s) {
      acc.push("scenario:" + s.name)
      if s.name == "S1" {
        SkipChildren(acc)
      } else {
        Continue(acc)
      }
    },
    visit_step: fn(acc, s) {
      acc.push("step:" + s.text)
      Continue(acc)
    },
  })
  // S1's steps should be skipped, S2's step should be included
  inspect(result.length(), content="3")
  inspect(result[0], content="scenario:S1")
  inspect(result[1], content="scenario:S2")
  inspect(result[2], content="step:c")
}

///|
test "fold: Stop halts traversal" {
  let src = Source::from_string(
    "Feature: Stop\n  Scenario: S1\n    Given a\n  Scenario: S2\n    When b\n",
  )
  let doc = parse(src)
  let count = doc.fold(0, {
    ..GherkinFold::default(),
    visit_scenario: fn(n, _s) { if n >= 1 { Stop(n) } else { Continue(n + 1) } },
  })
  // Should stop after first scenario
  inspect(count, content="1")
}

// ── parse_with_handler: SAX-style events ──

///|
/// A recording handler that captures event names in order.
struct RecordingHandler {
  events : Array[String]
}

///|
impl GherkinHandler for RecordingHandler with on_document(self) {
  self.events.push("document:start")
}

///|
impl GherkinHandler for RecordingHandler with on_end_document(self) {
  self.events.push("document:end")
}

///|
impl GherkinHandler for RecordingHandler with on_feature(self, e) {
  self.events.push("feature:" + e.name)
}

///|
impl GherkinHandler for RecordingHandler with on_end_feature(self) {
  self.events.push("feature:end")
}

///|
impl GherkinHandler for RecordingHandler with on_scenario(self, e) {
  self.events.push("scenario:" + e.name)
}

///|
impl GherkinHandler for RecordingHandler with on_end_scenario(self) {
  self.events.push("scenario:end")
}

///|
impl GherkinHandler for RecordingHandler with on_step(self, e) {
  self.events.push("step:" + e.text)
}

///|
impl GherkinHandler for RecordingHandler with on_background(self, e) {
  self.events.push("background:" + e.name)
}

///|
impl GherkinHandler for RecordingHandler with on_end_background(self) {
  self.events.push("background:end")
}

///|
impl GherkinHandler for RecordingHandler with on_comment(self, e) {
  self.events.push("comment:" + e.text)
}

///|
impl GherkinHandler for RecordingHandler with on_tag(self, e) {
  self.events.push("tag:" + e.name)
}

///|
test "parse_with_handler: dispatches balanced events" {
  let src = Source::from_string(
    "# comment\n@smoke\nFeature: Login\n  Background:\n    Given setup\n  Scenario: Basic\n    Given a user\n    When login\n",
  )
  let h : RecordingHandler = { events: [] }
  parse_with_handler(src, h)
  inspect(h.events[0], content="document:start")
  inspect(h.events[1], content="comment:# comment")
  inspect(h.events[2], content="feature:Login")
  inspect(h.events[3], content="tag:@smoke")
  inspect(h.events[4], content="background:")
  inspect(h.events[5], content="step:setup")
  inspect(h.events[6], content="background:end")
  inspect(h.events[7], content="scenario:Basic")
  inspect(h.events[8], content="step:a user")
  inspect(h.events[9], content="step:login")
  inspect(h.events[10], content="scenario:end")
  inspect(h.events[11], content="feature:end")
  inspect(h.events[12], content="document:end")
  inspect(h.events.length(), content="13")
}

// ── error handling ──

///|
test "parse: UnexpectedEof for empty feature" {
  let src = Source::from_string("Feature: Incomplete")
  // Should parse without error -- empty feature is valid
  let doc = parse(src)
  guard doc.feature is Some(f) else { abort("expected feature") }
  inspect(f.name, content="Incomplete")
  inspect(f.children.length(), content="0")
}

///|
test "parse: completely invalid input" {
  let src = Source::from_string("This is not gherkin at all")
  let mut msg = ""
  try parse(src) |> ignore catch {
    UnexpectedToken(message~, ..) => msg = message
    _ => abort("unexpected error type")
  }
  inspect(msg.contains("expected 'Feature:' keyword"), content="true")
}

///|
test "parse: InconsistentTableCells detected" {
  let src = Source::from_string(
    "Feature: Tables\n  Scenario: Bad table\n    Given a table:\n      | a | b | c |\n      | 1 | 2 |\n",
  )
  let mut msg = ""
  try parse(src) |> ignore catch {
    InconsistentTableCells(message~, ..) => msg = message
    _ => abort("unexpected error type")
  }
  inspect(msg.contains("inconsistent"), content="true")
}

// ── i18n: language directive ──

///|
test "parse: French i18n with language directive" {
  let src = Source::from_string(
    "# language: fr\nFonctionnalité: Internationalisation\n\n  Scénario: Scénario en français\n    Soit une précondition\n    Quand une action\n    Alors un résultat\n",
  )
  let doc = parse(src)
  guard doc.feature is Some(feature) else { abort("expected feature") }
  inspect(feature.language, content="fr")
  inspect(feature.keyword, content="Fonctionnalité")
  inspect(feature.name, content="Internationalisation")
  inspect(feature.children.length(), content="1")
  guard feature.children[0] is FeatureChild::Scenario(s) else {
    abort("expected scenario")
  }
  inspect(s.keyword, content="Scénario")
  inspect(s.steps.length(), content="3")
  inspect(s.steps[0].keyword_type, content="Context")
  inspect(s.steps[0].text, content="une précondition")
  inspect(s.steps[1].keyword_type, content="Action")
  inspect(s.steps[2].keyword_type, content="Outcome")
}

// ── JSON serialization ──

///|
test "GherkinDocument::to_json produces valid JSON" {
  let src = Source::from_string(
    "Feature: Login\n  Scenario: Basic\n    Given a user",
  )
  let doc = parse(src)
  let json = doc.to_json()
  let text = json.stringify()
  // Should contain key fields
  assert_true(text.contains("Login"))
  assert_true(text.contains("Basic"))
  assert_true(text.contains("a user"))
}
