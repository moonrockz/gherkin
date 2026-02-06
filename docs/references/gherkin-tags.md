# Gherkin Tags: Syntax, Semantics, and Data Model

## Overview

Tags are a core mechanism in Gherkin for **annotating** and **organizing**
features, rules, scenarios, scenario outlines, and examples tables. They serve
multiple purposes: filtering which tests to run, grouping related scenarios,
attaching metadata, and controlling hook execution.

A robust Gherkin parser must handle tags as first-class citizens with proper
data types -- not as bare strings.

## Syntax

### Basic Form

A tag is an `@` character followed by a tag name. Tags are placed on the line
**above** the element they annotate:

```gherkin
@smoke @regression
Feature: User login

  @happy-path
  Scenario: Successful login
    Given a registered user
    When they enter valid credentials
    Then they are logged in
```

### Tag Name Rules

- A tag name starts with `@` followed by one or more characters.
- Valid characters: letters, digits, hyphens (`-`), underscores (`_`),
  periods (`.`), colons (`:`).
- Tags are **case-sensitive**: `@Smoke` and `@smoke` are different tags.
- Multiple tags can appear on the same line, separated by whitespace.
- Tags can also span multiple lines above an element.

```gherkin
@smoke @ui
@jira:PROJ-1234
@priority:high
Scenario: Complex login flow
```

### Where Tags Can Be Placed

Tags can appear before:

| Element | Example |
|---|---|
| `Feature` | `@smoke Feature: ...` |
| `Rule` | `@business-rule Rule: ...` |
| `Scenario` / `Example` | `@happy-path Scenario: ...` |
| `Scenario Outline` / `Scenario Template` | `@parameterized Scenario Outline: ...` |
| `Examples` / `Scenarios` table | `@dataset-a Examples:` |

Tags **cannot** appear before:

