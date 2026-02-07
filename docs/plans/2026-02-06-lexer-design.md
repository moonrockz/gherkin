# Gherkin Lexer/Tokenizer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a line-oriented lexer that classifies Gherkin source lines into typed tokens, providing both eager (Array) and lazy (Iter) consumption modes.

**Architecture:** A layered design with a pure `classify_line` function at the core, plus a `LexerState` for tracking doc-string context. `tokenize()` eagerly collects all tokens; `Lexer` struct provides `Iter[Token]` for incremental consumption. Both share the same classification logic.

**Tech Stack:** MoonBit, `moon test` with `inspect` snapshots, `moon coverage analyze` for coverage.

---

### Task 1: Define Token type and LexerState

**Files:**
- Create: `src/token.mbt`

**Step 1: Write failing test for Token type**

Create `src/token_wbtest.mbt` with a smoke test that constructs a Token variant and inspects it. This forces us to define the type.

```moonbit
///|
test "Token::FeatureLine construction" {
  let tok = Token::FeatureLine(
    location={ line: 1, column: Some(1) },
    keyword="Feature",
    name="Login",
  )
  inspect(tok, content="FeatureLine({line: 1, column: Some(1)}, \"Feature\", \"Login\")")
}
```

**Step 2: Run test to verify it fails**

Run: `moon test -f token_wbtest.mbt 2>&1`
Expected: FAIL — `Token` type not defined

**Step 3: Write Token enum and LexerState**

Create `src/token.mbt`:

```moonbit
///|
/// A token produced by the lexer, representing a classified source line.
/// Each variant carries its Location and the relevant parsed fragments.
pub enum Token {
  FeatureLine(Location, String, String)       // location, keyword, name
  RuleLine(Location, String, String)          // location, keyword, name
  BackgroundLine(Location, String, String)    // location, keyword, name
  ScenarioLine(Location, String, String)      // location, keyword, name
  ExamplesLine(Location, String, String)      // location, keyword, name
  StepLine(Location, String, KeywordType, String) // location, keyword, keyword_type, text
  DocStringSeparator(Location, String, String?) // location, delimiter, media_type
  TableRow(Location, Array[String])           // location, cells
  TagLine(Location, Array[String])            // location, tags (each includes @)
  Comment(Location, String)                   // location, text
  Language(Location, String)                  // location, language code
  Empty(Location)                             // blank/whitespace-only line
  Other(Location, String)                     // description text or unrecognized
  Eof(Location)                               // end of input
} derive(Show, Eq)

///|
/// Internal state tracked between lines during tokenization.
/// Gherkin is mostly stateless line-by-line except inside doc strings.
pub(all) enum LexerState {
  Normal
  InDocString(String)  // the opening delimiter (""" or ```)
} derive(Show, Eq)
```

**Step 4: Run test to verify it passes**

Run: `moon test -f token_wbtest.mbt 2>&1`
Expected: PASS

**Step 5: Run full suite + format + update snapshots**

Run: `moon test --update && moon fmt && moon info`

**Step 6: Commit**

```bash
git add src/token.mbt src/token_wbtest.mbt
git commit -m "feat(lexer): define Token enum and LexerState types"
```

---

### Task 2: Implement classify_line for empty lines

**Files:**
- Modify: `src/token.mbt`
- Modify: `src/token_wbtest.mbt`

**Step 1: Write failing test**

```moonbit
///|
test "classify_line: empty line" {
  let (tok, state) = classify_line("", 1, Normal)
  inspect(tok, content="Empty({line: 1, column: None})")
  inspect(state, content="Normal")
}

