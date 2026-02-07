// ==========================================================================
// GherkinReader BDD tests — pull-based event iterator
// ==========================================================================

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

///|
fn event_name(e : GherkinEvent) -> String {
  match e {
    DocumentStart => "DocumentStart"
    DocumentEnd => "DocumentEnd"
    FeatureStart(_) => "FeatureStart"
    FeatureEnd => "FeatureEnd"
    RuleStart(_) => "RuleStart"
    RuleEnd => "RuleEnd"
    BackgroundStart(_) => "BackgroundStart"
    BackgroundEnd => "BackgroundEnd"
    ScenarioStart(_) => "ScenarioStart"
    ScenarioEnd => "ScenarioEnd"
    Step(_) => "Step"
    DocString(_) => "DocString"
    DataTable(_) => "DataTable"
    Examples(_) => "Examples"
    Tag(_) => "Tag"
    Comment(_) => "Comment"
  }
}

///|
fn collect_names(reader : GherkinReader) -> String {
  let names : Array[String] = []
  for e in reader.iter() {
    names.push(event_name(e))
  }
  names.join(" -> ")
}

// ==========================================================================
// Event sequence tests
// ==========================================================================

///|
test "reader: empty document" {
  let reader = GherkinReader::from_document(GherkinDocument::empty())
  inspect(collect_names(reader), content="DocumentStart -> DocumentEnd")
}

///|
test "reader: feature only" {
  let reader = GherkinReader::new(Source::from_string("Feature: Login"))
  inspect(
    collect_names(reader),
    content="DocumentStart -> FeatureStart -> FeatureEnd -> DocumentEnd",
  )
}

///|
test "reader: feature with scenario and steps" {
  let input =
    #|Feature: Login
    #|  Scenario: Success
    #|    Given a user
    #|    When they login
    #|    Then they see dashboard
  let reader = GherkinReader::new(Source::from_string(input))
  inspect(
    collect_names(reader),
    content="DocumentStart -> FeatureStart -> ScenarioStart -> Step -> Step -> Step -> ScenarioEnd -> FeatureEnd -> DocumentEnd",
  )
}

///|
test "reader: feature with tags" {
  let input =
    #|@smoke @regression
    #|Feature: Login
  let reader = GherkinReader::new(Source::from_string(input))
  inspect(
    collect_names(reader),
    content="DocumentStart -> FeatureStart -> Tag -> Tag -> FeatureEnd -> DocumentEnd",
  )
}

///|
test "reader: scenario with tags" {
  let input =
    #|Feature: F
    #|  @wip
    #|  Scenario: S
    #|    Given x
  let reader = GherkinReader::new(Source::from_string(input))
  inspect(
    collect_names(reader),
    content="DocumentStart -> FeatureStart -> ScenarioStart -> Tag -> Step -> ScenarioEnd -> FeatureEnd -> DocumentEnd",
  )
}

///|
test "reader: comments" {
  let input =
    #|# A comment
    #|Feature: Login
  let reader = GherkinReader::new(Source::from_string(input))
  inspect(
    collect_names(reader),
    content="DocumentStart -> Comment -> FeatureStart -> FeatureEnd -> DocumentEnd",
  )
}

///|
test "reader: background" {
  let input =
    #|Feature: F
    #|  Background:
    #|    Given a setup step
    #|  Scenario: S
    #|    When action
  let reader = GherkinReader::new(Source::from_string(input))
  inspect(
    collect_names(reader),
    content="DocumentStart -> FeatureStart -> BackgroundStart -> Step -> BackgroundEnd -> ScenarioStart -> Step -> ScenarioEnd -> FeatureEnd -> DocumentEnd",
  )
}

///|
test "reader: rules" {
  let input =
    #|Feature: F
    #|  Rule: Admin access
    #|    Scenario: Admin login
    #|      Given an admin
  let reader = GherkinReader::new(Source::from_string(input))
  inspect(
    collect_names(reader),
    content="DocumentStart -> FeatureStart -> RuleStart -> ScenarioStart -> Step -> ScenarioEnd -> RuleEnd -> FeatureEnd -> DocumentEnd",
  )
}

