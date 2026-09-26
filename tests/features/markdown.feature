Feature: Markdown with Gherkin
  Scenario: Parse a Markdown feature file
    Given a Gherkin file "minimal.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the output should contain 1 scenario(s)
    And the output should contain keyword "Markdown scenario"

  Scenario: Ignore Gherkin syntax in prose and unrelated code fences
    Given a Gherkin file "prose.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the output should contain 1 scenario(s)
    And the scenario should have 1 step
    And the feature description should be empty

  Scenario: Ignore fenced code under an unrelated list item
    Given a Gherkin file "list_prose.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the feature description should be empty

  Scenario: Parse tags above a Markdown heading
    Given a Gherkin file "tags.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the scenario should have tag "@smoke"
    And the scenario should have tag "@fast"

  Scenario: Parse an indented GFM data table
    Given a Gherkin file "table.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the output should contain a "DataTable" node
    And the data table should have 2 rows

  Scenario: Parse GFM tables without outer pipes
    Given a Gherkin file "gfm_table.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the data table should have 2 rows
    And the data table should contain cell "a|b"

  Scenario: Parse a fenced code block as a doc string
    Given a Gherkin file "code.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the output should contain a "DocString" node
    And the doc string content should be '{"ok": true}'

  Scenario: Keep shorter fences inside a doc string
    Given a Gherkin file "long_fence.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the doc string content should be '```'

  Scenario: Parse a rule and examples table
    Given a Gherkin file "outline.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the output should contain a "Rule" node
    And the output should contain a "ScenarioOutline" node
    And the scenario should have tag "@cases"
    And the output should contain a "Examples" node
    And the examples table should have 1 row

  Scenario: Parse a five-space-indented examples table
    Given a Gherkin file "deep_table.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the examples table should have 1 row

  Scenario: Parse a five-space-indented data table
    Given a Gherkin file "deep_data_table.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the data table should have 2 rows

  Scenario: Use the first heading as an implicit feature
    Given a Gherkin file "implicit.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the feature name should be "Pantry inventory"
    And the output should contain 1 scenario(s)

  Scenario: Parse translated Markdown keywords
    Given a Gherkin file "french.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the feature name should be "Inventaire"
    And the output should contain 1 scenario(s)
    And the scenario should have 1 step
