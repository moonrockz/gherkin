Feature: Markdown with Gherkin
  Scenario: Parse the public Cucumber MDG reference example
    Given a Gherkin file "cucumber_reference.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the feature name should be "Staying alive"
    And the rule name should be "If you don't eat you die"
    And the scenario outline name should be "eating"
    And the scenario should have 3 steps
    And the scenario steps should be:
      | keyword | text                            |
      | Given   | there are <start> cucumbers     |
      | When    | I eat <eat> cucumbers           |
      | Then    | I should have <left> cucumbers  |
    And the scenario should have tag "@important"
    And the scenario should have tag "@essential"
    And the examples table should have 2 rows
    And the examples table should contain row "20,5,15"

  Scenario: Parse Cucumber's public MDG data table fixture
    Given a Gherkin file "cucumber_datatables.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the feature name should be "DataTables"
    And the scenario should start at line 3 column 5
    And the first step should start at line 5 column 3
    And the data table should have 2 rows
    And the data table should contain cell "boo"

  Scenario: Parse Cucumber's public MDG doc string fixture
    Given a Gherkin file "cucumber_docstrings.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the feature name should be "DocString variations"
    And the scenario should start at line 3 column 5
    And the first step should start at line 5 column 3
    And the doc string content should be '```'
    And the doc string delimiter should be "````"
    And the doc string should start at line 6 column 1

  Scenario: Parse background and all step keyword kinds
    Given a Gherkin file "keywords.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the feature should have tag "@library"
    And the background should have 1 step
    And the scenario steps should be:
      | keyword | text                      |
      | When    | the customer pays         |
      | And     | a receipt is created      |
      | Then    | the order is complete     |
      | But     | no duplicate order exists |

  Scenario: Parse a Markdown feature file
    Given a Gherkin file "minimal.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the output should contain 1 scenario(s)
    And the scenario name should be "Markdown scenario"

  Scenario: Do not select MDG for an ordinary Markdown file
    Given a Gherkin file "plain_markdown.md"
    When I parse the file
    Then the parser should fail

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

  Scenario: Parse a tilde fence with media type
    Given a Gherkin file "tilde_fence.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the doc string content should be '{"ready": true}'
    And the doc string media type should be "json"
    And the doc string delimiter should be "~~~"

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

  Scenario: Leave an unindented GFM table as prose
    Given a Gherkin file "unindented_table.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the scenario should have no data table

  Scenario: Leave a table indented beyond five spaces as prose
    Given a Gherkin file "overindented_table.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the scenario should have no data table

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

  Scenario: Preserve source locations after Unicode prose
    Given a Gherkin file "unicode_locations.feature.md"
    When I parse the file
    Then the parser should succeed
    And the output should be valid JSON
    And the scenario should start at line 5 column 4
    And the first step should start at line 7 column 3