///|
test "reader: doc string" {
  let input =
    #|Feature: F
    #|  Scenario: S
    #|    Given a document:
    #|      """
    #|      Hello World
    #|      """
  let reader = GherkinReader::new(Source::from_string(input))
  inspect(
    collect_names(reader),
    content="DocumentStart -> FeatureStart -> ScenarioStart -> Step -> DocString -> ScenarioEnd -> FeatureEnd -> DocumentEnd",
  )
}

///|
test "reader: data table" {
  let input =
    #|Feature: F
    #|  Scenario: S
    #|    Given users:
    #|      | name | age |
    #|      | Bob  | 30  |
  let reader = GherkinReader::new(Source::from_string(input))
  inspect(
    collect_names(reader),
    content="DocumentStart -> FeatureStart -> ScenarioStart -> Step -> DataTable -> ScenarioEnd -> FeatureEnd -> DocumentEnd",
  )
}

///|
test "reader: scenario outline with examples" {
  let input =
    #|Feature: F
    #|  Scenario Outline: S
    #|    Given <user>
    #|    Examples:
    #|      | user  |
    #|      | Alice |
  let reader = GherkinReader::new(Source::from_string(input))
  inspect(
    collect_names(reader),
    content="DocumentStart -> FeatureStart -> ScenarioStart -> Step -> Examples -> ScenarioEnd -> FeatureEnd -> DocumentEnd",
  )
}

///|
test "reader: multiple scenarios" {
  let input =
    #|Feature: F
    #|  Scenario: First
    #|    Given a
    #|  Scenario: Second
    #|    Given b
  let reader = GherkinReader::new(Source::from_string(input))
  inspect(
    collect_names(reader),
    content="DocumentStart -> FeatureStart -> ScenarioStart -> Step -> ScenarioEnd -> ScenarioStart -> Step -> ScenarioEnd -> FeatureEnd -> DocumentEnd",
  )
}

// ==========================================================================
// API behavior tests
// ==========================================================================

///|
test "reader: peek returns same event without consuming" {
  let reader = GherkinReader::new(Source::from_string("Feature: F"))
  let peeked = reader.peek()
  let nexted = reader.next()
  // Both should be DocumentStart
  inspect(
    peeked.map(event_name),
    content=(
      #|Some("DocumentStart")
    ),
  )
  inspect(
    nexted.map(event_name),
    content=(
      #|Some("DocumentStart")
    ),
  )
}

///|
test "reader: next returns None when exhausted" {
  let reader = GherkinReader::from_document(GherkinDocument::empty())
  // Consume all events
  let _ = reader.next() // DocumentStart
  let _ = reader.next() // DocumentEnd
  inspect(reader.next(), content="None")
}

///|
test "reader: peek returns None when exhausted" {
  let reader = GherkinReader::from_document(GherkinDocument::empty())
  let _ = reader.next() // DocumentStart
  let _ = reader.next() // DocumentEnd
  inspect(reader.peek(), content="None")
}

///|
test "reader: iter produces same sequence as repeated next" {
  let input =
    #|Feature: F
    #|  Scenario: S
    #|    Given x
  let source = Source::from_string(input)
  // Collect via iter
  let reader1 = GherkinReader::new(source)
  let via_iter : Array[String] = []
  for e in reader1.iter() {
    via_iter.push(event_name(e))
  }
  // Collect via next
  let reader2 = GherkinReader::new(source)
  let via_next : Array[String] = []
  while true {
    match reader2.next() {
      Some(e) => via_next.push(event_name(e))
      None => break
    }
  }
  assert_eq(via_iter, via_next)
}

///|
test "reader: from_document produces same events as new" {
  let input =
    #|Feature: Login
    #|  Scenario: S
    #|    Given a user
  let source = Source::from_string(input)
  let doc = parse(source)
  let reader1 = GherkinReader::new(source)
  let reader2 = GherkinReader::from_document(doc)
  inspect(collect_names(reader1), content=collect_names(reader2))
}

// ==========================================================================
// Data verification tests
// ==========================================================================

///|
test "reader: FeatureStart carries correct data" {
  let input =
    #|Feature: Shopping cart
  let reader = GherkinReader::new(Source::from_string(input))
  let _ = reader.next() // DocumentStart
  let event = reader.next()
  guard event is Some(FeatureStart(fe)) else {
    fail("expected FeatureStart, got \{event}")
  }
  inspect(fe.name, content="Shopping cart")
  inspect(fe.keyword, content="Feature")
  inspect(fe.language, content="en")
}

