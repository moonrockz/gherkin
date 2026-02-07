///|
test "Token::FeatureLine construction" {
  let tok = Token::FeatureLine({ line: 1, column: Some(1) }, "Feature", "Login")
  inspect(
    tok,
    content="FeatureLine({line: 1, column: Some(1)}, \"Feature\", \"Login\")",
  )
}

///|
test "Token::Empty construction" {
  let tok = Token::Empty({ line: 5, column: None })
  inspect(tok, content="Empty({line: 5, column: None})")
}

///|
test "Token::StepLine construction" {
  let tok = Token::StepLine(
    { line: 3, column: Some(5) },
    "Given ",
    Context,
    "a precondition",
  )
  inspect(
    tok,
    content="StepLine({line: 3, column: Some(5)}, \"Given \", Context, \"a precondition\")",
  )
}

///|
test "LexerState variants" {
  inspect(LexerState::Normal, content="Normal")
  inspect(
    LexerState::InDocString("\"\"\""),
    content="InDocString(\"\\\"\\\"\\\"\")",
  )
}

// ── classify_line: empty lines ──

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

// ── classify_line: comments and language ──

///|
test "classify_line: comment" {
  let (tok, _) = classify_line("# This is a comment", 1, Normal)
  inspect(
    tok,
    content="Comment({line: 1, column: Some(1)}, \"# This is a comment\")",
  )
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

///|
test "classify_line: language directive with spaces" {
  let (tok, _) = classify_line("#language:  no  ", 1, Normal)
  inspect(tok, content="Language({line: 1, column: Some(1)}, \"no\")")
}

// ── classify_line: tags ──

///|
test "classify_line: single tag" {
  let (tok, _) = classify_line("@smoke", 1, Normal)
  inspect(tok, content="TagLine({line: 1, column: Some(1)}, [\"@smoke\"])")
}

///|
test "classify_line: multiple tags" {
  let (tok, _) = classify_line("@smoke @regression", 1, Normal)
  inspect(
    tok,
    content="TagLine({line: 1, column: Some(1)}, [\"@smoke\", \"@regression\"])",
  )
}

///|
test "classify_line: indented tags" {
  let (tok, _) = classify_line("  @wip", 4, Normal)
  inspect(tok, content="TagLine({line: 4, column: Some(3)}, [\"@wip\"])")
}

// ── classify_line: table rows ──

///|
test "classify_line: table row" {
  let (tok, _) = classify_line("      | name  | email |", 5, Normal)
  inspect(
    tok,
    content="TableRow({line: 5, column: Some(7)}, [\"name\", \"email\"])",
  )
}

///|
test "classify_line: table row with data" {
  let (tok, _) = classify_line("| Alice | alice@test.com |", 1, Normal)
  inspect(
    tok,
    content="TableRow({line: 1, column: Some(1)}, [\"Alice\", \"alice@test.com\"])",
  )
}

// ── classify_line: doc strings ──

///|
test "classify_line: doc string open triple-quote" {
  let (tok, state) = classify_line("      \"\"\"", 5, Normal)
  inspect(
    tok,
    content="DocStringSeparator({line: 5, column: Some(7)}, \"\\\"\\\"\\\"\", None)",
  )
  inspect(state, content="InDocString(\"\\\"\\\"\\\"\")")
}

///|
test "classify_line: doc string with media type" {
  let (tok, state) = classify_line("  \"\"\"json", 3, Normal)
  inspect(
    tok,
    content="DocStringSeparator({line: 3, column: Some(3)}, \"\\\"\\\"\\\"\", Some(\"json\"))",
  )
  inspect(state, content="InDocString(\"\\\"\\\"\\\"\")")
}

///|
test "classify_line: content inside doc string" {
  let (tok, state) = classify_line(
    "  This is content",
    6,
    InDocString("\"\"\""),
  )
  inspect(tok, content="Other({line: 6, column: None}, \"  This is content\")")
  inspect(state, content="InDocString(\"\\\"\\\"\\\"\")")
}

///|
test "classify_line: doc string close" {
  let (tok, state) = classify_line("      \"\"\"", 8, InDocString("\"\"\""))
  inspect(
    tok,
    content="DocStringSeparator({line: 8, column: Some(7)}, \"\\\"\\\"\\\"\", None)",
  )
  inspect(state, content="Normal")
}

///|
test "classify_line: backtick doc string open" {
  let (tok, state) = classify_line("  ```", 3, Normal)
  inspect(
    tok,
    content="DocStringSeparator({line: 3, column: Some(3)}, \"```\", None)",
  )
  inspect(state, content="InDocString(\"```\")")
}

///|
test "classify_line: backtick doc string close" {
  let (tok, state) = classify_line("  ```", 5, InDocString("```"))
  inspect(
    tok,
    content="DocStringSeparator({line: 5, column: Some(3)}, \"```\", None)",
  )
  inspect(state, content="Normal")
}

///|
test "classify_line: triple-quote inside backtick docstring is content" {
  let (tok, state) = classify_line("  \"\"\"", 4, InDocString("```"))
  inspect(tok, content="Other({line: 4, column: None}, \"  \\\"\\\"\\\"\")")
  inspect(state, content="InDocString(\"```\")")
}

// ── classify_line: keywords ──

///|
test "classify_line: Feature keyword" {
  let (tok, _) = classify_line("Feature: Login", 1, Normal)
  inspect(
    tok,
    content="FeatureLine({line: 1, column: Some(1)}, \"Feature\", \"Login\")",
  )
}

///|
test "classify_line: Scenario keyword" {
  let (tok, _) = classify_line("  Scenario: First scenario", 4, Normal)
  inspect(
    tok,
    content="ScenarioLine({line: 4, column: Some(3)}, \"Scenario\", \"First scenario\")",
  )
}

///|
test "classify_line: Scenario Outline keyword" {
  let (tok, _) = classify_line(
    "  Scenario Outline: Eating cucumbers",
    3,
    Normal,
  )
  inspect(
    tok,
    content="ScenarioLine({line: 3, column: Some(3)}, \"Scenario Outline\", \"Eating cucumbers\")",
  )
}

///|
test "classify_line: Background keyword" {
  let (tok, _) = classify_line("  Background:", 3, Normal)
  inspect(
    tok,
    content="BackgroundLine({line: 3, column: Some(3)}, \"Background\", \"\")",
  )
}

///|
test "classify_line: Rule keyword" {
  let (tok, _) = classify_line("  Rule: Business rule one", 3, Normal)
  inspect(
    tok,
    content="RuleLine({line: 3, column: Some(3)}, \"Rule\", \"Business rule one\")",
  )
}

///|
test "classify_line: Examples keyword" {
  let (tok, _) = classify_line("    Examples:", 8, Normal)
  inspect(
    tok,
    content="ExamplesLine({line: 8, column: Some(5)}, \"Examples\", \"\")",
  )
}

///|
test "classify_line: Example as synonym for Scenario" {
  let (tok, _) = classify_line("  Example: A test", 4, Normal)
  inspect(
    tok,
    content="ScenarioLine({line: 4, column: Some(3)}, \"Example\", \"A test\")",
  )
}

///|
test "classify_line: Scenario Template synonym" {
  let (tok, _) = classify_line("  Scenario Template: Parameterized", 3, Normal)
  inspect(
    tok,
    content="ScenarioLine({line: 3, column: Some(3)}, \"Scenario Template\", \"Parameterized\")",
  )
}

///|
test "classify_line: Scenarios synonym for Examples" {
  let (tok, _) = classify_line("    Scenarios:", 8, Normal)
  inspect(
    tok,
    content="ExamplesLine({line: 8, column: Some(5)}, \"Scenarios\", \"\")",
  )
}

// ── classify_line: steps ──

///|
test "classify_line: Given step" {
  let (tok, _) = classify_line("    Given a precondition", 5, Normal)
  inspect(
    tok,
    content="StepLine({line: 5, column: Some(5)}, \"Given \", Context, \"a precondition\")",
  )
}

///|
test "classify_line: When step" {
  let (tok, _) = classify_line("    When an action is performed", 6, Normal)
  inspect(
    tok,
    content="StepLine({line: 6, column: Some(5)}, \"When \", Action, \"an action is performed\")",
  )
}

///|
test "classify_line: Then step" {
  let (tok, _) = classify_line("    Then an outcome is observed", 7, Normal)
  inspect(
    tok,
    content="StepLine({line: 7, column: Some(5)}, \"Then \", Outcome, \"an outcome is observed\")",
  )
}

///|
test "classify_line: And step" {
  let (tok, _) = classify_line("    And another step", 6, Normal)
  inspect(
    tok,
    content="StepLine({line: 6, column: Some(5)}, \"And \", Conjunction, \"another step\")",
  )
}

///|
test "classify_line: But step" {
  let (tok, _) = classify_line("    But not this", 7, Normal)
  inspect(
    tok,
    content="StepLine({line: 7, column: Some(5)}, \"But \", Conjunction, \"not this\")",
  )
}

///|
test "classify_line: star step" {
  let (tok, _) = classify_line("  * I have eggs", 5, Normal)
  inspect(
    tok,
    content="StepLine({line: 5, column: Some(3)}, \"* \", Unknown, \"I have eggs\")",
  )
}

///|
test "classify_line: backtick doc string with media type" {
  let (tok, state) = classify_line("  ```yaml", 3, Normal)
  inspect(
    tok,
    content="DocStringSeparator({line: 3, column: Some(3)}, \"```\", Some(\"yaml\"))",
  )
  inspect(state, content="InDocString(\"```\")")
}

// ── classify_line: description/Other ──

///|
test "classify_line: description text" {
  let (tok, _) = classify_line("  A feature with a single scenario.", 2, Normal)
  inspect(
    tok,
    content="Other({line: 2, column: None}, \"  A feature with a single scenario.\")",
  )
}

// ── tokenize: full source ──

///|
test "tokenize: simple feature" {
  let src = Source::from_string(
    "Feature: Login\n  Scenario: Basic login\n    Given a user",
  )
  let tokens = tokenize(src)
  inspect(tokens.length(), content="4")
  inspect(
    tokens[0],
    content="FeatureLine({line: 1, column: Some(1)}, \"Feature\", \"Login\")",
  )
  inspect(
    tokens[1],
    content="ScenarioLine({line: 2, column: Some(3)}, \"Scenario\", \"Basic login\")",
  )
  inspect(
    tokens[2],
    content="StepLine({line: 3, column: Some(5)}, \"Given \", Context, \"a user\")",
  )
  inspect(tokens[3], content="Eof({line: 4, column: None})")
}

///|
test "tokenize: empty source" {
  let src = Source::from_string("")
  let tokens = tokenize(src)
  inspect(tokens.length(), content="2")
  inspect(tokens[0], content="Empty({line: 1, column: None})")
  inspect(tokens[1], content="Eof({line: 2, column: None})")
}

// ── Lexer iterator ──

///|
test "Lexer::next: produces tokens and Eof" {
  let src = Source::from_string("Feature: Test")
  let lex = Lexer::new(src)
  let first = lex.next()
  inspect(
    first,
    content="Some(FeatureLine({line: 1, column: Some(1)}, \"Feature\", \"Test\"))",
  )
  let second = lex.next()
  inspect(second, content="Some(Eof({line: 2, column: None}))")
  let third = lex.next()
  inspect(third, content="None")
}

///|
test "Lexer::iter: collects all tokens" {
  let src = Source::from_string("@smoke\nFeature: Test")
  let lex = Lexer::new(src)
  let tokens = lex.iter().collect()
  inspect(tokens.length(), content="3")
  inspect(
    tokens[0],
    content="TagLine({line: 1, column: Some(1)}, [\"@smoke\"])",
  )
  inspect(
    tokens[1],
    content="FeatureLine({line: 2, column: Some(1)}, \"Feature\", \"Test\")",
  )
  inspect(tokens[2], content="Eof({line: 3, column: None})")
}
