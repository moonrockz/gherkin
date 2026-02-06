# Parser-Visitor Integration for Gherkin

## Overview

This document describes how push-based and pull-based parsers integrate with the Visitor pattern, and outlines a unified architecture for a Gherkin parser that supports both models. The goal is a design where:

1. A **pull-based parser** (token iterator + recursive descent) serves as the core parsing engine.
2. A **push-based interface** (event handler / listener) is layered on top as an adapter.
3. A **Visitor** operates on the resulting AST for post-parse traversal and transformation.

All three are interoperable, enabling consumers to choose the model that best fits their use case.

## Push vs Pull: Side-by-Side Comparison

| Aspect | Push (SAX-style) | Pull (StAX-style) |
|---|---|---|
| **Who drives** | Parser | Consumer |
| **Control flow** | Inversion of control (callbacks) | Normal control flow (loop) |
| **State management** | Handler fields / state machine | Local variables in loop |
| **Early termination** | Requires special abort mechanism | Consumer simply stops calling `next()` |
| **Memory model** | Streaming, no tree needed | Streaming or tree-building |
| **Composability** | Handler chaining / multicasting | Iterator adapters (map, filter) |
| **Nesting** | Parser tracks begin/end | Consumer tracks nesting |
| **Multiple consumers** | Natural (multicast events) | Requires tee / buffer |
| **Tree building** | Consumer reconstructs from events | Natural recursive descent |
| **Best analogy** | Observer pattern | Iterator pattern |

## The Visitor Pattern

The Visitor pattern decouples **operations** from **data structure**. The data structure (AST) defines an `accept(visitor)` method, and the visitor defines a `visit_X` method for each node type. The structure drives traversal; the visitor supplies behavior.

```
// Pseudocode
trait GherkinVisitor {
  visit_feature(Self, Feature) -> Unit
  visit_rule(Self, Rule) -> Unit
  visit_scenario(Self, Scenario) -> Unit
  visit_step(Self, Step) -> Unit
  visit_doc_string(Self, DocString) -> Unit
  visit_data_table(Self, DataTable) -> Unit
  visit_examples(Self, Examples) -> Unit
  visit_background(Self, Background) -> Unit
  visit_comment(Self, Comment) -> Unit
  visit_tag(Self, Tag) -> Unit
}

// Each AST node
trait Visitable {
  accept(Self, GherkinVisitor) -> Unit
}
```

### Visitor vs Push Handler

These two interfaces look almost identical. The critical difference is **what is being traversed**:

| | Visitor | Push Handler |
|---|---|---|
| **Input** | AST (in-memory tree) | Raw text (input stream) |
| **Driver** | AST's `accept()` method | Parser's scan loop |
| **Requires tree** | Yes | No |
| **Can re-traverse** | Yes (tree persists) | No (events are transient) |

Because the interfaces are structurally similar, we can design them to share a common shape, enabling adapters between the two.

## Unified Architecture

```
                          ┌─────────────────────────┐
                          │      Input (.feature)    │
                          └────────────┬────────────┘
                                       │
                                       v
                          ┌─────────────────────────┐
                          │    Token Scanner (Pull)  │
                          │   line-by-line tokenizer │
                          └────────────┬────────────┘
                                       │ tokens (pull)
                                       v
                    ┌──────────────────────────────────────┐
                    │        Core Parser (Pull-based)      │
                    │     recursive descent over tokens     │
                    └───┬──────────────┬──────────────┬────┘
                        │              │              │
                   (A) build AST  (B) emit events  (C) pull events
                        │              │              │
                        v              v              v
                   ┌─────────┐  ┌───────────┐  ┌───────────────┐
                   │   AST   │  │   Push     │  │  Pull Event   │
                   │  (tree) │  │  Handler   │  │   Iterator    │
                   └────┬────┘  │ (callback) │  │  (consumer    │
                        │       └───────────┘  │   driven)     │
                        v                       └───────────────┘
                   ┌─────────┐
                   │ Visitor  │
                   │ traversal│
                   └─────────┘
```

### Path A: Pull Parser -> AST -> Visitor

The most common path. The parser builds a complete AST, then consumers traverse it with visitors.