///|
test "classify_line: whitespace-only line" {
  let (tok, _) = classify_line("   ", 2, Normal)
  inspect(tok, content="Empty({line: 2, column: None})")
}
```

**Step 2: Run test to verify it fails**

Run: `moon test -f token_wbtest.mbt 2>&1`
Expected: FAIL — `classify_line` not defined

**Step 3: Write minimal classify_line**

Add to `src/token.mbt`:

```moonbit
///|
/// Classify a single source line into a Token.
/// This is the core pure function of the lexer.
/// Returns the token and the next lexer state.
pub fn classify_line(
  line : String,
  line_num : Int,
  state : LexerState
) -> (Token, LexerState) {
  let trimmed = line.trim_start()
  if trimmed.is_empty() {
    (Empty({ line: line_num, column: None }), state)
  } else {
    (Other({ line: line_num, column: None }, line), state)
  }
}
```

**Step 4: Run test, update snapshots**

Run: `moon test --update && moon fmt`

**Step 5: Commit**

```bash
git add src/token.mbt src/token_wbtest.mbt
git commit -m "feat(lexer): classify_line handles empty lines"
```

---

### Task 3: Classify comment lines and language directives

**Files:**
- Modify: `src/token.mbt`
- Modify: `src/token_wbtest.mbt`

**Step 1: Write failing tests**

```moonbit
///|
test "classify_line: comment" {
  let (tok, _) = classify_line("# This is a comment", 1, Normal)
  inspect(tok, content="Comment({line: 1, column: Some(1)}, \"# This is a comment\")")
}

///|
test "classify_line: indented comment" {
  let (tok, _) = classify_line("  # indented", 5, Normal)
  inspect(tok, content="Comment({line: 5, column: Some(3)}, \"# indented\")")
}

///|
test "classify_line: language directive" {
  let (tok, _) = classify_line("# language: fr", 1, Normal)
  inspect(tok, content="Language({line: 1, column: Some(1)}, \"fr\")")
}
```

**Step 2: Implement comment/language classification**

In `classify_line`, after the empty check, check if trimmed starts with `#`. If the content after `#` matches `language:`, parse the language code. Otherwise, it's a comment.

The column is calculated as: `line.length() - trimmed.length() + 1` (1-based).

**Step 3: Run tests, update snapshots**

Run: `moon test --update && moon fmt`

**Step 4: Commit**

```bash
git add src/token.mbt src/token_wbtest.mbt
git commit -m "feat(lexer): classify comments and language directives"
```

---

### Task 4: Classify tag lines

**Files:**
- Modify: `src/token.mbt`
- Modify: `src/token_wbtest.mbt`

**Step 1: Write failing tests**

```moonbit
///|
test "classify_line: single tag" {
  let (tok, _) = classify_line("@smoke", 1, Normal)
  inspect(tok, content="TagLine({line: 1, column: Some(1)}, [\"@smoke\"])")
}

///|
test "classify_line: multiple tags" {
  let (tok, _) = classify_line("@smoke @regression", 1, Normal)
  inspect(tok, content="TagLine({line: 1, column: Some(1)}, [\"@smoke\", \"@regression\"])")
}

///|
test "classify_line: indented tags" {
  let (tok, _) = classify_line("  @wip", 4, Normal)
  inspect(tok, content="TagLine({line: 4, column: Some(3)}, [\"@wip\"])")
}
```

**Step 2: Implement tag parsing**

Check if trimmed starts with `@`. Split on whitespace, collecting words that start with `@`.

**Step 3: Run tests, commit**

```bash
git add src/token.mbt src/token_wbtest.mbt
git commit -m "feat(lexer): classify tag lines"
```

---

### Task 5: Classify table rows

**Files:**
- Modify: `src/token.mbt`
- Modify: `src/token_wbtest.mbt`

**Step 1: Write failing tests**

```moonbit
///|
test "classify_line: table row" {
  let (tok, _) = classify_line("      | name  | email |", 5, Normal)
  inspect(tok, content="TableRow({line: 5, column: Some(7)}, [\"name\", \"email\"])")
}

///|
test "classify_line: table row with spaces in cells" {
  let (tok, _) = classify_line("| Alice | alice@test.com |", 1, Normal)
  inspect(tok, content="TableRow({line: 1, column: Some(1)}, [\"Alice\", \"alice@test.com\"])")
}
```

