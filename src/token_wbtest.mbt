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

// ── classify_line: keyword classification via language parameter ──

///|
test "classify_line: keywords classified with default English" {
  let (tok, _) = classify_line("Feature: Login", 1, Normal)
  inspect(
    tok,
    content="FeatureLine({line: 1, column: Some(1)}, \"Feature\", \"Login\")",
  )
}

// ── tokenize: keyword classification ──

///|
test "tokenize: Feature keyword" {
  let tokens = tokenize(Source::from_string("Feature: Login"))
  inspect(
    tokens[0],
    content="FeatureLine({line: 1, column: Some(1)}, \"Feature\", \"Login\")",
  )
}

///|
test "tokenize: Scenario keyword" {
  let tokens = tokenize(Source::from_string("  Scenario: First scenario"))
  inspect(
    tokens[0],
    content="ScenarioLine({line: 1, column: Some(3)}, \"Scenario\", \"First scenario\", Scenario)",
  )
}

///|
test "tokenize: Scenario Outline keyword" {
  let tokens = tokenize(
    Source::from_string("  Scenario Outline: Eating cucumbers"),
  )
  inspect(
    tokens[0],
    content="ScenarioLine({line: 1, column: Some(3)}, \"Scenario Outline\", \"Eating cucumbers\", ScenarioOutline)",
  )
}

///|
test "tokenize: Background keyword" {
  let tokens = tokenize(Source::from_string("  Background:"))
  inspect(
    tokens[0],
    content="BackgroundLine({line: 1, column: Some(3)}, \"Background\", \"\")",
  )
}

///|
test "tokenize: Rule keyword" {
  let tokens = tokenize(Source::from_string("  Rule: Business rule one"))
  inspect(
    tokens[0],
    content="RuleLine({line: 1, column: Some(3)}, \"Rule\", \"Business rule one\")",
  )
}

///|
test "tokenize: Examples keyword" {
  let tokens = tokenize(Source::from_string("    Examples:"))
  inspect(
    tokens[0],
    content="ExamplesLine({line: 1, column: Some(5)}, \"Examples\", \"\")",
  )
}

///|
test "tokenize: Example as synonym for Scenario" {
  let tokens = tokenize(Source::from_string("  Example: A test"))
  inspect(
    tokens[0],
    content="ScenarioLine({line: 1, column: Some(3)}, \"Example\", \"A test\", Scenario)",
  )
}

///|
test "tokenize: Scenario Template synonym" {
  let tokens = tokenize(
    Source::from_string("  Scenario Template: Parameterized"),
  )
  inspect(
    tokens[0],
    content="ScenarioLine({line: 1, column: Some(3)}, \"Scenario Template\", \"Parameterized\", ScenarioOutline)",
  )
}

///|
test "tokenize: Scenarios synonym for Examples" {
  let tokens = tokenize(Source::from_string("    Scenarios:"))
  inspect(
    tokens[0],
    content="ExamplesLine({line: 1, column: Some(5)}, \"Scenarios\", \"\")",
  )
}

// ── tokenize: step classification ──

///|
test "tokenize: Given step" {
  let tokens = tokenize(Source::from_string("    Given a precondition"))
  inspect(
    tokens[0],
    content="StepLine({line: 1, column: Some(5)}, \"Given \", Context, \"a precondition\")",
  )
}

///|
test "tokenize: When step" {
  let tokens = tokenize(
    Source::from_string("    When an action is performed"),
  )
  inspect(
    tokens[0],
    content="StepLine({line: 1, column: Some(5)}, \"When \", Action, \"an action is performed\")",
  )
}

///|
test "tokenize: Then step" {
  let tokens = tokenize(
    Source::from_string("    Then an outcome is observed"),
  )
  inspect(
    tokens[0],
    content="StepLine({line: 1, column: Some(5)}, \"Then \", Outcome, \"an outcome is observed\")",
  )
}

///|
test "tokenize: And step" {
  let tokens = tokenize(Source::from_string("    And another step"))
  inspect(
    tokens[0],
    content="StepLine({line: 1, column: Some(5)}, \"And \", Conjunction, \"another step\")",
  )
}

///|
test "tokenize: But step" {
  let tokens = tokenize(Source::from_string("    But not this"))
  inspect(
    tokens[0],
    content="StepLine({line: 1, column: Some(5)}, \"But \", Conjunction, \"not this\")",
  )
}

///|
test "tokenize: star step" {
  let tokens = tokenize(Source::from_string("  * I have eggs"))
  inspect(
    tokens[0],
    content="StepLine({line: 1, column: Some(3)}, \"* \", Unknown, \"I have eggs\")",
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
    content="ScenarioLine({line: 2, column: Some(3)}, \"Scenario\", \"Basic login\", Scenario)",
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

// ── Token::to_json ──

///|
test "Token::to_json: FeatureLine" {
  let tok : Token = FeatureLine({ line: 1, column: Some(1) }, "Feature", "Login")
  let json = tok.to_json().stringify()
  assert_true(json.contains("FeatureLine"))
  assert_true(json.contains("Feature"))
  assert_true(json.contains("Login"))
}

///|
test "Token::to_json: StepLine" {
  let tok : Token = StepLine(
    { line: 3, column: Some(5) },
    "Given ",
    Context,
    "a precondition",
  )
  let json = tok.to_json().stringify()
  assert_true(json.contains("StepLine"))
  assert_true(json.contains("Given"))
  assert_true(json.contains("a precondition"))
}

///|
test "tokenize to JSON array" {
  let src = Source::from_string(
    "Feature: Login\n  Scenario: Test\n    Given a user",
  )
  let tokens = tokenize(src)
  let json = tokens.to_json().stringify()
  assert_true(json.has_prefix("["))
  assert_true(json.has_suffix("]"))
  assert_true(json.contains("FeatureLine"))
  assert_true(json.contains("ScenarioLine"))
  assert_true(json.contains("StepLine"))
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