```
let ast = Parser::parse(scanner)     // Pull-based: builds AST
ast.accept(my_visitor)                // Visitor: traverses AST
```

**Use cases**: IDE tooling, linting, transformation, code generation, test execution.

### Path B: Pull Parser -> Push Adapter -> Handler

A thin adapter pulls events from the core parser and pushes them to a handler. The handler never sees the parser directly.

```
let parser = Parser::new(scanner)
let adapter = PushAdapter::new(parser, my_handler)
adapter.run()   // Pulls from parser, pushes to handler
```

**Use cases**: Streaming validation, reformatting, statistics collection, message protocol emission.

### Path C: Pull Event Iterator

The consumer drives a loop, pulling structured events directly.

```
let reader = EventReader::new(scanner)
while reader.has_next() {
  match reader.next_event() {
    Feature(f) => ...
    Scenario(s) => ...
    _ => ()
  }
}
```

**Use cases**: Selective parsing, filtering by tags, incremental/partial parsing, testing.

## Design Details

### Shared Event/Node Types

The same data types serve both events (push/pull) and AST nodes:

```
// These types are used everywhere
struct Feature { name: String, description: String, tags: Array[Tag], location: Location }
struct Scenario { name: String, description: String, tags: Array[Tag], steps: Array[Step], location: Location }
struct Step { keyword: String, text: String, argument: StepArgument?, location: Location }
// ... etc
```

In push/pull event mode, `Scenario.steps` may be empty (steps arrive as separate events). In AST mode, `Scenario.steps` is fully populated.

To handle this cleanly, consider two type families:

1. **Event types** (flat): `FeatureEvent`, `ScenarioEvent`, `StepEvent` -- each carries only its own data.
2. **AST node types** (nested): `FeatureNode`, `ScenarioNode`, `StepNode` -- each carries its children.

### The Push Handler Trait

```
trait GherkinHandler {
  on_feature(Self, FeatureEvent) -> Unit
  on_end_feature(Self) -> Unit
  on_rule(Self, RuleEvent) -> Unit
  on_end_rule(Self) -> Unit
  on_background(Self, BackgroundEvent) -> Unit
  on_end_background(Self) -> Unit
  on_scenario(Self, ScenarioEvent) -> Unit
  on_end_scenario(Self) -> Unit
  on_step(Self, StepEvent) -> Unit
  on_doc_string(Self, DocStringEvent) -> Unit
  on_data_table(Self, DataTableEvent) -> Unit
  on_examples(Self, ExamplesEvent) -> Unit
  on_comment(Self, CommentEvent) -> Unit
  on_tag(Self, TagEvent) -> Unit
}
```

Default implementations do nothing, so consumers only override what they care about.

### The Visitor Trait

```
trait GherkinVisitor {
  visit_feature(Self, FeatureNode) -> Unit
  visit_rule(Self, RuleNode) -> Unit
  visit_background(Self, BackgroundNode) -> Unit
  visit_scenario(Self, ScenarioNode) -> Unit
  visit_step(Self, StepNode) -> Unit
  visit_doc_string(Self, DocStringNode) -> Unit
  visit_data_table(Self, DataTableNode) -> Unit
  visit_examples(Self, ExamplesNode) -> Unit
  visit_comment(Self, CommentNode) -> Unit
  visit_tag(Self, TagNode) -> Unit
}
```

Each AST node's `accept` method calls the corresponding `visit_*` method, then recursively accepts its children:

```
fn accept(self: FeatureNode, visitor: GherkinVisitor) -> Unit {
  visitor.visit_feature(self)
  for child in self.children {
    child.accept(visitor)
  }
}
```

### The Pull-to-Push Adapter

This is the bridge between paths. It pulls from the event reader and pushes to a handler:

```
struct PushAdapter {
  reader: EventReader
  handler: GherkinHandler
}

fn run(self: PushAdapter) -> Unit {
  while self.reader.has_next() {
    match self.reader.next_event() {
      Feature(f) => self.handler.on_feature(f)
      EndFeature => self.handler.on_end_feature()
      Scenario(s) => self.handler.on_scenario(s)
      EndScenario => self.handler.on_end_scenario()
      Step(s) => self.handler.on_step(s)
      // ...
    }
  }
}
```

### The AST Builder as a Handler