**Step 2: Implement table row parsing**

Check if trimmed starts with `|`. Split by `|`, trim each cell, ignore empty first/last segments.

**Step 3: Run tests, commit**

```bash
git add src/token.mbt src/token_wbtest.mbt
git commit -m "feat(lexer): classify table rows"
```

---

### Task 6: Classify doc string separators and content

**Files:**
- Modify: `src/token.mbt`
- Modify: `src/token_wbtest.mbt`

**Step 1: Write failing tests**

```moonbit
///|
test "classify_line: doc string open triple-quote" {
  let (tok, state) = classify_line("      \"\"\"", 5, Normal)
  inspect(tok, content="DocStringSeparator({line: 5, column: Some(7)}, \"\\\"\\\"\\\"\", None)")
  inspect(state, content="InDocString(\"\\\"\\\"\\\"\")")
}

///|
test "classify_line: doc string with media type" {
  let (tok, state) = classify_line("  \"\"\"json", 3, Normal)
  inspect(tok, content="DocStringSeparator({line: 3, column: Some(3)}, \"\\\"\\\"\\\"\", Some(\"json\"))")
  inspect(state, content="InDocString(\"\\\"\\\"\\\"\")")
}

///|
test "classify_line: content inside doc string" {
  let (tok, state) = classify_line("  This is content", 6, InDocString("\"\"\""))
  inspect(tok, content="Other({line: 6, column: None}, \"  This is content\")")
  inspect(state, content="InDocString(\"\\\"\\\"\\\"\")")
}

///|
test "classify_line: doc string close" {
  let (tok, state) = classify_line("      \"\"\"", 8, InDocString("\"\"\""))
  inspect(tok, content="DocStringSeparator({line: 8, column: Some(7)}, \"\\\"\\\"\\\"\", None)")
  inspect(state, content="Normal")
}

///|
test "classify_line: backtick doc string" {
  let (tok, state) = classify_line("  ```", 3, Normal)
  inspect(state, content="InDocString(\"```\")")
}
```

**Step 2: Implement doc string handling**

Key insight: when `state` is `InDocString(delimiter)`, check if the trimmed line matches the delimiter. If so, produce `DocStringSeparator` and return to `Normal`. Otherwise, produce `Other` (content line) and stay in `InDocString`.

When in `Normal` state, check if trimmed starts with `"""` or `` ``` ``.

**Step 3: Run tests, commit**

```bash
git add src/token.mbt src/token_wbtest.mbt
git commit -m "feat(lexer): classify doc string separators and content"
```

---

### Task 7: Classify keyword lines (Feature, Scenario, etc.)

**Files:**
- Modify: `src/token.mbt`
- Modify: `src/token_wbtest.mbt`

**Step 1: Write failing tests**

```moonbit
///|
test "classify_line: Feature keyword" {
  let (tok, _) = classify_line("Feature: Login", 1, Normal)
  inspect(tok, content="FeatureLine({line: 1, column: Some(1)}, \"Feature\", \"Login\")")
}

///|
test "classify_line: Scenario keyword" {
  let (tok, _) = classify_line("  Scenario: First scenario", 4, Normal)
  inspect(tok, content="ScenarioLine({line: 4, column: Some(3)}, \"Scenario\", \"First scenario\")")
}

///|
test "classify_line: Scenario Outline keyword" {
  let (tok, _) = classify_line("  Scenario Outline: Eating cucumbers", 3, Normal)
  inspect(tok, content="ScenarioLine({line: 3, column: Some(3)}, \"Scenario Outline\", \"Eating cucumbers\")")
}

///|
test "classify_line: Background keyword" {
  let (tok, _) = classify_line("  Background:", 3, Normal)
  inspect(tok, content="BackgroundLine({line: 3, column: Some(3)}, \"Background\", \"\")")
}

///|
test "classify_line: Rule keyword" {
  let (tok, _) = classify_line("  Rule: Business rule one", 3, Normal)
  inspect(tok, content="RuleLine({line: 3, column: Some(3)}, \"Rule\", \"Business rule one\")")
}

///|
test "classify_line: Examples keyword" {
  let (tok, _) = classify_line("    Examples:", 8, Normal)
  inspect(tok, content="ExamplesLine({line: 8, column: Some(5)}, \"Examples\", \"\")")
}

///|
test "classify_line: Example as synonym for Scenario" {
  let (tok, _) = classify_line("  Example: A test", 4, Normal)
  inspect(tok, content="ScenarioLine({line: 4, column: Some(3)}, \"Example\", \"A test\")")
}

///|
test "classify_line: Scenario Template as synonym" {
  let (tok, _) = classify_line("  Scenario Template: Parameterized", 3, Normal)
  inspect(tok, content="ScenarioLine({line: 3, column: Some(3)}, \"Scenario Template\", \"Parameterized\")")
}

///|
test "classify_line: Scenarios as synonym for Examples" {
  let (tok, _) = classify_line("    Scenarios:", 8, Normal)
  inspect(tok, content="ExamplesLine({line: 8, column: Some(5)}, \"Scenarios\", \"\")")
}
```

**Step 2: Implement keyword matching**

After comment/tag/table/docstring checks, try matching keyword patterns. The keywords to check (in order to avoid ambiguity):
1. `Scenario Outline:` and `Scenario Template:` (multi-word, check before `Scenario:`)
2. `Feature:`, `Rule:`, `Background:`, `Scenario:`, `Example:`, `Examples:`, `Scenarios:`

For each, check if trimmed starts with `keyword + ":"`, extract the name as trimmed text after the colon.

**Step 3: Run tests, commit**

```bash
git add src/token.mbt src/token_wbtest.mbt
git commit -m "feat(lexer): classify keyword lines"
```

---

### Task 8: Classify step lines

**Files:**
- Modify: `src/token.mbt`
- Modify: `src/token_wbtest.mbt`

**Step 1: Write failing tests**

```moonbit
///|
test "classify_line: Given step" {
  let (tok, _) = classify_line("    Given a precondition", 5, Normal)
  inspect(tok, content="StepLine({line: 5, column: Some(5)}, \"Given \", Context, \"a precondition\")")
}

///|
test "classify_line: When step" {
  let (tok, _) = classify_line("    When an action is performed", 6, Normal)
  inspect(tok, content="StepLine({line: 6, column: Some(5)}, \"When \", Action, \"an action is performed\")")
}

///|
test "classify_line: Then step" {
  let (tok, _) = classify_line("    Then an outcome is observed", 7, Normal)
  inspect(tok, content="StepLine({line: 7, column: Some(5)}, \"Then \", Outcome, \"an outcome is observed\")")
}

///|
test "classify_line: And step" {
  let (tok, _) = classify_line("    And another step", 6, Normal)
  inspect(tok, content="StepLine({line: 6, column: Some(5)}, \"And \", Conjunction, \"another step\")")
}

///|
test "classify_line: But step" {
  let (tok, _) = classify_line("    But not this", 7, Normal)
  inspect(tok, content="StepLine({line: 7, column: Some(5)}, \"But \", Conjunction, \"not this\")")
}

///|
test "classify_line: star step" {
  let (tok, _) = classify_line("  * I have eggs", 5, Normal)
  inspect(tok, content="StepLine({line: 5, column: Some(3)}, \"* \", Unknown, \"I have eggs\")")
}
```

**Step 2: Implement step keyword matching**

Check if trimmed starts with `Given `, `When `, `Then `, `And `, `But `, or `* `. Note the trailing space — step keywords include the space as part of the keyword (matching the AST's `Step.keyword` field).

Map each to the corresponding `KeywordType`: Given→Context, When→Action, Then→Outcome, And/But→Conjunction, *→Unknown.

**Step 3: Run tests, commit**

```bash
git add src/token.mbt src/token_wbtest.mbt
git commit -m "feat(lexer): classify step lines"
```

---

### Task 9: Classify description/Other lines

**Files:**
- Modify: `src/token_wbtest.mbt`

**Step 1: Write tests for description lines**

```moonbit
///|
test "classify_line: description text" {
  let (tok, _) = classify_line("  A feature with a single scenario.", 2, Normal)
  inspect(tok, content="Other({line: 2, column: None}, \"  A feature with a single scenario.\")")
}
```

This should already pass since `Other` is the fallback. Verify and commit.

**Step 2: Commit**

```bash
git add src/token_wbtest.mbt
git commit -m "test(lexer): verify description lines classify as Other"
```

---

### Task 10: Implement tokenize (eager)

**Files:**
- Modify: `src/token.mbt`
- Modify: `src/token_wbtest.mbt`

**Step 1: Write failing test**

```moonbit
///|
test "tokenize: minimal feature" {
  let src = Source::from_string("Feature: Minimal\n\n  Scenario: First\n    Given a thing\n")
  let tokens = tokenize(src)
  inspect(tokens.length(), content="5")
  inspect(tokens[0], content="FeatureLine({line: 1, column: Some(1)}, \"Feature\", \"Minimal\")")
  inspect(tokens[1], content="Empty({line: 2, column: None})")
  inspect(tokens[2], content="ScenarioLine({line: 3, column: Some(3)}, \"Scenario\", \"First\")")
  inspect(tokens[3], content="StepLine({line: 4, column: Some(5)}, \"Given \", Context, \"a thing\")")
  inspect(tokens[4], content="Eof({line: 5, column: None})")
}
```

**Step 2: Implement tokenize**

```moonbit
///|
/// Tokenize a Source into an array of Tokens (eager).
/// Processes all lines and appends an Eof token.
pub fn tokenize(source : Source) -> Array[Token] {
  let tokens : Array[Token] = []
  let mut state : LexerState = Normal
  for i = 1; i <= source.line_count(); i = i + 1 {
    match source.line(i) {
      Some(line) => {
        let (token, next_state) = classify_line(line, i, state)
        tokens.push(token)
        state = next_state
      }
      None => ()
    }
  }
  tokens.push(Eof({ line: source.line_count() + 1, column: None }))
  tokens
}
```

**Step 3: Run tests, commit**

```bash
git add src/token.mbt src/token_wbtest.mbt
git commit -m "feat(lexer): implement tokenize (eager array)"
```

---

### Task 11: Implement Lexer struct with Iter[Token]

**Files:**
- Modify: `src/token.mbt`
- Modify: `src/token_wbtest.mbt`

**Step 1: Write failing tests**

```moonbit
///|
test "Lexer::iter produces same tokens as tokenize" {
  let src = Source::from_string("Feature: Test\n  Scenario: S1\n    Given x\n")
  let eager = tokenize(src)
  let lazy = Lexer::new(src).iter().collect()
  inspect(eager.length() == lazy.length(), content="true")
  inspect(eager[0] == lazy[0], content="true")
  inspect(eager[1] == lazy[1], content="true")
  inspect(eager[2] == lazy[2], content="true")
}
```

**Step 2: Implement Lexer**

```moonbit
///|
/// A lazy lexer that produces tokens on demand via Iter[Token].
pub struct Lexer {
  source : Source
}

///|
/// Create a new Lexer for the given Source.
pub fn Lexer::new(source : Source) -> Lexer {
  { source, }
}

///|
/// Return an iterator over the tokens in this source.
pub fn Lexer::iter(self : Lexer) -> Iter[Token] {
  Iter::new(fn(visit) {
    let mut state : LexerState = Normal
    for i = 1; i <= self.source.line_count(); i = i + 1 {
      match self.source.line(i) {
        Some(line) => {
          let (token, next_state) = classify_line(line, i, state)
          state = next_state
          guard visit(token) is IterContinue else { break IterEnd }
        }
        None => ()
      }
    } else {
      let eof = Eof({ line: self.source.line_count() + 1, column: None })
      visit(eof)
    }
  })
}
```

**Step 3: Run tests, commit**

```bash
git add src/token.mbt src/token_wbtest.mbt
git commit -m "feat(lexer): implement Lexer struct with Iter[Token]"
```

---

### Task 12: Integration test with fixture files

**Files:**
- Modify: `src/token_wbtest.mbt` (or `src/gherkin_test.mbt`)

**Step 1: Write integration test against minimal.feature content**

```moonbit
///|
test "tokenize: full minimal.feature" {
  let input = "Feature: Minimal\n  A feature with a single scenario.\n\n  Scenario: First scenario\n    Given a precondition\n    When an action is performed\n    Then an outcome is observed\n"
  let src = Source::from_string(input)
  let tokens = tokenize(src)
  // Feature, description, empty, Scenario, Given, When, Then, trailing empty, Eof
  inspect(tokens[0], content="FeatureLine({line: 1, column: Some(1)}, \"Feature\", \"Minimal\")")
  inspect(tokens[3], content="ScenarioLine({line: 4, column: Some(3)}, \"Scenario\", \"First scenario\")")
  inspect(tokens[4], content="StepLine({line: 5, column: Some(5)}, \"Given \", Context, \"a precondition\")")
}
```

**Step 2: Write integration test for tags.feature content**

```moonbit
///|
test "tokenize: tags fixture" {
  let input = "@smoke @regression\nFeature: Tagged feature\n\n  @wip\n  Scenario: Tagged scenario\n    Given something\n"
  let src = Source::from_string(input)
  let tokens = tokenize(src)
  inspect(tokens[0], content="TagLine({line: 1, column: Some(1)}, [\"@smoke\", \"@regression\"])")
  inspect(tokens[1], content="FeatureLine({line: 2, column: Some(1)}, \"Feature\", \"Tagged feature\")")
  inspect(tokens[3], content="TagLine({line: 4, column: Some(3)}, [\"@wip\"])")
}
```

**Step 3: Write integration test for doc_strings.feature content**

```moonbit
///|
test "tokenize: doc string fixture" {
  let input = "Feature: Doc Strings\n\n  Scenario: A step with a doc string\n    Given the following text:\n      \"\"\"\n      This is a doc string.\n      \"\"\"\n"
  let src = Source::from_string(input)
  let tokens = tokenize(src)
  inspect(tokens[4], content="DocStringSeparator({line: 5, column: Some(7)}, \"\\\"\\\"\\\"\", None)")
  inspect(tokens[5], content="Other({line: 6, column: None}, \"      This is a doc string.\")")
  inspect(tokens[6], content="DocStringSeparator({line: 7, column: Some(7)}, \"\\\"\\\"\\\"\", None)")
}
```

**Step 4: Run all tests, commit**

```bash
git add src/token_wbtest.mbt
git commit -m "test(lexer): integration tests against fixture content"
```

---

### Task 13: Code coverage analysis

**Step 1: Run coverage**

Run: `moon coverage analyze 2>&1`

Review output to identify any uncovered branches in `classify_line`.

**Step 2: Add tests for any uncovered paths**

Likely candidates:
- Backtick doc strings (`` ``` ``)
- Doc string with media type
- Table row edge cases (empty cells, trailing pipe)
- `Scenario Template:` and `Scenarios:` synonyms

**Step 3: Commit coverage improvements**

```bash
git add src/token_wbtest.mbt
git commit -m "test(lexer): improve coverage for edge cases"
```

---

### Task 14: Final cleanup — format, info, full test

**Step 1: Run quality gates**

Run:
```bash
moon fmt
moon info
moon test
moon coverage analyze
```

Verify no regressions, interface file changes are expected.

**Step 2: Commit any formatting/interface changes**

```bash
git add -A
git commit -m "chore: format and update package interface"
```

**Step 3: Close the beads issue**

Run: `bd close gherkin-1m4`
