# DOM-Based Gherkin Representation

## Overview

A DOM (Document Object Model) representation provides a **complete, in-memory tree** of a Gherkin document. Unlike the streaming models (push and pull), a DOM materializes the entire document structure as a navigable, queryable, and mutable object graph. Consumers can traverse the tree in any direction, inspect any node at any time, and modify the structure.

This model originates from the W3C DOM for HTML/XML, where the entire document is loaded into memory as a tree of nodes that can be traversed, queried, and manipulated programmatically.

## How It Works

```
Input (.feature) --> [ Parser ] --> [ GherkinDocument (DOM tree) ]
                                            |
                                     full tree in memory
                                            |
                                    traverse / query / mutate
```

1. The parser reads the entire input and builds a complete tree.
2. The tree is returned to the consumer as a single root object.
3. The consumer navigates the tree freely -- parent, children, siblings, arbitrary lookup.
4. The consumer can modify the tree (add, remove, replace nodes) and serialize it back.

## The Gherkin DOM Tree

A Gherkin document has a natural hierarchical structure:

```
GherkinDocument
├── Feature
│   ├── tags: [Tag]
│   ├── name: String
│   ├── description: String
│   ├── children: [FeatureChild]
│   │   ├── Background
│   │   │   ├── name: String
│   │   │   └── steps: [Step]
│   │   │       ├── keyword: String
│   │   │       ├── text: String
│   │   │       └── argument: DocString | DataTable | None
│   │   ├── Scenario
│   │   │   ├── tags: [Tag]
│   │   │   ├── name: String
│   │   │   ├── description: String
│   │   │   ├── steps: [Step]
│   │   │   └── examples: [Examples]
│   │   │       ├── tags: [Tag]
│   │   │       ├── name: String
│   │   │       ├── table_header: TableRow
│   │   │       └── table_body: [TableRow]
│   │   └── Rule
│   │       ├── tags: [Tag]
│   │       ├── name: String
│   │       ├── description: String
│   │       └── children: [RuleChild]
│   │           ├── Background
│   │           └── Scenario
│   └── comments: [Comment]
└── comments: [Comment]
```

### Node Types

```
// Pseudocode in MoonBit style

struct GherkinDocument {
  feature: Feature?
  comments: Array[Comment]
}

struct Feature {
  tags: Array[Tag]
  location: Location
  language: String
  keyword: String
  name: String
  description: String
  children: Array[FeatureChild]
}

enum FeatureChild {
  Background(Background)
  Scenario(Scenario)
  Rule(Rule)
}

struct Rule {
  tags: Array[Tag]
  location: Location
  keyword: String
  name: String
  description: String
  children: Array[RuleChild]
}

enum RuleChild {
  Background(Background)
  Scenario(Scenario)
}

struct Background {
  location: Location
  keyword: String
  name: String
  description: String
  steps: Array[Step]
}

struct Scenario {
  tags: Array[Tag]
  location: Location
  keyword: String
  name: String
  description: String
  steps: Array[Step]
  examples: Array[Examples]
}

struct Step {
  location: Location
  keyword: String
  keyword_type: KeywordType  // Context, Action, Outcome, Conjunction, Unknown
  text: String
  argument: StepArgument?
}

enum StepArgument {
  DocString(DocString)
  DataTable(DataTable)
}

struct DocString {
  location: Location
  media_type: String?
  content: String
  delimiter: String
}

struct DataTable {
  location: Location
  rows: Array[TableRow]
}

struct TableRow {
  location: Location
  cells: Array[TableCell]
}

struct TableCell {
  location: Location
  value: String
}

struct Examples {
  tags: Array[Tag]
  location: Location
  keyword: String
  name: String
  description: String
  table_header: TableRow?
  table_body: Array[TableRow]
}

struct Tag {
  location: Location
  name: String   // includes the '@' prefix
  id: String
}

struct Comment {
  location: Location
  text: String
}

struct Location {
  line: Int
  column: Int?
}

enum KeywordType {
  Context      // Given
  Action       // When
  Outcome      // Then
  Conjunction  // And, But
  Unknown      // *
}
```

## DOM vs Streaming: Comparison