An AST builder can be implemented as a push handler, demonstrating that the push model can produce an AST:

```
struct AstBuilder : GherkinHandler {
  stack: Array[AstNode]  // Stack of partially-built nodes
}

fn on_feature(self: AstBuilder, event: FeatureEvent) -> Unit {
  self.stack.push(FeatureNode::new(event))
}

fn on_scenario(self: AstBuilder, event: ScenarioEvent) -> Unit {
  self.stack.push(ScenarioNode::new(event))
}

fn on_end_scenario(self: AstBuilder) -> Unit {
  let scenario = self.stack.pop()
  self.stack.top().add_child(scenario)
}

fn on_end_feature(self: AstBuilder) -> Unit {
  // Feature node is complete with all children
}
```

This is exactly how the official Cucumber Gherkin parser works -- its `AstBuilder` is a handler that receives events from the parser and constructs the AST.

## How the Official Cucumber Gherkin Parser Works

For reference, the official Cucumber Gherkin implementation uses this architecture:

1. **TokenScanner** (pull): Reads input line by line, produces `Token` objects.
2. **TokenMatcher** (pull): Matches tokens against expected types for the current parser state.
3. **Parser** (generated, push internally): A generated parser (from a grammar) that pulls tokens and calls `AstBuilder` methods (push).
4. **AstBuilder** (push handler): Receives events from the parser, builds a `GherkinDocument` AST.
5. **Compiler** (visitor-like): Walks the AST to produce `Pickle` messages (the normalized, executable form).

The parser itself is generated from a Berzerker grammar and acts as the bridge: it pulls tokens and pushes to the builder.

## Design Principles for Our Gherkin Parser

### 1. Pull at the Core

The token scanner and core parser should be pull-based. This gives us maximum flexibility -- pull can be adapted to push, but not easily the reverse.

### 2. Push as an Adapter

The push/event-handler interface should be a thin layer over the pull core. This keeps the push model available without duplicating parsing logic.

### 3. Visitor for Post-Parse

The Visitor operates on the AST after parsing. It should be the primary mechanism for analysis, transformation, and code generation. Multiple visitor variants (external, internal, cursor-based) serve different use cases -- see [visitor-variants.md](visitor-variants.md) for the full design space.

### 4. Common Type System

Event types and AST node types should share a common foundation. Events are "open" nodes (children not yet known); AST nodes are "closed" nodes (fully populated). Consider using a type parameter or separate type families to make this distinction clear.

### 5. Default Implementations

Both the handler trait and visitor trait should provide default no-op implementations. Consumers override only what they need.

### 6. Error Handling

Errors should be representable in all three models:
- **Pull**: Return an `Error` variant from `next_event()`.
- **Push**: Call an `on_error(error)` handler method.
- **Visitor**: Errors in the AST can be represented as error nodes, or the visitor can return `Result`.

## Summary: Choosing the Right Model

| Use Case | Recommended Model |
|---|---|
| Build complete AST for IDE / tooling | Pull parser -> AST -> Visitor |
| Stream validation (well-formedness) | Pull parser -> Push adapter -> Validator handler |
| Pretty-print / reformat | Pull parser -> Push adapter -> Formatter handler |
| Extract specific scenarios by tag | Pull event iterator (early termination) |
| Generate test code | Pull parser -> AST -> CodeGen visitor |
| Produce Cucumber messages | Pull parser -> Push adapter -> Message handler |
| Lint / style check | Pull parser -> AST -> Linter visitor |
| Count features/scenarios/steps | Pull parser -> Push adapter -> Counter handler |
| Incremental parsing (editor) | Pull event iterator (partial parse) |

## References

- *Design Patterns* (Gamma, Helm, Johnson, Vlissides) -- Visitor, Iterator, Observer
- Cucumber Gherkin source: https://github.com/cucumber/gherkin
- SAX vs StAX: https://docs.oracle.com/javase/tutorial/jaxp/stax/why.html
- [push-based-parsing.md](push-based-parsing.md)
- [pull-based-parsing.md](pull-based-parsing.md)
- [dom-based-representation.md](dom-based-representation.md)
- [visitor-variants.md](visitor-variants.md)
- [gherkin-tags.md](gherkin-tags.md)