- `Background` (backgrounds inherit the Feature's tags)
- `Given` / `When` / `Then` / `And` / `But` (individual steps)
- `Doc Strings` or `Data Tables`

## Tag Inheritance

Tags follow an **inheritance** model where tags from parent elements
propagate down to children:

```
Feature tags     -->  inherited by all Scenarios, Rules
Rule tags        -->  inherited by all Scenarios within that Rule
Scenario Outline -->  inherited by all Examples tables
```

### Example

```gherkin
@feature-tag
Feature: Shopping cart

  @rule-tag
  Rule: Discounts apply for members

    @scenario-tag
    Scenario: Member discount
      Given ...
```

The `Member discount` scenario has **effective tags**:
`[@feature-tag, @rule-tag, @scenario-tag]`

### Examples Table Inheritance

```gherkin
@outline-tag
Scenario Outline: Parameterized login
  Given a user with role "<role>"
  When they login
  Then they see the "<page>" page

  @admin-data
  Examples: Admin users
    | role  | page      |
    | admin | dashboard |

  @basic-data
  Examples: Basic users
    | role  | page   |
    | user  | home   |
```

The "Admin users" examples inherit `@outline-tag` and have `@admin-data`.
The "Basic users" examples inherit `@outline-tag` and have `@basic-data`.

When the outline is expanded, each generated scenario gets:
- Tags from the Feature
- Tags from the Scenario Outline
- Tags from the specific Examples table

## Tag Expressions

Tag expressions allow boolean filtering of scenarios by their tags. This is
not part of the Gherkin *syntax* (it's a runtime/tooling concern), but the
parser's data model must support it efficiently.

### Expression Syntax

```
@smoke                      -- has tag @smoke
not @slow                   -- does not have tag @slow
@smoke and @ui              -- has both
@smoke or @api              -- has either
@smoke and not @wip         -- has @smoke but not @wip
(@smoke or @regression) and not @slow  -- grouping with parens
```

### Tag Expression AST

```
enum TagExpression {
  Tag(TagName)                           // Leaf: a single tag
  Not(TagExpression)                     // Negation
  And(TagExpression, TagExpression)      // Conjunction
  Or(TagExpression, TagExpression)       // Disjunction
}
```

### Evaluation

```
fn evaluate(self: TagExpression, tags: Array[TagName]) -> Bool {
  match self {
    Tag(name) => tags.contains(name)
    Not(expr) => not expr.evaluate(tags)
    And(left, right) => left.evaluate(tags) and right.evaluate(tags)
    Or(left, right) => left.evaluate(tags) or right.evaluate(tags)
  }
}
```

## Data Model: Avoiding Primitive Obsession

### Bad: Tags as Strings

```
// DO NOT do this
struct Scenario {
  tags: Array[String]   // Primitive obsession: "@smoke" is just a string
  // ...
}
```

Problems:
- No validation at construction time. `""`, `"not a tag"`, `"@"` are all
  valid `String`s but not valid tags.
- The `@` prefix may or may not be included -- consumers must handle both.
- No distinction between a raw tag string and a parsed tag with location.
- Tag inheritance is stringly-typed and error-prone.

### Good: Tags as ADTs

```
/// A tag name, guaranteed to be well-formed at construction.
/// Stores the name WITHOUT the '@' prefix.
struct TagName {
  priv value: String
}

/// Smart constructor: validates and normalizes
fn TagName::new(raw: String) -> Result[TagName, TagError] {
  let name = if raw.starts_with("@") { raw.substring(1) } else { raw }
  if name.is_empty() {
    Err(TagError::Empty)
  } else if not name.chars().all(is_valid_tag_char) {
    Err(TagError::InvalidCharacter(name))
  } else {
    Ok(TagName { value: name })
  }
}

/// Display always includes the '@' prefix
fn to_string(self: TagName) -> String {
  "@" + self.value
}

/// A tag as it appears in source: name + location
struct Tag {
  name: TagName
  location: Location
}

/// Tag-related errors
enum TagError {
  Empty
  InvalidCharacter(String)
}
```

### Tag Collections

Since tags have set-like semantics (a scenario either has a tag or doesn't,
duplicates are meaningless), consider a dedicated collection:

```
/// An ordered set of tags preserving source order.
/// Provides efficient membership testing.
struct TagSet {
  priv tags: Array[Tag]
  priv index: Map[TagName, Int]  // name -> position for O(1) lookup
}

fn TagSet::from_array(tags: Array[Tag]) -> TagSet { ... }
fn contains(self: TagSet, name: TagName) -> Bool { ... }
fn iter(self: TagSet) -> Iter[Tag] { ... }
fn union(self: TagSet, other: TagSet) -> TagSet { ... }  // For inheritance
fn to_array(self: TagSet) -> Array[Tag] { ... }
```

### Effective Tags (Inheritance-Aware)

To distinguish between **declared tags** (written directly on the element) and
**effective tags** (including inherited tags), use distinct types:

```
/// Tags declared directly on an element
struct DeclaredTags {
  tags: TagSet
}

/// Tags effective on an element (declared + inherited)
struct EffectiveTags {
  declared: TagSet     // Tags written on this element
  inherited: TagSet    // Tags inherited from parent elements
}

fn all(self: EffectiveTags) -> TagSet {
  self.declared.union(self.inherited)
}

fn is_declared(self: EffectiveTags, name: TagName) -> Bool {
  self.declared.contains(name)
}

fn is_inherited(self: EffectiveTags, name: TagName) -> Bool {
  self.inherited.contains(name)
}
```

### Structured Tags

Some teams use **structured tag conventions** like `@jira:PROJ-123` or
`@priority:high`. The parser can optionally support parsing these:

```
enum TagValue {
  Simple(TagName)                        // @smoke
  KeyValue(TagName, String)              // @jira:PROJ-123
}

// Or, keep it in TagName and let consumers parse the structure:
fn namespace(self: TagName) -> String? {
  match self.value.split_once(":") {
    Some((ns, _)) => Some(ns)
    None => None
  }
}

fn value(self: TagName) -> String? {
  match self.value.split_once(":") {
    Some((_, v)) => Some(v)
    None => None
  }
}
```

**Recommendation**: Keep `TagName` simple (the parser doesn't interpret
internal structure). Provide helper methods for consumers who use conventions
like `key:value`. This keeps the parser orthogonal to team conventions.

## Tags in the DOM

### Feature

```
struct Feature {
  tags: TagSet          // Declared tags on the Feature
  // ...
}
```

### Rule

```
struct Rule {
  tags: TagSet          // Declared tags on the Rule
  // ...
}

fn effective_tags(self: Rule, feature: Feature) -> EffectiveTags {
  EffectiveTags {
    declared: self.tags,
    inherited: feature.tags,
  }
}
```

### Scenario

```
struct Scenario {
  tags: TagSet          // Declared tags on the Scenario
  // ...
}

fn effective_tags(self: Scenario, ancestors: Array[TagSet]) -> EffectiveTags {
  EffectiveTags {
    declared: self.tags,
    inherited: ancestors.fold(TagSet::empty(), |acc, ts| acc.union(ts)),
  }
}
```

### Examples

```
struct Examples {
  tags: TagSet          // Declared tags on the Examples table
  // ...
}
```

## Tags in Each Parser Model

### Push Model

Tags are emitted as events before the element they annotate:

```
on_tag(Tag { name: "@smoke", location: (1, 1) })
on_tag(Tag { name: "@regression", location: (1, 8) })
on_feature(FeatureEvent { name: "User login", ... })
```

The handler accumulates tags and associates them with the next element.

### Pull Model

Tags are part of the element's event:

```
match reader.next_event() {
  Feature(FeatureEvent { tags: [@smoke, @regression], ... }) => ...
}
```

Or, tags can be separate events that the consumer accumulates:

```
match reader.next_event() {
  Tags([@smoke, @regression]) => pending_tags = ...
  Feature(FeatureEvent { ... }) => // attach pending_tags
}
```

**Recommendation**: Include tags directly in element events (pull model) for
ergonomics. Emit them as separate events in the push model (for streaming
consumers that process tags independently).

### DOM Model

Tags are stored in the node as a `TagSet`:

```
let feature = document.feature!
for tag in feature.tags.iter() {
  println(tag.name)  // @smoke, @regression
}
```

### Visitor Model

Tags can be visited as children of their parent element:

```
fn visit_tag(self: MyVisitor, tag: Tag) -> Unit {
  // Called for each tag on each element
}
```

Or, tags can be accessed as a property of the visited element:

```
fn visit_scenario(self: MyVisitor, scenario: Scenario) -> Unit {
  if scenario.tags.contains(TagName::new("@smoke")!) {
    // Handle smoke-tagged scenario
  }
}
```

**Recommendation**: Support both. Tags are visited as child nodes in
external/internal visitors (for completeness), AND accessible as properties
on the parent node (for convenience).

## Tag Expressions in the Parser Architecture

Tag expressions belong at the **consumer layer**, not in the parser itself.
The parser produces the AST with raw tags; consumers apply tag expressions
for filtering.

```
                         ┌──────────────┐
                         │  Tag         │
     Parse-time          │  Expression  │     Runtime
                         │  Parser      │
                         └──────┬───────┘
                                │
                                v
┌──────────┐    ┌──────┐    ┌──────────────┐    ┌──────────┐
│ .feature │ -> │Parser│ -> │ DOM with     │ -> │ Filter   │ -> selected
│ file     │    │      │    │ TagSets      │    │ by expr  │    scenarios
└──────────┘    └──────┘    └──────────────┘    └──────────┘
```

The tag expression parser is a separate, small parser that produces a
`TagExpression` AST. This keeps the Gherkin parser focused on syntax and the
tag expression logic reusable across different contexts.

## References

- Cucumber Tag Expressions: https://github.com/cucumber/tag-expressions
- Gherkin Reference (tags section): see [gherkin-reference.md](../specs/gherkin-reference.md)
- [dom-based-representation.md](dom-based-representation.md)
- [parser-visitor-integration.md](parser-visitor-integration.md)
- [visitor-variants.md](visitor-variants.md)
