# Pull-Based Parsing

## Overview

In a pull-based parser (also called a **StAX-style** or **iterator-based** parser), the **consumer drives** the process. The consumer explicitly requests the next token or event from the parser, processes it, and decides when to advance. The parser is passive -- it produces the next element only when asked.

This model originates from StAX (Streaming API for XML), designed as a middle ground between DOM (full tree in memory) and SAX (event-driven, parser controls flow).

## How It Works

```
[ Consumer ] --next()--> [ Parser / Token Iterator ]
   drives                    responds on demand
```

1. The consumer calls a method like `next()`, `peek()`, or `advance()` on the parser.
2. The parser reads just enough of the input to produce the next token or event.
3. The consumer inspects the token and decides what to do.
4. The consumer calls `next()` again when ready, or stops early.

The parser exposes an **iterator interface** -- the consumer pulls tokens from it like items from a queue.

## Concrete Example: StAX XML Parsing

```java
// Pseudocode illustrating a StAX-style pull parser
XMLStreamReader reader = factory.createXMLStreamReader(input);

while (reader.hasNext()) {
    int event = reader.next();
    switch (event) {
        case START_ELEMENT:
            System.out.println("Opening: " + reader.getLocalName());
            break;
        case END_ELEMENT:
            System.out.println("Closing: " + reader.getLocalName());
            break;
        case CHARACTERS:
            System.out.println("Text: " + reader.getText());
            break;
    }
}
```

The consumer controls the loop. It can stop at any point, skip elements, or branch logic based on what it sees.

## Applied to Gherkin

For a pull-based Gherkin parser, the parser exposes an iterator over tokens or events:

### Token-Level Pull (Lexer)

At the lowest level, a pull-based lexer produces tokens:

| Token Type | Value |
|---|---|
| `TagLine` | `@smoke @regression` |
| `FeatureLine` | `Feature: Guess the word` |
| `DescriptionLine` | `The word guess game is...` |
| `BackgroundLine` | `Background:` |
| `ScenarioLine` | `Scenario: Maker starts a game` |
| `StepLine` | `When the Maker starts a game` |
| `DocStringSeparator` | `"""` |
| `DocStringContent` | `Some content here` |
| `TableRow` | `\| name \| email \|` |
| `ExamplesLine` | `Examples:` |
| `Comment` | `# This is a comment` |
| `Empty` | *(blank line)* |
| `EOF` | *(end of input)* |

```
// Pseudocode in MoonBit style
trait TokenIterator {
  next(Self) -> Token
  peek(Self) -> Token
  has_next(Self) -> Bool
}
```

### Event-Level Pull (Parser)

At a higher level, the parser can produce structured events (like the push model, but pulled):

```
// Pseudocode in MoonBit style
enum GherkinEvent {
  Feature(Feature)
  Background(Background)
  Scenario(Scenario)
  Step(Step)
  DocString(DocString)
  DataTable(DataTable)
  Examples(Examples)
  EndFeature
  EndScenario
  EndBackground
  // ...
}

trait GherkinReader {
  next_event(Self) -> GherkinEvent?
  peek_event(Self) -> GherkinEvent?
}
```

### Consumer-Driven Processing

```
// Pseudocode: consumer pulls events
let reader = GherkinReader::new(input)

while reader.has_next() {
  match reader.next_event() {
    Feature(f) => {
      // Process feature, decide whether to continue
      process_feature(f)
    }
    Scenario(s) => {
      if s.tags.contains("@skip") {
        reader.skip_until(EndScenario)  // Consumer controls skipping
      } else {
        process_scenario(s)
      }
    }
    Step(step) => process_step(step)
    _ => ()  // Ignore other events
  }
}
```

## Characteristics

### Advantages

- **Consumer controls flow**: The consumer decides when to advance, what to process, and when to stop. This is natural for conditional processing (e.g., "only parse scenarios tagged @smoke").
- **Early termination**: The consumer can stop parsing as soon as it has what it needs, without processing the rest of the input.
- **Easier state management**: Since the consumer drives a sequential loop, its state is local variables in the loop body rather than fields in a handler object. No state machine required.
- **Composable and chainable**: Pull parsers compose naturally. A filtering layer can wrap the base parser, pulling and selectively forwarding events. This is analogous to iterator adapters (map, filter, take_while).
- **Natural for tree building**: The consumer can recursively descend by pulling events, building subtrees as it goes. The call stack naturally mirrors the document nesting.
- **Peek / lookahead**: The consumer can peek at the next event without consuming it, enabling lookahead decisions.

### Disadvantages

- **Slightly more complex API**: The consumer must understand the event protocol and explicitly advance through it. Missing a `next()` call or mishandling nesting leads to subtle bugs.
- **Consumer must handle nesting**: In a push model, the parser handles begin/end pairing. In a pull model, the consumer must track nesting depth or recursively process nested structures.
- **Less natural for multicasting**: Sending the same event stream to multiple consumers requires either buffering or explicit fan-out logic.
- **Lazy evaluation complexity**: If the parser is truly lazy (reads input only on demand), error reporting for malformed input may be delayed until the consumer pulls past the error point.

## When to Use Pull-Based Parsing for Gherkin

- **Selective processing**: Parse only certain scenarios (by tag, name, or position) without processing the entire file.
- **AST construction**: Build a Gherkin AST by recursively pulling events. The recursive descent naturally mirrors Feature > Rule > Scenario > Step nesting.
- **Pipeline composition**: Chain parser stages (tokenizer -> event parser -> filter -> AST builder) where each stage pulls from the previous one.
- **Interactive / incremental parsing**: In editor tooling (LSP), parse up to the cursor position and stop.
- **Testing**: Pull specific tokens or events in tests without needing to set up full handler infrastructure.

## The Two-Level Architecture

A practical Gherkin parser often uses pull-based parsing at **two levels**:

### Level 1: Token Scanner (Pull)

A lexer/scanner that reads input line-by-line and produces tokens. This is almost always pull-based because the parser grammar needs to inspect the next token to decide what production rule to apply.

```
Input Text --> [ Scanner ] --pull--> tokens
```

### Level 2: Event/AST Parser

The parser pulls tokens from the scanner and either:
- **Produces events** (pull-based event parser) that a consumer pulls, or
- **Builds an AST directly** (traditional recursive descent parser)

```
tokens --> [ Parser ] --pull--> events --> [ Consumer ]
                   or
tokens --> [ Parser ] --> AST
```

The official Cucumber Gherkin parser uses this two-level architecture: a `TokenScanner` (pull) feeds a `Parser` that builds an AST via recursive descent.

## Relationship to Visitor Pattern

A pull-based parser and a visitor serve different phases:

- **Pull parser**: Reads input and produces tokens/events. Operates on *text*.
- **Visitor**: Traverses a *data structure* (AST). Operates on *structured data*.

The typical flow is: pull parser builds an AST, then a visitor traverses it. However, a pull parser can also drive a visitor directly by pulling events and dispatching them as visitor calls (a **pull-to-push adapter**). See [parser-visitor-integration.md](parser-visitor-integration.md) for design details.

## References

- StAX Tutorial: https://docs.oracle.com/javase/tutorial/jaxp/stax/
- Cucumber Gherkin Token Scanner: https://github.com/cucumber/gherkin
- "Iterator Pattern" in *Design Patterns* (Gamma et al.)
- Rob Pike, "Lexical Scanning in Go" (talk on pull-based lexer design)
