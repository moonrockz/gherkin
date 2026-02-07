Feature: Parser Error Handling
  The parser should produce clear errors for invalid input.

  Scenario: Reject completely invalid input
    Given a Gherkin input
      """
      This is not valid Gherkin at all.
      Just some random text.
      """
    When I parse the file
    Then the parser should fail
    And the error should mention "expected"

  Scenario: Report missing Feature keyword
    Given a Gherkin input
      """
      Scenario: Orphan scenario
        Given something
      """
    When I parse the file
    Then the parser should fail
    And the error should mention "Feature"
