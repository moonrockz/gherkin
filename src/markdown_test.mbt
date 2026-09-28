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

///|
test "parse_markdown exposes table cells through the library API" {
  let source = @gherkin.Source::from_string(
    "# Feature: Tables\n\n## Scenario: Values\n\n- Given these records\n  name | value\n  ---- | -----\n  key  | a\\|b\n",
  )
  let document = @gherkin.parse_markdown(source)
  match document.feature {
    Some(feature) =>
      match feature.children[0] {
        Scenario(scenario) =>
          match scenario.steps[0].argument {
            Some(DataTable(table)) => {
              @debug.debug_inspect(table.rows.length(), content="2")
              @debug.debug_inspect(
                table.rows[1].cells[1].value,
                content="\"a|b\"",
              )
            }
            _ => fail("expected a data table")
          }
        _ => fail("expected a scenario")
      }
    None => fail("expected a feature")
  }
}

///|
test "parse_markdown exposes fenced doc strings through the library API" {
  let source = @gherkin.Source::from_string(
    "# Feature: Bodies\n\n## Scenario: Payload\n\n- Given this body\n  ~~~json\n  {\"ready\": true}\n  ~~~\n",
  )
  let document = @gherkin.parse_markdown(source)
  match document.feature {
    Some(feature) =>
      match feature.children[0] {
        Scenario(scenario) =>
          match scenario.steps[0].argument {
            Some(DocString(body)) => {
              @debug.debug_inspect(
                body.content,
                content="\"{\\\"ready\\\": true}\"",
              )
              @debug.debug_inspect(body.media_type, content="Some(\"json\")")
              @debug.debug_inspect(body.delimiter, content="\"~~~\"")
            }
            _ => fail("expected a doc string")
          }
        _ => fail("expected a scenario")
      }
    None => fail("expected a feature")
  }
}

///|
test "parse_markdown attaches an unindented fence to the preceding step" {
  let source = @gherkin.Source::from_string(
    "## Feature: DocString variations\n\n### Scenario: minimalistic\n\n* And a DocString with an implicitly escaped separator inside\n````\n```\n````\n",
  )
  let document = @gherkin.parse_markdown(source)
  match document.feature {
    Some(feature) =>
      match feature.children[0] {
        Scenario(scenario) =>
          match scenario.steps[0].argument {
            Some(DocString(body)) => {
              @debug.debug_inspect(body.content, content="\"```\"")
              @debug.debug_inspect(body.delimiter, content="\"````\"")
              @debug.debug_inspect(body.location.line, content="6")
              @debug.debug_inspect(body.location.column, content="Some(1)")
            }
            _ => fail("expected a doc string")
          }
        _ => fail("expected a scenario")
      }
    None => fail("expected a feature")
  }
}

///|
test "parse_markdown exposes tags and example rows through the library API" {
  let source = @gherkin.Source::from_string(
    "# Feature: Outlines\n\n`@smoke`\n## Scenario Outline: Value <value>\n\n* Given <value> exists\n\n### Examples:\n\n  | value |\n  | ----- |\n  | pear  |\n",
  )
  let document = @gherkin.parse_markdown(source)
  match document.feature {
    Some(feature) =>
      match feature.children[0] {
        Scenario(scenario) => {
          @debug.debug_inspect(scenario.kind, content="ScenarioOutline")
          @debug.debug_inspect(scenario.tags[0].name, content="\"@smoke\"")
          @debug.debug_inspect(scenario.examples.length(), content="1")
          @debug.debug_inspect(
            scenario.examples[0].table_body[0].cells[0].value,
            content="\"pear\"",
          )
        }
        _ => fail("expected a scenario outline")
      }
    None => fail("expected a feature")
  }
}

///|
test "parse_markdown accepts an implicit feature and translated keywords" {
  let source = @gherkin.Source::from_string(
    "# language: fr\n# Café\n\n## Scénario: Ajouter un fruit\n\n- Soit une poire\n",
  )
  let document = @gherkin.parse_markdown(source)
  match document.feature {
    Some(feature) => {
      @debug.debug_inspect(feature.language, content="\"fr\"")
      @debug.debug_inspect(feature.name, content="\"Café\"")
      match feature.children[0] {
        Scenario(scenario) =>
          @debug.debug_inspect(scenario.steps[0].keyword, content="\"Soit \"")
        _ => fail("expected a scenario")
      }
    }
    None => fail("expected a feature")
  }
}
