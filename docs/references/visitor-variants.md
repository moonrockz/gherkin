# Visitor Variants: External, Internal, and Cursor-Based

## Overview

The classic Visitor pattern from the Gang of Four book describes one specific
configuration: the data structure controls traversal, and the visitor supplies
behavior. But this is only one point in a design space. Visitors differ along
two axes:

1. **Who controls traversal** -- the data structure (external) or the visitor (internal)?
2. **How position is represented** -- implicitly via the call stack, or explicitly via a cursor?

This document covers three visitor variants and how each applies to Gherkin AST
traversal. Our parser should support all three, because different use cases
demand different levels of control.

```
                     Traversal controlled by:
                     Structure          Visitor
                   ┌──────────────┬──────────────┐
  Position via     │              │              │
  call stack       │   External   │   Internal   │
                   │   Visitor    │   Visitor    │
                   ├──────────────┼──────────────┤
  Position via     │   Cursor +   │   Cursor     │
  explicit focus   │   External   │   (Zipper)   │
                   └──────────────┴──────────────┘
```

---

## External Visitor

### Definition

In an **external visitor**, the **data structure controls traversal**. Each AST
node has an `accept` method that:

1. Calls the visitor's corresponding `visit_*` method.
2. Recursively calls `accept` on its children.

The visitor provides behavior but has **no say** in traversal order, which
children are visited, or when to stop.

### Structure

```
// The data structure drives
fn accept(self: Feature, visitor: &GherkinVisitor) -> Unit {
  visitor.visit_feature(self)          // 1. Visit this node
  for tag in self.tags {               // 2. Structure decides child order
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

// The visitor only supplies behavior
trait GherkinVisitor {
  visit_feature(Self, Feature) -> Unit
  visit_scenario(Self, Scenario) -> Unit
  visit_step(Self, Step) -> Unit
  // ... one method per node type
}
```

### Characteristics

| Property | Value |
|---|---|
| Traversal control | Data structure (`accept`) |
| Traversal order | Fixed (defined once in `accept`) |
| Can skip subtrees | No (visitor has no way to signal "stop") |
| Can change order | No |
| Early termination | Not without exceptions or special flags |
| Adding new operations | Easy (new visitor impl) |
| Adding new node types | Hard (must update all visitors) |
| State management | Visitor fields |
| Best analogy | Hollywood Principle: "don't call us, we'll call you" |

### When to Use for Gherkin

- **Simple aggregation**: Counting features, scenarios, steps.
- **Collection**: Gathering all tags, all step texts, all locations.
- **Uniform operations**: Pretty-printing, serialization, where every node is
  handled the same way regardless of context.
- **Guaranteed completeness**: You want to be sure every node is visited
  exactly once in document order.

### Limitation: The Expression Problem

External visitors suffer from the **expression problem**: adding a new node
type (e.g., a hypothetical `RuleGroup`) requires updating the visitor trait
*and* all existing visitor implementations. In MoonBit, the compiler will
flag this as a non-exhaustive match if the visitor uses pattern matching --
which is actually a feature, not a bug, because it forces you to handle the
new case.

---

## Internal Visitor

### Definition

In an **internal visitor**, the **visitor controls traversal**. The AST nodes
expose their children (via accessors or pattern matching), but the visitor
decides which children to visit, in what order, and whether to recurse at all.

There is no `accept` method on the nodes. Instead, the visitor has explicit
traversal logic.

### Structure

```
// The visitor drives everything
trait GherkinInternalVisitor {
  // Called for each node type -- the visitor decides what to do next
  visit_feature(Self, Feature) -> Unit
  visit_scenario(Self, Scenario) -> Unit
  visit_step(Self, Step) -> Unit
  // ...

  // Default traversal logic -- can be overridden
  walk_feature(Self, Feature) -> Unit
  walk_scenario(Self, Scenario) -> Unit
  // ...
}

// Default walk methods provide a traversal skeleton
fn walk_feature(self: &GherkinInternalVisitor, feature: Feature) -> Unit {
  self.visit_feature(feature)
  for child in feature.children {
    match child {
      Background(bg) => self.walk_background(bg)
      Scenario(sc) => self.walk_scenario(sc)
      Rule(rule) => self.walk_rule(rule)
    }
  }
}
```

The crucial difference: the visitor can **override `walk_*` methods** to
change traversal behavior.

### Visitor-Controlled Traversal Examples

**Skip scenarios without a specific tag:**