///|
test "reader: StepEvent carries correct data" {
  let input =
    #|Feature: F
    #|  Scenario: S
    #|    Given a registered user
  let reader = GherkinReader::new(Source::from_string(input))
  let _ = reader.next() // DocumentStart
  let _ = reader.next() // FeatureStart
  let _ = reader.next() // ScenarioStart
  let event = reader.next()
  guard event is Some(Step(se)) else { fail("expected Step, got \{event}") }
  inspect(se.text, content="a registered user")
  inspect(se.keyword, content="Given ")
  inspect(se.keyword_type, content="Context")
}

///|
test "reader: TagEvent carries correct name" {
  let input =
    #|@smoke
    #|Feature: F
  let reader = GherkinReader::new(Source::from_string(input))
  let _ = reader.next() // DocumentStart
  let _ = reader.next() // FeatureStart
  let event = reader.next()
  guard event is Some(Tag(te)) else { fail("expected Tag, got \{event}") }
  inspect(te.name, content="@smoke")
}

///|
test "reader: CommentEvent carries correct text" {
  let input =
    #|# Hello world
    #|Feature: F
  let reader = GherkinReader::new(Source::from_string(input))
  let _ = reader.next() // DocumentStart
  let event = reader.next()
  guard event is Some(Comment(ce)) else {
    fail("expected Comment, got \{event}")
  }
  inspect(ce.text, content="# Hello world")
}

// ==========================================================================
// Pull-to-Push adapter tests (pipe)
// ==========================================================================

///|
test "reader: pipe to writer produces same output as write" {
  let input =
    #|Feature: Login
    #|  Scenario: Success
    #|    Given a registered user
    #|    When they enter credentials
    #|    Then they see the dashboard
  let source = Source::from_string(input)
  let doc = parse(source)
  // Direct write
  let direct = write(doc)
  // Reader -> pipe -> writer
  let reader = GherkinReader::from_document(doc)
  let w = GherkinWriter::new()
  reader.pipe(w)
  let piped = w.to_string()
  assert_eq(direct, piped)
}

///|
test "reader: pipe with tags" {
  let input =
    #|@smoke
    #|Feature: F
    #|  @wip
    #|  Scenario: S
    #|    Given x
  let source = Source::from_string(input)
  let doc = parse(source)
  let direct = write(doc)
  let reader = GherkinReader::from_document(doc)
  let w = GherkinWriter::new()
  reader.pipe(w)
  assert_eq(direct, w.to_string())
}

///|
test "reader: pipe with data table" {
  let input =
    #|Feature: F
    #|  Scenario: S
    #|    Given users:
    #|      | name  | age |
    #|      | Alice | 30  |
    #|      | Bob   | 25  |
  let source = Source::from_string(input)
  let doc = parse(source)
  let direct = write(doc)
  let reader = GherkinReader::from_document(doc)
  let w = GherkinWriter::new()
  reader.pipe(w)
  assert_eq(direct, w.to_string())
}

///|
test "reader: pipe with doc string" {
  let input =
    #|Feature: F
    #|  Scenario: S
    #|    Given a document:
    #|      """
    #|      Hello World
    #|      """
  let source = Source::from_string(input)
  let doc = parse(source)
  let direct = write(doc)
  let reader = GherkinReader::from_document(doc)
  let w = GherkinWriter::new()
  reader.pipe(w)
  assert_eq(direct, w.to_string())
}

///|
test "reader: pipe with examples" {
  let input =
    #|Feature: F
    #|  Scenario Outline: S
    #|    Given <user>
    #|    Examples:
    #|      | user  |
    #|      | Alice |
    #|      | Bob   |
  let source = Source::from_string(input)
  let doc = parse(source)
  let direct = write(doc)
  let reader = GherkinReader::from_document(doc)
  let w = GherkinWriter::new()
  reader.pipe(w)
  assert_eq(direct, w.to_string())
}

///|
test "reader: pipe with rules" {
  let input =
    #|Feature: F
    #|  Rule: Admin
    #|    Scenario: S
    #|      Given an admin
  let source = Source::from_string(input)
  let doc = parse(source)
  let direct = write(doc)
  let reader = GherkinReader::from_document(doc)
  let w = GherkinWriter::new()
  reader.pipe(w)
  assert_eq(direct, w.to_string())
}
