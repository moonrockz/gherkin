# Testing Strategy: Unit Tests, BDD Tests, and Acceptance Tests

## Overview

This project employs a layered testing strategy where different kinds of tests
serve fundamentally different purposes. Understanding the distinction is
critical -- these are not interchangeable, and each has a specific role in
verifying that the Gherkin parser is correct, complete, and useful.

```
                    ┌─────────────────────────────┐
                    │    Acceptance Tests (BDD)    │  Does the feature work
                    │    .feature files + Behave   │  as the user expects?
                    ├─────────────────────────────┤
                    │      Integration Tests       │  Do the pieces work
                    │   (moon test, cross-module)  │  together?
                    ├─────────────────────────────┤
                    │        Unit Tests            │  Does each piece work
                    │  (_test.mbt, moon test)      │  in isolation?
                    └─────────────────────────────┘
                              Test Pyramid
```

## Unit Tests

### What They Are

Unit tests verify **individual functions, types, and modules in isolation**.
They test the smallest meaningful units of behavior: a single function, a
single method, a single pattern match branch.

### Purpose

- **Verify correctness** of internal logic at the lowest level.
- **Document behavior** of individual functions through examples.
- **Enable safe refactoring** by catching regressions immediately.
- **Drive API design** when written first (TDD): writing calling code before
  implementation reveals awkward APIs early.

### What They Look Like

In this project, unit tests are MoonBit `_test.mbt` files run via `moon test`:

```moonbit
///|
test "TagName rejects empty string" {
  inspect(TagName::new(""), content="Err(Empty)")
}

///|
test "TagName strips @ prefix" {
  inspect(TagName::new("@smoke").unwrap().to_string(), content="@smoke")
}

///|
test "TagName validates characters" {
  inspect(TagName::new("@valid-tag_1.0").is_ok(), content="true")
  inspect(TagName::new("@invalid tag").is_ok(), content="false")
}

///|
test "Location comparison" {
  let a = Location::new(line=1, column=5)
  let b = Location::new(line=2, column=1)
  inspect(a < b, content="true")
}
```

### Characteristics

| Property | Unit Tests |
|---|---|
| **Scope** | Single function, method, or type |
| **Speed** | Milliseconds per test |
| **Dependencies** | None (isolated, no I/O, no external processes) |
| **Written in** | MoonBit (`_test.mbt` and `_wbtest.mbt` files) |
| **Run with** | `moon test` |
| **Failure tells you** | Exactly which function broke and how |
| **Written by** | Developers, as part of TDD cycle |

### What Unit Tests Are NOT

- They do not prove that features work end-to-end.
- They do not validate user-facing behavior.
- They do not replace acceptance tests.
- Passing unit tests does not mean the feature is done.

---

## BDD Tests (Behavior-Driven Development)

### What They Are

BDD tests describe **system behavior in business/domain language**. They are
written in Gherkin (`.feature` files) and express what the system should do
from the perspective of someone who uses it, without describing how it works
internally.

### Purpose

- **Specify behavior** before it's implemented (executable specifications).
- **Communicate intent** between developers, testers, and stakeholders using
  a shared language.
- **Verify observable outcomes** -- what comes out of the system, not what
  happens inside it.
- **Document the system** in a form that remains readable to non-developers.

### What They Look Like

In this project, BDD tests are Behave `.feature` files in `tests/features/`:

```gherkin
Feature: Gherkin Parser
  As a developer using the MoonBit Gherkin parser,
  I want the parser to correctly handle all Gherkin constructs,
  so that I can build reliable BDD tooling.

  Scenario: Parse a minimal feature file
    Given a Gherkin file "minimal.feature"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the output should contain a "Feature" node

  Scenario: Parse tags
    Given a Gherkin file "tags.feature"
    When I parse the file
    Then the parser should succeed
    And the output should contain keyword "@smoke"
```

Each scenario follows the **Given-When-Then** pattern:

- **Given** (arrange): Set up the initial context.
- **When** (act): Perform the action under test.
- **Then** (assert): Verify the observable outcome.

### Characteristics

| Property | BDD Tests |
|---|---|
| **Scope** | Complete user-facing behavior / feature |
| **Speed** | Slower (may invoke external processes, I/O) |
| **Dependencies** | Step definitions, test fixtures, parser binary |
| **Written in** | Gherkin (`.feature` files) + Python step definitions |
| **Run with** | `behave` (via `uv run behave`) |
| **Failure tells you** | Which behavior is broken, in domain terms |
| **Written by** | Anyone who understands the domain |