```
fn walk_feature(self: TagFilterVisitor, feature: Feature) -> Unit {
  self.visit_feature(feature)
  for child in feature.children {
    match child {
      Scenario(sc) => {
        if sc.tags.any(|t| t.name == self.required_tag) {
          self.walk_scenario(sc)     // Visit this one
        }
        // Otherwise: skip entirely -- no traversal into children
      }
      Rule(rule) => self.walk_rule(rule)
      Background(bg) => self.walk_background(bg)
    }
  }
}
```

**Visit steps in reverse order:**

```
fn walk_scenario(self: ReverseStepVisitor, scenario: Scenario) -> Unit {
  self.visit_scenario(scenario)
  // Reverse! External visitor can't do this.
  for step in scenario.steps.rev() {
    self.walk_step(step)
  }
}
```

**Early termination (find first match):**

```
fn walk_feature(self: FindFirstVisitor, feature: Feature) -> Unit {
  self.visit_feature(feature)
  for child in feature.children {
    if self.found { return }   // Stop as soon as we find it
    match child {
      Scenario(sc) => self.walk_scenario(sc)
      _ => ()
    }
  }
}
```

### Characteristics

| Property | Value |
|---|---|
| Traversal control | Visitor (`walk_*` methods) |
| Traversal order | Customizable per visitor |
| Can skip subtrees | Yes |
| Can change order | Yes |
| Early termination | Natural (just stop recursing) |
| Adding new operations | Easy (new visitor impl) |
| Adding new node types | Moderate (update `walk_*` defaults) |
| State management | Visitor fields + local variables in `walk_*` |
| Best analogy | "I'll walk where I want" |

### The Two-Method Pattern: visit + walk

A clean internal visitor separates **observation** from **traversal**:

- `visit_*(node)` -- Pure observation. Called when entering a node. Does not
  recurse. This is where the visitor performs its operation (count, collect,
  transform, etc.).

- `walk_*(node)` -- Traversal logic. Calls `visit_*` on the current node,
  then decides which children to recurse into and in what order.

Default `walk_*` implementations provide depth-first, document-order traversal.
Consumers override `visit_*` for behavior and `walk_*` only when they need
custom traversal.

```
// Consumer only overrides visit_* (uses default traversal)
struct StepCounter : GherkinInternalVisitor {
  mut count: Int
}

fn visit_step(self: StepCounter, _step: Step) -> Unit {
  self.count += 1
}
// walk_* methods inherited from defaults -- visits everything in document order
```

### When to Use for Gherkin

- **Filtered traversal**: Only visit scenarios matching a tag expression.
- **Conditional depth**: Visit Rules but not their children unless a condition
  is met.
- **Search operations**: Find the first scenario with a given name, then stop.
- **Transformation with context**: Visit steps differently depending on
  whether they're in a Background vs a Scenario.
- **Non-standard order**: Visit Examples before Steps, or process children in
  reverse.

---

## Controlled External Visitor (Hybrid)

A practical middle ground: the **data structure** still drives traversal via
`accept`, but the visitor's `visit_*` methods return a **directive** that tells
the traversal infrastructure what to do next.

### Traversal Directives

```
enum VisitDirective {
  Continue        // Continue normal traversal into children
  SkipChildren    // Visit this node but do not recurse into children
  Stop            // Halt all traversal immediately
}
```

### Structure

```
trait GherkinControlledVisitor {
  visit_feature(Self, Feature) -> VisitDirective
  visit_scenario(Self, Scenario) -> VisitDirective
  visit_step(Self, Step) -> VisitDirective
  // ...
}

fn accept(self: Feature, visitor: &GherkinControlledVisitor) -> VisitDirective {
  match visitor.visit_feature(self) {
    Stop => Stop
    SkipChildren => Continue   // Node was visited, skip children, continue siblings
    Continue => {
      for child in self.children {
        let directive = match child {
          Background(bg) => bg.accept(visitor)
          Scenario(sc) => sc.accept(visitor)
          Rule(rule) => rule.accept(visitor)
        }
        if directive == Stop { return Stop }
      }
      Continue
    }
  }
}
```

### Characteristics

This gives the visitor limited control over traversal while keeping traversal
logic in the data structure:

- **`Continue`**: Default behavior, same as classic external visitor.
- **`SkipChildren`**: Useful for filtering. "I've seen this scenario, I don't
  need its steps."
- **`Stop`**: Early termination. "Found what I needed."

