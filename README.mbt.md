# moonrockz/gherkin

A [Gherkin](https://cucumber.io/docs/gherkin/) parser for MoonBit. Parses `.feature` files used in Behavior-Driven Development (BDD) with Cucumber and similar frameworks.

## Installation

```bash
moon add moonrockz/gherkin
```

## Quick Start

```moonbit skip nocheck
let source = @gherkin.Source::from_string(
  "Feature: Login\n  Scenario: Success\n    Given a user\n    When they log in\n    Then they see the dashboard",
)
let doc = @gherkin.parse!(source)
let feature = doc.feature.unwrap()
// feature.name == "Login"
```

## Four Parsing APIs

### DOM-Based

Parse to a full AST for random access to the document tree.

```moonbit skip nocheck
let doc = @gherkin.parse!(source)
// doc.feature, doc.comments — full tree
```

### Visitor Pattern

Traverse the AST depth-first, overriding only the node types you care about.

```moonbit skip nocheck
doc.accept(my_visitor)
```

### Functional Fold

Thread an accumulator through the tree with flow control (`Continue`, `SkipChildren`, `Stop`).

```moonbit skip nocheck
let count = doc.fold(0, {
  ..@gherkin.GherkinFold::default(),
  visit_step: @gherkin.continuing(fn(n, _) { n + 1 }),
})
```

### SAX-Style Handler

Push-based event-driven parsing without building an AST.

```moonbit skip nocheck
@gherkin.parse_with_handler!(source, my_handler)
```

## CLI

Parse a `.feature` file to JSON:

```bash
moon run src/cmd/main -- path/to/file.feature
```

Parse from stdin:

```bash
echo "Feature: Test" | moon run src/cmd/main -- -
```

## License

Apache-2.0