### BDD vs Unit Tests: A Key Distinction

BDD tests and unit tests answer **different questions** and should not be
confused or substituted for each other:

| | Unit Tests | BDD Tests |
|---|---|---|
| **Question** | Does this function compute the right result? | Does the system behave correctly from the outside? |
| **Audience** | Developers | Developers, testers, stakeholders |
| **Language** | Code (MoonBit) | Domain language (Gherkin) |
| **Granularity** | One function, one edge case | One behavior, one scenario |
| **Internals** | Tests internal implementation | Tests external behavior only |
| **Change frequency** | Change with refactoring | Change only when behavior changes |
| **Example** | "TokenScanner returns a FeatureLine token for 'Feature: X'" | "When I parse a file with a Feature, the output contains a Feature node" |

A refactoring that changes internal function names should break unit tests
(they test those functions) but should **never** break BDD tests (behavior
hasn't changed). This is how you know your refactoring is safe.

### What BDD Tests Are NOT

- They are not unit tests. They don't test individual functions.
- They don't test internal implementation details.
- They shouldn't be used to test every edge case -- that's what unit tests
  are for.
- They don't replace the need for unit-level TDD.

---

## Acceptance Tests

### What They Are

Acceptance tests are the subset of BDD tests that define the **criteria for a
feature to be considered complete**. They answer the question: "Does this
feature meet its specification?" They are the contract between what was
requested and what was delivered.

### Purpose

- **Gate completion**: A feature is not done until its acceptance tests pass.
- **Prevent regression**: If a previously-passing acceptance test fails, a
  feature that was working has been broken.
- **Define scope**: The acceptance tests for a feature define exactly what
  "done" means. No more, no less.

### Relationship to BDD Tests

All acceptance tests in this project are BDD tests (written in Gherkin). But
not all BDD tests are necessarily acceptance tests -- some may be exploratory
or cover additional edge cases beyond the core acceptance criteria:

```
┌─────────────────────────────────────┐
│           BDD Tests                 │
│  ┌───────────────────────────────┐  │
│  │     Acceptance Tests          │  │
│  │  (feature completion gates)   │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │  Exploratory / Edge-case BDD  │  │
│  │  (additional coverage)        │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### How Acceptance Tests Are Organized

Each parser feature has corresponding scenarios that serve as its acceptance
criteria:

| Parser Feature | Acceptance Test File | Key Scenarios |
|---|---|---|
| Basic parsing | `parsing.feature` | Minimal file, inline text |
| Background | `parsing.feature` | Parse Background node |
| Scenario Outline | `parsing.feature` | Parse ScenarioOutline node |
| Tags | `parsing.feature` | Parse tags, verify `@smoke` |
| Data Tables | `parsing.feature` | Parse DataTable node |
| Doc Strings | `parsing.feature` | Parse DocString node |
| Comments | `parsing.feature` | Parse Comment node |
| Rules | `parsing.feature` | Parse Rule node |
| Error handling | `error_handling.feature` | Malformed input, missing Feature |

---

## The Three Layers Working Together

### Acceptance Test Workflow (Outside-In TDD)

The layers are used in an **outside-in** order: start from the acceptance test
(outermost) and work inward to unit tests:

```
1. Write the acceptance test (.feature) -- defines "done"
       │
       v
2. Run it -- FAILS (feature not implemented yet)
       │
       v
3. TDD the internal components with unit tests (_test.mbt)
   ┌──────────────────────────────────────┐
   │  a. Write failing unit test (Red)    │
   │  b. Implement minimum code (Green)   │◄── repeat
   │  c. Refactor (Refactor)              │
   └──────────────────────────────────────┘
       │
       v
4. Wire up the components
       │
       v
5. Run acceptance test again -- PASSES
       │
       v
6. Feature is DONE (both layers green)
```

### Example: Adding Tag Inheritance Support

**Step 1: Write the acceptance test** (defines "done")

```gherkin
# tests/features/tag_inheritance.feature
Feature: Tag Inheritance
  As a developer,
  I want Feature-level tags to be inherited by Scenarios,
  so that I can apply tags to all scenarios in a feature.

  Scenario: Feature tags are inherited by scenarios
    Given a Gherkin input
      """
      @feature-tag
      Feature: Tagged feature

        Scenario: Inner scenario
          Given something
      """
    When I parse the file
    Then the parser should succeed
    And the scenario "Inner scenario" should have effective tag "@feature-tag"

  Scenario: Rule tags combine with Feature tags
    Given a Gherkin input
      """
      @feature-tag
      Feature: Tagged feature

        @rule-tag
        Rule: Business rule

          Scenario: Rule scenario
            Given something
      """
    When I parse the file
    Then the parser should succeed
    And the scenario "Rule scenario" should have effective tags "@feature-tag" and "@rule-tag"
```

Run `uv run behave` -- both scenarios fail. Good. We know what "done" looks
like.

**Step 2: TDD the internal components with unit tests**

```moonbit
///|
test "EffectiveTags combines declared and inherited" {
  let declared = TagSet::from_names(["@fast"])
  let inherited = TagSet::from_names(["@smoke"])
  let effective = EffectiveTags::new(declared~, inherited~)
  inspect(effective.all().contains(TagName::new("@smoke")!), content="true")
  inspect(effective.all().contains(TagName::new("@fast")!), content="true")
  inspect(effective.is_inherited(TagName::new("@smoke")!), content="true")
  inspect(effective.is_declared(TagName::new("@fast")!), content="true")
}

///|
test "TagSet union merges two sets" {
  let a = TagSet::from_names(["@a", "@b"])
  let b = TagSet::from_names(["@b", "@c"])
  let merged = a.union(b)
  inspect(merged.len(), content="3")
}
```

Run `moon test` -- fails (types don't exist yet). Implement `TagSet`,
`EffectiveTags`, etc. Tests go green.

Continue TDD-ing the parser's tag inheritance logic with unit tests until all
internal components work.

**Step 3: Run acceptance tests again**

```
uv run behave tests/features/tag_inheritance.feature
```

Both scenarios pass. Feature is done.

---

## Using `#declaration_only` in the TDD Cycle

MoonBit's `#declaration_only` attribute bridges the gap between the Red and
Green phases by letting you define types and signatures before implementation:

```moonbit
// Step 1: Declare the types and API (spec-first)
#declaration_only
pub(all) struct TagSet {
  tags: Array[Tag]
}

#declaration_only
pub fn TagSet::from_names(names : Array[String]) -> TagSet {
  ...
}

#declaration_only
pub fn TagSet::contains(self : TagSet, name : TagName) -> Bool {
  ...
}

#declaration_only
pub fn TagSet::union(self : TagSet, other : TagSet) -> TagSet {
  ...
}
```

```moonbit
// Step 2: Write tests against the declarations
///|
test "TagSet contains a tag" {
  let set = TagSet::from_names(["@smoke"])
  inspect(set.contains(TagName::new("@smoke")!), content="true")
  inspect(set.contains(TagName::new("@other")!), content="false")
}
```

```moonbit
// Step 3: Replace #declaration_only with real implementation, one at a time
pub fn TagSet::from_names(names : Array[String]) -> TagSet {
  // Real implementation here
}
```

This workflow means tests are compilable and expressible before any logic
exists. Each `#declaration_only` is a to-do item -- a function-shaped hole
waiting to be filled.

---

## Summary: What Each Layer Does

| Layer | Question Answered | Speed | Scope | Tool |
|---|---|---|---|---|
| **Unit tests** | Does this function work correctly? | Fast (ms) | Single function/type | `moon test` |
| **BDD tests** | Does this behavior work as described? | Moderate | Feature / scenario | `uv run behave` |
| **Acceptance tests** | Is this feature complete? | Moderate | End-to-end feature | `uv run behave` |

### Rules of Thumb

- **Every function** should have unit tests.
- **Every feature** should have acceptance tests.
- **Unit tests** catch *how* things break.
- **Acceptance tests** catch *what* is broken (in domain terms).
- A passing unit test suite with failing acceptance tests means: the pieces
  work but they're not wired together correctly.
- A passing acceptance test suite with failing unit tests means: something is
  coincidentally working but internally broken. Fix the unit tests.
- **Both must be green** before a feature is considered done.

## References

- Kent Beck, *Test-Driven Development: By Example*
- Dan North, "Introducing BDD": https://dannorth.net/introducing-bdd/
- MoonBit testing docs: https://docs.moonbitlang.com
- MoonBit `#declaration_only`: https://www.moonbitlang.com/updates/2026/01/12/index#language-updates
- Behave documentation: https://behave.readthedocs.io/
- [Gherkin Reference](../specs/gherkin-reference.md)