This is the approach used by many real-world compilers and tools (e.g.,
Roslyn's `CSharpSyntaxWalker`, `tree-sitter`'s visitor API).

### When to Use for Gherkin

- When you want the **simplicity of external visitors** but need **occasional
  skip/stop control**.
- Linters that check Feature-level and Scenario-level rules but don't need to
  inspect every Step.
- Tag-based filtering where you skip scenarios that don't match.

---

## Cursor-Based Visitor (Zipper)

### Definition

A **cursor** (also known as a **zipper** in functional programming) is an
explicit representation of a **position** within a tree plus the **context**
needed to navigate and reconstruct the tree. Instead of recursion driving the
traversal, the consumer moves a cursor around the tree imperatively.

The cursor knows:
- The **current node** (focus)
- The **path to the root** (breadcrumbs / context)
- How to **move**: down to first child, up to parent, right to next sibling,
  left to previous sibling

### Origin: Huet's Zipper

Gerard Huet introduced the Zipper in 1997 as a technique for navigating and
"editing" immutable trees in functional languages. The key insight: instead of
modifying a node in place, you decompose the tree into a **focus** (the current
node) and a **context** (everything else), make your change to the focus, and
then **zip** back up to reconstruct a new tree with the modification -- sharing
all unchanged structure with the original.

### Structure

```
// The context: path from current node back to root
enum Breadcrumb {
  FeatureChild(
    parent: Feature,       // The parent node (without the focused child)
    left: Array[FeatureChild],   // Siblings to the left
    right: Array[FeatureChild],  // Siblings to the right
  )
  RuleChild(
    parent: Rule,
    left: Array[RuleChild],
    right: Array[RuleChild],
  )
  ScenarioStep(
    parent: Scenario,
    left: Array[Step],
    right: Array[Step],
  )
  // ... one variant per parent-child relationship
}

// The cursor: focus + context
struct GherkinCursor {
  focus: GherkinNode       // Current node
  breadcrumbs: Array[Breadcrumb]  // Path to root
}

// Navigation
fn down(self: GherkinCursor) -> GherkinCursor?    // To first child
fn up(self: GherkinCursor) -> GherkinCursor?      // To parent
fn right(self: GherkinCursor) -> GherkinCursor?    // To next sibling
fn left(self: GherkinCursor) -> GherkinCursor?     // To previous sibling

// Observation
fn current(self: GherkinCursor) -> GherkinNode     // What am I looking at?
fn depth(self: GherkinCursor) -> Int               // How deep am I?
fn path(self: GherkinCursor) -> Array[GherkinNode] // Ancestors from root

// Modification (returns new cursor with new tree)
fn replace(self: GherkinCursor, node: GherkinNode) -> GherkinCursor
fn insert_right(self: GherkinCursor, node: GherkinNode) -> GherkinCursor
fn insert_left(self: GherkinCursor, node: GherkinNode) -> GherkinCursor
fn remove(self: GherkinCursor) -> GherkinCursor

// Reconstruction
fn to_root(self: GherkinCursor) -> GherkinDocument  // Zip back up
```

### The GherkinNode Sum Type

For the cursor to work uniformly, we need a sum type representing any node:

```
enum GherkinNode {
  Document(GherkinDocument)
  Feature(Feature)
  Rule(Rule)
  Background(Background)
  Scenario(Scenario)
  Step(Step)
  DocString(DocString)
  DataTable(DataTable)
  Examples(Examples)
  TableRow(TableRow)
  TableCell(TableCell)
  Tag(Tag)
  Comment(Comment)
}
```

This is distinct from the typed DOM nodes -- it erases the specific type in
exchange for uniform navigation. The consumer can pattern-match to recover
type information at any point.

### Cursor Traversal Example

```
// Start at the document root
let cursor = GherkinCursor::from_document(document)

// Navigate to the Feature
let cursor = cursor.down()!       // -> Feature

// Navigate to the first child (Background or Scenario)
let cursor = cursor.down()!       // -> first FeatureChild

// Walk siblings
let mut cursor = cursor
while true {
  match cursor.current() {
    Scenario(sc) => {
      if sc.tags.any(|t| t.name == "@smoke") {
        process_scenario(sc)
      }
    }
    _ => ()
  }
  match cursor.right() {
    Some(next) => cursor = next
    None => break
  }
}

// Go back up to Feature
let cursor = cursor.up()!
```

### Cursor-Based Modification (Immutable)

The power of the zipper for an immutable DOM:

