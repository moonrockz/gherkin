# Push-Based Parsing

## Overview

In a push-based parser (also called an **event-driven** or **SAX-style** parser), the **parser drives** the process. The parser reads the input, identifies structural elements, and *pushes* events to a consumer by invoking callbacks or handler methods. The consumer does not control when or in what order events arrive -- it simply reacts to them.

This model originates from the SAX (Simple API for XML) parser, designed to handle large XML documents without loading them entirely into memory.

## How It Works

```
Input Stream --> [ Parser ] --events--> [ Handler / Listener ]
                   drives                  reacts
```

1. The parser reads the input token by token (or line by line).
2. When the parser recognizes a structural element, it emits an event.
3. The consumer's handler method for that event type is invoked synchronously.
4. The parser continues to the next element and repeats.

The consumer implements a **handler interface** (or trait) with methods for each event type. The parser calls these methods as it encounters corresponding structures.

## Concrete Example: SAX XML Parsing

```python
# Pseudocode illustrating a SAX-style handler
class MyHandler(ContentHandler):
    def start_element(self, name, attrs):
        print(f"Opening: {name}")

    def end_element(self, name):
        print(f"Closing: {name}")

    def characters(self, content):
        print(f"Text: {content}")

parser = SAXParser()
parser.set_handler(MyHandler())
parser.parse(input_stream)   # Parser drives -- consumer just reacts
```

The consumer has no say in ordering or timing. The parser calls `start_element`, `characters`, and `end_element` in document order as it scans through the input.

## Applied to Gherkin

For a push-based Gherkin parser, the parser would scan a `.feature` file and emit events like:

| Event | Data |
|---|---|
| `on_feature` | name, description, tags, location |
| `on_background` | name, description, location |
| `on_rule` | name, description, tags, location |
| `on_scenario` | name, description, tags, location |
| `on_step` | keyword, text, location |
| `on_doc_string` | content, media_type, location |
| `on_data_table` | rows, location |
| `on_examples` | name, tags, table_header, table_body, location |
| `on_comment` | text, location |
| `on_end_feature` | |
| `on_end_scenario` | |
| ... | |

A consumer implements a handler trait:

```
// Pseudocode in MoonBit style
trait GherkinHandler {
  on_feature(Self, Feature) -> Unit
  on_scenario(Self, Scenario) -> Unit
  on_step(Self, Step) -> Unit
  on_doc_string(Self, DocString) -> Unit
  on_data_table(Self, DataTable) -> Unit
  // ...
}
```

### Push Model: Event Lifecycle

Events in a push-based Gherkin parser follow a **nested lifecycle** matching document structure:

```
on_feature("Guess the word")
  on_background(...)
    on_step("Given", "a global administrator")
    on_step("And", "a blog named ...")
  on_end_background()
  on_scenario("Maker starts a game")
    on_step("When", "the Maker starts a game")
    on_step("Then", "the Maker waits for a Breaker")
  on_end_scenario()
  on_scenario("Breaker joins")
    on_step("Given", "the Maker has started a game")
      on_data_table([[...]])
    on_step("When", "the Breaker joins")
  on_end_scenario()
on_end_feature()
```

## Characteristics

### Advantages

- **Memory efficient**: No need to build a full AST in memory. Events are processed and discarded. Ideal for very large feature files or streaming scenarios.
- **Simple parser implementation**: The parser just needs to recognize elements and dispatch events. No tree construction logic required.
- **Streaming friendly**: Can begin processing before the entire input is available.
- **Natural fit for validation**: A handler that checks structural rules (e.g., "Feature must come first", "Steps must be inside a Scenario") maps cleanly to the event model.
- **Composable handlers**: Multiple handlers can be chained (e.g., a validator handler followed by a formatter handler) by wrapping or multicasting events.

### Disadvantages

- **Consumer must manage state**: Since events arrive one at a time, the consumer must track context manually (e.g., "am I inside a Scenario or a Background?"). This leads to state machine logic in the handler.
- **No lookahead or backtracking**: The consumer sees events in strict forward order. Correlating related elements (e.g., matching a Scenario's steps with its Examples table) requires buffering.
- **Inversion of control**: The parser controls flow. The consumer cannot pause, skip, or selectively process parts of the document without additional coordination.
- **Harder to build a tree**: If the consumer ultimately needs an AST, it must reconstruct the tree from the flat event stream, negating the memory advantage.

## When to Use Push-Based Parsing for Gherkin

- **Validation passes**: Check that a `.feature` file is well-formed without building a tree.
- **Reformatting / pretty-printing**: Emit formatted output as events arrive.
- **Streaming message protocol**: The official Cucumber project uses a push/event model for its *Gherkin messages* protocol, where parsers emit Protobuf messages consumed by downstream tools.
- **Statistics / analysis**: Count scenarios, steps, tags, etc. in a single pass.
- **Large-scale processing**: When processing thousands of feature files where holding ASTs in memory is undesirable.

## Relationship to Visitor Pattern

A push-based parser and a visitor are structurally similar -- both involve an external driver calling methods on a consumer. The key difference:

- **Push parser**: The *parser* drives, walking the *input text*.
- **Visitor**: The *visitor infrastructure* drives, walking an *already-built data structure* (AST).

A push parser can be thought of as a "visitor over the input stream." This similarity means that the handler interface for a push parser can be designed to closely mirror a visitor interface, enabling a clean adapter between the two. See [parser-visitor-integration.md](parser-visitor-integration.md) for design details.

## References

- SAX Project: https://www.saxproject.org/
- Cucumber Gherkin Messages: https://github.com/cucumber/messages
- "Event-Driven Parsing" in *Compilers: Principles, Techniques, and Tools* (Aho et al.)
