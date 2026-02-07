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