```
// Find a step and replace its text
let cursor = GherkinCursor::from_document(document)
let cursor = navigate_to_step(cursor, "old step text")

// Replace the step -- returns a new cursor with a new tree
let new_step = Step { text: "new step text", ..cursor.current_step() }
let cursor = cursor.replace(GherkinNode::Step(new_step))

// Zip back to root to get the complete modified document
let new_document = cursor.to_root()
// The original document is unchanged
```

This is **structural sharing**: only the path from the modified node to the
root is reallocated. All other nodes are shared with the original tree.

```
Original:                    Modified (shared structure):

    Document                     Document'
    └── Feature                  └── Feature'
        ├── Background ────────────── Background  (shared)
        ├── Scenario1 ─────────────── Scenario1   (shared)
        └── Scenario2                └── Scenario2'
            ├── Step1 ─────────────────── Step1   (shared)
            ├── Step2  (old)             ├── Step2' (new)
            └── Step3 ─────────────────── Step3   (shared)
```

### Characteristics

| Property | Value |
|---|---|
| Traversal control | Consumer (explicit move calls) |
| Traversal order | Arbitrary (any direction, any time) |
| Can skip subtrees | Yes (just don't call `down()`) |
| Can backtrack | Yes (`left()`, `up()`) |
| Can modify | Yes (immutably, with structural sharing) |
| Position awareness | Full (knows parent, siblings, depth, path) |
| Early termination | Natural (stop moving) |
| State management | Cursor itself is the state |
| Adding new operations | Easy (functions that take a cursor) |
| Memory overhead | Breadcrumb stack (proportional to depth) |
| Best analogy | A cursor in a text editor |

### When to Use for Gherkin

- **Editor / IDE integration**: "What Gherkin node is at line 42, column 10?"
  Navigate the cursor to the right position by location.

- **Refactoring**: Replace a step, add a tag, insert a scenario -- all while
  preserving the rest of the tree (immutable modification with structural
  sharing).

- **Incremental analysis**: Navigate to the changed region, re-analyze only
  that subtree, zip back up.

- **Context-aware operations**: "What Rule does this Scenario belong to?"
  The breadcrumbs tell you the full ancestor chain.

- **Non-recursive traversal**: Useful when the tree is too deep for the call
  stack or when you need to serialize the traversal position (e.g., save and
  resume later).

- **Undo/redo**: Each cursor state is an immutable snapshot. Keep a history
  of cursor states for undo.

---

## Comparison: All Three Variants

| Aspect | External | Internal | Cursor |
|---|---|---|---|
| **Traversal control** | Structure | Visitor | Consumer (imperative) |
| **Direction** | Forward only (depth-first) | Any (visitor decides) | Any (up/down/left/right) |
| **Skip subtrees** | No (or hybrid: directives) | Yes | Yes |
| **Early termination** | Difficult | Easy | Easy |
| **Backtracking** | No | Possible (manual) | Native |
| **Position awareness** | Implicit (call stack) | Implicit (call stack) | Explicit (breadcrumbs) |
| **Modification** | Read-only (typically) | Read-only (typically) | Native (immutable edit) |
| **Composability** | Chain visitors | Override walk methods | Functions over cursors |
| **Complexity** | Low | Medium | Higher |
| **Best for** | Simple uniform ops | Filtered/conditional ops | Navigation + editing |

---

## Combining Variants

The three visitor variants are not mutually exclusive. A well-designed Gherkin
parser provides all three and lets consumers choose.

### External + Cursor: Visitor with Location

An external visitor can carry a cursor as context, giving each `visit_*`
method access to parent/sibling information:

```
trait GherkinContextualVisitor {
  visit_feature(Self, Feature, GherkinCursor) -> Unit
  visit_scenario(Self, Scenario, GherkinCursor) -> Unit
  visit_step(Self, Step, GherkinCursor) -> Unit
  // ...
}

fn accept(self: Feature, visitor: &GherkinContextualVisitor, cursor: GherkinCursor) -> Unit {
  visitor.visit_feature(self, cursor)
  for (i, child) in self.children.iter().enumerate() {
    let child_cursor = cursor.move_to_child(i)
    match child {
      Scenario(sc) => sc.accept(visitor, child_cursor)
      // ...
    }
  }
}
```

**Use case**: A linter that checks "Scenario should not have more than 10
steps" needs the Scenario context while visiting Steps. The cursor provides
this without the visitor needing to track it manually.

### Internal Visitor Backed by Cursor

An internal visitor can use a cursor internally for navigation, exposing a
simpler `visit_*` interface to consumers:

```
fn walk(self: &GherkinInternalVisitor, document: GherkinDocument) -> Unit {
  let mut cursor = GherkinCursor::from_document(document)
  self.walk_cursor(&mut cursor)
}

fn walk_cursor(self: &GherkinInternalVisitor, cursor: &mut GherkinCursor) -> Unit {
  match cursor.current() {
    Feature(f) => self.visit_feature(f)
    Scenario(s) => self.visit_scenario(s)
    Step(s) => self.visit_step(s)
    // ...
  }
  // Depth-first: go down, then right, then up-and-right
  if cursor.down().is_some() {
    self.walk_cursor(cursor)
    while cursor.right().is_some() {
      self.walk_cursor(cursor)
    }
    cursor.up()
  }
}
```

**Use case**: The consumer gets the simplicity of an internal visitor (just
override `visit_*`) while the traversal infrastructure uses a cursor for
flexible, non-recursive tree walking.

### Cursor as Iterator (Pull Visitor)

A cursor can be adapted into an iterator that yields nodes, bridging the
cursor world with the pull-based world:

```
struct CursorIterator {
  cursor: GherkinCursor
  done: Bool
}

fn next(self: CursorIterator) -> GherkinNode? {
  if self.done { return None }

  let node = self.cursor.current()

  // Advance: depth-first traversal
  if self.cursor.down().is_none() {
    // No children -- try right sibling
    while self.cursor.right().is_none() {
      // No right sibling -- go up
      if self.cursor.up().is_none() {
        self.done = true
        return Some(node)
      }
    }
  }

  Some(node)
}
```

**Use case**: Pull-based consumers that want cursor-level flexibility but
prefer the iterator/loop ergonomics.

---

## Gherkin-Specific Design Recommendations

### 1. Default to External Visitor

For most consumers, the external visitor is sufficient and simplest. Make this
the primary API:

```
let document = parse(input)
document.accept(my_visitor)
```

### 2. Offer Controlled External Visitor

For consumers that need skip/stop, provide the directive-based variant:

```
let document = parse(input)
document.accept_controlled(my_controlled_visitor)
```

### 3. Provide Internal Visitor with visit/walk Separation

For power users who need full traversal control:

```
struct MyVisitor : GherkinInternalVisitor { ... }
fn visit_scenario(self: MyVisitor, sc: Scenario) -> Unit { ... }
fn walk_feature(self: MyVisitor, f: Feature) -> Unit { ... }  // custom traversal
MyVisitor.walk(document)
```

### 4. Expose Cursor for Navigation and Editing

For editor integration and refactoring tools:

```
let cursor = GherkinCursor::from_document(document)
let cursor = cursor.navigate_to_line(42)
match cursor.current() {
  Step(s) => // Handle step at line 42
  _ => // ...
}
```

### 5. Type Safety Across Variants

All variants should work with the same ADT-based AST. The cursor's
`GherkinNode` sum type is the only place where type erasure occurs, and
pattern matching immediately recovers it. No stringly-typed APIs, no
`Any`/`Object` casts.

---

## Summary: When to Use Each

| Use Case | Visitor Variant |
|---|---|
| Count nodes, collect tags, serialize | External |
| Pretty-print in document order | External |
| Lint with occasional skip | Controlled External (directives) |
| Filter scenarios by tag expression | Internal |
| Search for first matching node | Internal (early termination) |
| Visit children in custom order | Internal |
| Context-aware analysis (needs parent info) | External + Cursor context |
| Editor: "what's at this position?" | Cursor |
| Refactoring: modify and re-serialize | Cursor (immutable edit) |
| Undo/redo for editor operations | Cursor (snapshot history) |
| Non-recursive traversal | Cursor as iterator |
| Incremental re-analysis | Cursor (navigate to changed region) |

## References

- *Design Patterns* (Gamma et al.) -- Visitor, Iterator
- Gerard Huet, "The Zipper" (1997) -- https://www.st.cs.uni-saarland.de/edu/seminare/2005/advanced-fp/docs/huet-zipper.pdf
- Conor McBride, "The Derivative of a Regular Type is its Type of One-Hole Contexts" -- foundation for zipper generalization
- Roslyn CSharpSyntaxWalker -- controlled external visitor in practice
- tree-sitter TreeCursor -- cursor-based traversal for editor integration
- [parser-visitor-integration.md](parser-visitor-integration.md)
- [dom-based-representation.md](dom-based-representation.md)