| Aspect | DOM | Push (SAX) | Pull (StAX) |
|---|---|---|---|
| **Memory** | Full tree in memory | Minimal (event at a time) | Minimal (event at a time) |
| **Random access** | Yes (any node, any time) | No (forward-only) | No (forward-only) |
| **Mutation** | Yes (add, remove, modify) | No | No |
| **Re-traversal** | Yes (unlimited passes) | No (single pass) | No (single pass unless rewound) |
| **Navigation** | Parent, child, sibling | Forward events only | Forward events only |
| **Query** | Find by tag, name, type | Must filter during stream | Must filter during stream |
| **Serialization** | Round-trip (parse -> modify -> write) | One-way (parse) | One-way (parse) |
| **Latency** | Must parse entire document first | Can begin processing immediately | Can begin processing immediately |
| **Best for** | Analysis, transformation, tooling | Validation, streaming | Selective parsing, pipelines |

## Operations Enabled by DOM

### 1. Navigation

```
// Walk up to the parent
let feature = scenario.parent   // -> Feature or Rule

// Walk siblings
let next_scenario = feature.children[idx + 1]

// Deep lookup
let all_steps = document.feature.scenarios().flat_map(|s| s.steps)
```

### 2. Querying

```
// Find all scenarios with a specific tag
let smoke_tests = document.feature
  .scenarios()
  .filter(|s| s.tags.any(|t| t.name == "@smoke"))

// Find all steps matching a pattern
let given_steps = document.feature
  .scenarios()
  .flat_map(|s| s.steps)
  .filter(|step| step.keyword_type == Context)
```

### 3. Mutation

```
// Add a tag to a scenario
scenario.tags.push(Tag { name: "@wip", location: ... })

// Remove a scenario
feature.children.remove(idx)

// Replace a step's text
step.text = "the updated step text"
```

### 4. Serialization (Round-Trip)

```
// Parse -> Modify -> Write back
let document = Parser::parse(input)
document.feature.children.push(new_scenario)
let output = Formatter::format(document)  // Back to .feature text
```

## DOM + Visitor Integration

The DOM and Visitor pattern are **complementary**. The DOM provides the data structure; the Visitor provides the traversal mechanism and pluggable operations.

### Accept/Visit Protocol

Each DOM node implements `accept`:

```
fn accept(self: GherkinDocument, visitor: GherkinVisitor) -> Unit {
  visitor.visit_document(self)
  for comment in self.comments {
    comment.accept(visitor)
  }
  if self.feature is Some(feature) {
    feature.accept(visitor)
  }
}

fn accept(self: Feature, visitor: GherkinVisitor) -> Unit {
  visitor.visit_feature(self)
  for tag in self.tags {
    tag.accept(visitor)
  }
  for child in self.children {
    match child {
      Background(bg) => bg.accept(visitor)
      Scenario(sc) => sc.accept(visitor)
      Rule(rule) => rule.accept(visitor)
    }
  }
}

fn accept(self: Scenario, visitor: GherkinVisitor) -> Unit {
  visitor.visit_scenario(self)
  for tag in self.tags {
    tag.accept(visitor)
  }
  for step in self.steps {
    step.accept(visitor)
  }
  for examples in self.examples {
    examples.accept(visitor)
  }
}
```

### Visitor Examples on the DOM

**Counting visitor:**
```
struct CountVisitor {
  mut features: Int
  mut scenarios: Int
  mut steps: Int
}

fn visit_feature(self: CountVisitor, _f: Feature) -> Unit { self.features += 1 }
fn visit_scenario(self: CountVisitor, _s: Scenario) -> Unit { self.scenarios += 1 }
fn visit_step(self: CountVisitor, _s: Step) -> Unit { self.steps += 1 }
```

**Tag collector visitor:**
```
struct TagCollector {
  tags: Map[String, Array[Location]]
}

fn visit_tag(self: TagCollector, tag: Tag) -> Unit {
  self.tags.get_or_insert(tag.name, []).push(tag.location)
}
```

**Pretty-printer visitor:**
```
struct PrettyPrinter {
  mut indent: Int
  output: StringBuilder
}

fn visit_feature(self: PrettyPrinter, f: Feature) -> Unit {
  self.write_tags(f.tags)
  self.writeln(f.keyword + ": " + f.name)
  self.indent += 1
}

fn visit_scenario(self: PrettyPrinter, s: Scenario) -> Unit {
  self.writeln("")
  self.write_tags(s.tags)
  self.writeln(s.keyword + ": " + s.name)
  self.indent += 1
}

fn visit_step(self: PrettyPrinter, s: Step) -> Unit {
  self.writeln(s.keyword + s.text)
}
```

## DOM + Push Handler: Building the DOM

The DOM is typically **built** using the push handler interface. The parser pushes events, and an `AstBuilder` handler assembles them into the DOM tree:

