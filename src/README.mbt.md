# moonrockz/gherkin

A Gherkin parser providing four APIs: DOM tree, visitor, functional fold, and SAX-style handler.

## Source

All parsing starts with a `Source`, an opaque wrapper around the input text.

```moonbit check
///|
test "create a source from a string" {
  let src = Source::from_string("Feature: Hello\n  Scenario: World", uri="test.feature")
  inspect(src.uri(), content="Some(\"test.feature\")")
  inspect(src.line_count(), content="2")
  inspect(src.line(1), content="Some(\"Feature: Hello\")")
}
```

## DOM Parsing

`parse` returns a `GherkinDocument` containing the full AST.

```moonbit check
///|
test "parse a feature with scenarios and steps" {
  let input =
    #|Feature: Calculator
    #|  Scenario: Addition
    #|    Given two numbers
    #|    When I add them
    #|    Then I get the sum
  let doc = parse(Source::from_string(input))
  let feature = doc.feature.unwrap()
  inspect(feature.name, content="Calculator")
  inspect(feature.language, content="en")
  guard feature.children[0] is Scenario(s)
  inspect(s.name, content="Addition")
  inspect(s.steps.length(), content="3")
  inspect(s.steps[0].keyword_type, content="Context")
  inspect(s.steps[1].keyword_type, content="Action")
  inspect(s.steps[2].keyword_type, content="Outcome")
}
```

### Data Tables

Steps can have a `DataTable` argument with rows and cells.

```moonbit check
///|
test "parse a step with a data table" {
  let input =
    #|Feature: Users
    #|  Scenario: List users
    #|    Given users:
    #|      | name  | age |
    #|      | Alice | 30  |
    #|      | Bob   | 25  |
  let doc = parse(Source::from_string(input))
  guard doc.feature.unwrap().children[0] is Scenario(s)
  guard s.steps[0].argument is Some(DataTable(table))
  inspect(table.rows.length(), content="3")
  inspect(table.rows[0].cells[0].value, content="name")
  inspect(table.rows[1].cells[0].value, content="Alice")
  inspect(table.rows[2].cells[1].value, content="25")
}
```

### Doc Strings

Steps can have a `DocString` argument with an optional media type.

```moonbit check
///|
test "parse a step with a doc string" {
  let input =
    #|Feature: Payloads
    #|  Scenario: JSON body
    #|    Given a request body:
    #|      ```json
    #|      {"key": "value"}
    #|      ```
  let doc = parse(Source::from_string(input))
  guard doc.feature.unwrap().children[0] is Scenario(s)
  guard s.steps[0].argument is Some(DocString(ds))
  inspect(ds.media_type, content="Some(\"json\")")
  assert_true(ds.content.contains("key"))
}
```

### Tags

Tags decorate features, scenarios, and examples.

```moonbit check
///|
test "parse tags on features and scenarios" {
  let input =
    #|@smoke @regression
    #|Feature: Tagged
    #|  @critical
    #|  Scenario: Important
    #|    Given a step
  let doc = parse(Source::from_string(input))
  let feature = doc.feature.unwrap()
  inspect(feature.tags.length(), content="2")
  inspect(feature.tags[0].name, content="@smoke")
  guard feature.children[0] is Scenario(s)
  inspect(s.tags[0].name, content="@critical")
}
```

### JSON Serialization

All AST types implement `ToJson`.

```moonbit check
///|
test "serialize a document to JSON" {
  let doc = parse(Source::from_string("Feature: JSON\n  Scenario: Test\n    Given a step"))
  let text = doc.to_json().stringify()
  assert_true(text.contains("JSON"))
  assert_true(text.contains("Test"))
}
```

## Visitor Pattern

Implement `GherkinVisitor` and override only the methods you need.
All methods have default no-op implementations.

```moonbit check
///|
struct ScenarioCounter {
  mut count : Int
}

///|
impl GherkinVisitor for ScenarioCounter with visit_scenario(self, _scenario) {
  self.count += 1
}

