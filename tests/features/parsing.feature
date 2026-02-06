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

  Scenario: Parse a feature with Background
    Given a Gherkin file "background.feature"
    When I parse the file
    Then the parser should succeed
    And the output should contain a "Background" node

  Scenario: Parse a Scenario Outline
    Given a Gherkin file "scenario_outline.feature"
    When I parse the file
    Then the parser should succeed
    And the output should contain a "ScenarioOutline" node

  Scenario: Parse tags
    Given a Gherkin file "tags.feature"
    When I parse the file
    Then the parser should succeed
    And the output should contain keyword "@smoke"

  Scenario: Parse data tables
    Given a Gherkin file "data_tables.feature"
    When I parse the file
    Then the parser should succeed
    And the output should contain a "DataTable" node

  Scenario: Parse doc strings
    Given a Gherkin file "doc_strings.feature"
    When I parse the file
    Then the parser should succeed
    And the output should contain a "DocString" node

  Scenario: Parse comments
    Given a Gherkin file "comments.feature"
    When I parse the file
    Then the parser should succeed
    And the output should contain a "Comment" node

  Scenario: Parse rules
    Given a Gherkin file "rules.feature"
    When I parse the file
    Then the parser should succeed
    And the output should contain a "Rule" node

  Scenario: Parse inline Gherkin text
    Given a Gherkin input
      """
      Feature: Inline test
        Scenario: A simple scenario
          Given something
          When an action
          Then a result
      """
    When I parse the file
    Then the parser should succeed
    And the output should contain 1 scenario(s)