```
                     push events
[ Parser ] ──────────────────────> [ AstBuilder (Handler) ]
                                          │
                                          v
                                   [ GherkinDocument (DOM) ]
                                          │
                                          v
                                   [ Visitor traversal ]
```

This is the standard pipeline:
1. Parser scans input (pull-based internally).
2. Parser emits events to AstBuilder (push interface).
3. AstBuilder constructs the DOM.
4. Consumers traverse the DOM with visitors.

## Immutable vs Mutable DOM

### Immutable DOM

Nodes are created once during parsing and never modified. To "change" a node, create a new node with the desired modifications (structural sharing where possible).

**Advantages**: Thread-safe, no aliasing bugs, cache-friendly, easier to reason about.
**Best for**: Analysis, read-only tooling, parallel processing.

### Mutable DOM

Nodes can be modified in place after construction.

**Advantages**: Simpler for transformation workflows (add/remove/modify nodes).
**Best for**: Refactoring tools, formatters, editor integrations that modify documents.

### Recommendation for Gherkin

Start with an **immutable DOM** as the default. Provide builder methods for constructing modified copies:

```
// Immutable style: returns a new Scenario with the added tag
fn with_tag(self: Scenario, tag: Tag) -> Scenario {
  Scenario { tags: self.tags + [tag], ..self }
}

// Immutable style: returns a new Feature with filtered children
fn without_scenario(self: Feature, name: String) -> Feature {
  Feature {
    children: self.children.filter(|c| match c {
      Scenario(s) => s.name != name
      _ => true
    }),
    ..self
  }
}
```

This aligns with MoonBit's emphasis on value types and functional patterns.

## When to Use DOM-Based Representation

| Use Case | Why DOM |
|---|---|
| IDE / editor integration | Random access to any node, location-based lookup, incremental updates |
| Linting / style checking | Multiple passes over the tree, cross-node analysis |
| Refactoring tools | Need to modify and serialize back |
| Code generation | Walk tree to produce test code |
| Cucumber Pickle compilation | Walk AST to produce normalized executable scenarios |
| Diff / merge tools | Compare two DOMs structurally |
| Documentation generation | Extract and organize feature documentation |
| Test filtering by tag | Query scenarios by tag without re-parsing |

## Complete Architecture: DOM + Push + Pull + Visitor

```
                          ┌─────────────────────────┐
                          │      Input (.feature)    │
                          └────────────┬────────────┘
                                       │
                                       v
                          ┌─────────────────────────┐
                          │    Token Scanner (Pull)  │
                          └────────────┬────────────┘
                                       │ tokens
                                       v
                    ┌──────────────────────────────────────┐
                    │        Core Parser (Pull-based)      │
                    └───┬──────────────┬──────────────┬────┘
                        │              │              │
                   (A) AST         (B) push       (C) pull
                   Builder         adapter        events
                        │              │              │
                        v              v              v
                   ┌─────────┐  ┌───────────┐  ┌───────────┐
                   │  DOM     │  │  Handler  │  │  Event    │
                   │ (tree)   │  │ (callback)│  │  Iterator │
                   └────┬────┘  └───────────┘  └───────────┘
                        │
            ┌───────────┼───────────┐
            │           │           │
            v           v           v
       ┌─────────┐ ┌────────┐ ┌──────────┐
       │ Visitor  │ │ Query  │ │ Mutate + │
       │ (walk)   │ │ (find) │ │ Serialize│
       └─────────┘ └────────┘ └──────────┘
```

All four models (DOM, push, pull, visitor) are interconnected:

- **Pull** is the parsing core.
- **Push** is an adapter over pull.
- **DOM** is built by a push handler (AstBuilder).
- **Visitor** traverses the DOM.
- **Pull events** can also be produced from the DOM (DOM-to-pull adapter) for consumers that prefer the streaming interface but want to work with a parsed document.

## References

- W3C DOM specification: https://www.w3.org/DOM/
- Cucumber GherkinDocument: https://github.com/cucumber/messages (see `GherkinDocument` message)
- *Design Patterns* (Gamma et al.) -- Composite pattern (tree), Visitor pattern, Builder pattern
- [push-based-parsing.md](push-based-parsing.md)
- [pull-based-parsing.md](pull-based-parsing.md)
- [parser-visitor-integration.md](parser-visitor-integration.md)
- [visitor-variants.md](visitor-variants.md)
- [gherkin-tags.md](gherkin-tags.md)
