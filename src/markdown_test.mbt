///|
test "parse_markdown parses source without a URI" {
  let source = @gherkin.Source::from_string(
    "# Feature: Library API\n\n## Scenario: Works\n\n- Given input\n",
  )
  let document = @gherkin.parse_markdown(source)
  match document.feature {
    Some(feature) => {
      @debug.debug_inspect(feature.name, content="\"Library API\"")
      @debug.debug_inspect(feature.children.length(), content="1")
    }
    None => fail("expected a feature")
  }
}

///|
test "Lexer reads Markdown tokens from a feature.md source" {
  let source = @gherkin.Source::from_string(
    "# Feature: Streaming\n\n## Scenario: Reads\n\n- Given input\n",
    uri="sample.feature.md",
  )
  let names : Array[String] = []
  for token in @gherkin.Lexer::new(source).iter() {
    match token {
      FeatureLine(_, _, _) => names.push("feature")
      ScenarioLine(_, _, _, _) => names.push("scenario")
      StepLine(_, _, _, _) => names.push("step")
      _ => ()
    }
  }
  @debug.debug_inspect(names.join(","), content="\"feature,scenario,step\"")
}

///|
test "MDG tags require single backticks" {
  let source = @gherkin.Source::from_string(
    "# Feature: Tags\n\n``@not_a_tag``\n## Scenario: One\n\n- Given input\n",
  )
  let document = @gherkin.parse_markdown(source)
  match document.feature {
    Some(feature) =>
      match feature.children[0] {
        Scenario(scenario) =>
          @debug.debug_inspect(scenario.tags.length(), content="0")
        _ => fail("expected a scenario")
      }
    None => fail("expected a feature")
  }
}
