Feature: WASM Component Model Integration
  As a cross-language consumer
  I want to use the Gherkin parser via its WASM component interface
  So that I can parse, tokenize, and write Gherkin in any language

  Scenario: Parse a simple feature via WASM component
    Given a Gherkin source
      """
      Feature: Login
        Scenario: Basic login
          Given a registered user
          When they enter credentials
          Then they see the dashboard
      """
    When I call the parse function via the component
    Then the result should be ok
    And the JSON should contain "Feature"
    And the JSON should contain "Login"
    And the JSON should contain "Scenario"

  Scenario: Parse returns error for invalid input
    Given a Gherkin source
      """
      not a valid feature file
      """
    When I call the parse function via the component
    Then the result should be an error
    And the error should contain "expected"

  Scenario: Tokenize a simple feature via WASM component
    Given a Gherkin source
      """
      Feature: Hello
        Scenario: World
          Given something
      """
    When I call the tokenize function via the component
    Then the result should be ok
    And the JSON should contain "FeatureLine"
    And the JSON should contain "ScenarioLine"
    And the JSON should contain "StepLine"

  Scenario: Write a JSON AST back to Gherkin via WASM component
    Given a Gherkin source
      """
      Feature: Round Trip
        Scenario: Echo
          Given a step
          When another step
          Then final step
      """
    When I call the parse function via the component
    And I call the write function with the parsed JSON
    Then the write result should be ok
    And the written output should contain "Feature: Round Trip"
    And the written output should contain "Given a step"

  Scenario: Parse-then-write round-trip preserves structure
    Given a Gherkin source
      """
      @smoke
      Feature: Tagged Feature
        Background:
          Given a common setup

        Scenario: First
          Given a step
          Then a result
      """
    When I call the parse function via the component
    And I call the write function with the parsed JSON
    Then the write result should be ok
    And the written output should contain "@smoke"
    And the written output should contain "Feature: Tagged Feature"
    And the written output should contain "Background:"
    And the written output should contain "Scenario: First"