///|
test "count scenarios with a visitor" {
  let input =
    #|Feature: Counter
    #|  Scenario: First
    #|    Given a
    #|  Scenario: Second
    #|    Given b
  let doc = parse(Source::from_string(input))
  let counter : ScenarioCounter = { count: 0 }
  doc.accept(counter)
  inspect(counter.count, content="2")
}
```

## Functional Fold

`GherkinFold` threads an accumulator through the AST.
Use `GherkinFold::default()` for a passthrough fold, then override fields.
The `continuing` helper lifts plain functions into fold callbacks.

```moonbit check
///|
test "count steps with fold" {
  let input =
    #|Feature: Fold
    #|  Scenario: One
    #|    Given step 1
    #|    When step 2
    #|  Scenario: Two
    #|    Then step 3
  let doc = parse(Source::from_string(input))
  let step_count = doc.fold(0, {
    ..GherkinFold::default(),
    visit_step: continuing(fn(n, _step) { n + 1 }),
  })
  inspect(step_count, content="3")
}
```

### Flow Control

`FoldAction` controls traversal: `Continue` descends into children,
`SkipChildren` skips children but continues siblings, `Stop` halts immediately.

```moonbit skip nocheck
let step_count = doc.fold(0, {
  ..GherkinFold::default(),
  visit_scenario: fn(n, scenario) {
    if scenario.tags.iter().any(fn(t) { t.name == "@skip" }) {
      SkipChildren(n)  // skip steps inside @skip scenarios
    } else {
      Continue(n)
    }
  },
  visit_step: continuing(fn(n, _) { n + 1 }),
})
```

## SAX-Style Handler

`GherkinHandler` receives push-based events as the parser encounters elements.
No AST is built — useful for streaming or memory-constrained scenarios.

```moonbit check
///|
struct EventLog {
  events : Array[String]
}

///|
impl GherkinHandler for EventLog with on_feature(self, event) {
  self.events.push("feature:\{event.name}")
}

///|
impl GherkinHandler for EventLog with on_scenario(self, event) {
  self.events.push("scenario:\{event.name}")
}

///|
impl GherkinHandler for EventLog with on_step(self, event) {
  self.events.push("step:\{event.text}")
}

///|
test "log events with a handler" {
  let input =
    #|Feature: Events
    #|  Scenario: Example
    #|    Given a step
    #|    When an action
  let logger : EventLog = { events: [] }
  parse_with_handler(Source::from_string(input), logger)
  inspect(logger.events[0], content="feature:Events")
  inspect(logger.events[1], content="scenario:Example")
  inspect(logger.events[2], content="step:a step")
  inspect(logger.events[3], content="step:an action")
}
```

## Lexer

The lower-level lexer API is useful for syntax highlighting or custom parsing.

`tokenize` converts a full source to tokens eagerly.
`Lexer` provides a lazy iterator.

```moonbit check
///|
test "tokenize a source" {
  let tokens = tokenize(Source::from_string("Feature: Test\n  Given a step"))
  guard tokens[0] is FeatureLine(_, kw, name)
  inspect(kw, content="Feature")
  inspect(name, content="Test")
  guard tokens[1] is StepLine(_, _, kt, text)
  inspect(kt, content="Context")
  inspect(text, content="a step")
}
```

```moonbit check
///|
test "lazy iteration with Lexer" {
  let lexer = Lexer::new(Source::from_string("Given a\nWhen b\nThen c"))
  let mut count = 0
  for tok in lexer.iter() {
    match tok {
      StepLine(_, _, _, _) => count += 1
      _ => ()
    }
  }
  inspect(count, content="3")
}
```

## Error Handling

Parse errors carry a message and location.

```moonbit check
///|
test "handle parse errors" {
  let input =
    #|Feature: Tables
    #|  Scenario: Bad
    #|    Given a table:
    #|      | a | b |
    #|      | 1 | 2 | 3 |
  let result = try {
    let _ = parse(Source::from_string(input))
    "ok"
  } catch {
    InconsistentTableCells(message~, ..) => message
    _ => "other"
  }
  assert_true(result.contains("inconsistent cell count"))
}
```

## i18n

Use `# language: xx` on the first line to parse non-English Gherkin.

```moonbit check
///|
test "parse French Gherkin" {
  let input =
    #|# language: fr
    #|Fonctionnalité: Connexion
    #|  Scénario: Succès
    #|    Soit un utilisateur
  let doc = parse(Source::from_string(input))
  let feature = doc.feature.unwrap()
  inspect(feature.language, content="fr")
  inspect(feature.keyword, content="Fonctionnalit\u00e9")
}
```
