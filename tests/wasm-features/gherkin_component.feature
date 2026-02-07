Feature: WASM Component Model Integration
  As a cross-language consumer
  I want to use the Gherkin parser via its WASM component interface
  So that I can parse, tokenize, and write Gherkin in any language

  # --- Parser: basic parsing ---

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

  Scenario: Parse a feature with Background
    Given a Gherkin source
      """
      Feature: Background example

        Background:
          Given a common precondition
          And another common setup step

        Scenario: First scenario
          When an action
          Then a result

        Scenario: Second scenario
          When a different action
          Then a different result
      """
    When I call the parse function via the component
    Then the result should be ok
    And the parsed JSON should have a "feature" node
    And the parsed JSON feature should have a "Background" child
    And the parsed JSON feature should have 3 children

  Scenario: Parse a Scenario Outline with Examples
    Given a Gherkin source
      """
      Feature: Scenario Outline example

        Scenario Outline: Eating cucumbers
          Given there are <start> cucumbers
          When I eat <eat> cucumbers
          Then I should have <left> cucumbers

          Examples:
            | start | eat | left |
            |    12 |   5 |    7 |
            |    20 |   5 |   15 |
      """
    When I call the parse function via the component
    Then the result should be ok
    And the JSON should contain "Scenario Outline"
    And the JSON should contain "Examples"
    And the parsed JSON should have a "feature" node

  Scenario: Parse tags on feature and scenario
    Given a Gherkin source
      """
      @smoke @regression
      Feature: Tagged feature

        @wip
        Scenario: Tagged scenario
          Given something
          When action
          Then result
      """
    When I call the parse function via the component
    Then the result should be ok
    And the JSON should contain "@smoke"
    And the JSON should contain "@regression"
    And the JSON should contain "@wip"

  Scenario: Parse a step with a data table
    Given a Gherkin source
      """
      Feature: Data Tables

        Scenario: A step with a data table
          Given the following users exist:
            | name  | email          | role  |
            | Alice | alice@test.com | admin |
            | Bob   | bob@test.com   | user  |
          When I list all users
          Then I should see 2 users
      """
    When I call the parse function via the component
    Then the result should be ok
    And the JSON should contain "DataTable"
    And the JSON should contain "Alice"
    And the JSON should contain "alice@test.com"

  Scenario: Parse a step with a doc string
    Given a Gherkin source
      """
      Feature: Doc Strings

        Scenario: A step with a doc string
          Given the following text:
            ```
            This is a doc string.
            It can span multiple lines.
            ```
          When I process the text
          Then it should be captured
      """
    When I call the parse function via the component
    Then the result should be ok
    And the JSON should contain "DocString"
    And the JSON should contain "This is a doc string."

  Scenario: Parse comments
    Given a Gherkin source
      """
      # This is a file-level comment
      Feature: Comments
        # This is a feature-level comment

        # Pre-scenario comment
        Scenario: Commented scenario
          # Step comment
          Given something
          When action
          Then result
      """
    When I call the parse function via the component
    Then the result should be ok
    And the JSON should contain "Comment"
    And the JSON should contain "file-level comment"

  Scenario: Parse Gherkin 6 Rules
    Given a Gherkin source
      """
      Feature: Gherkin 6 Rules

        Rule: Business rule one
          Scenario: First rule scenario
            Given a context
            When an event
            Then an outcome

        Rule: Business rule two
          Scenario: Second rule scenario
            Given another context
            When another event
            Then another outcome
      """
    When I call the parse function via the component
    Then the result should be ok
    And the JSON should contain "Rule"
    And the JSON should contain "Business rule one"
    And the JSON should contain "Business rule two"

  Scenario: Parse multiple scenarios
    Given a Gherkin source
      """
      Feature: Multiple scenarios
        Scenario: First
          Given step one
        Scenario: Second
          Given step two
        Scenario: Third
          Given step three
      """
    When I call the parse function via the component
    Then the result should be ok
    And the parsed JSON should have a "feature" node
    And the parsed JSON feature should have 3 children

  Scenario: Parse feature with descriptions
    Given a Gherkin source
      """
      Feature: Descriptions
        As a developer,
        I want to use descriptions,
        So that features are self-documenting.

        Scenario: Described scenario
          Given something
      """
    When I call the parse function via the component
    Then the result should be ok
    And the JSON should contain "As a developer"

  Scenario: Parse i18n feature (French)
    Given a Gherkin source
      """
      # language: fr
      Fonctionnalité: Connexion

        Scénario: Succès
          Soit un utilisateur
      """
    When I call the parse function via the component
    Then the result should be ok
    And the JSON should contain "Fonctionnalit"
    And the JSON should contain "fr"

  Scenario: Parse complex feature with rules, tags, and background
    Given a Gherkin source
      """
      @integration
      Feature: Complex feature
        Background:
          Given a base setup

        Rule: Admin access
          @admin
          Scenario: Admin can manage
            Given an admin user
            When they access management
            Then they see the admin panel

        Rule: User access
          Scenario Outline: User permissions
            Given a <role> user
            When they access <page>
            Then they see <result>
            Examples:
              | role  | page    | result       |
              | user  | home    | dashboard    |
              | guest | home    | login prompt |
      """
    When I call the parse function via the component
    Then the result should be ok
    And the JSON should contain "@integration"
    And the JSON should contain "@admin"
    And the JSON should contain "Rule"
    And the JSON should contain "Background"
    And the JSON should contain "Scenario Outline"
    And the JSON should contain "Examples"

  # --- Parser: error handling ---

  Scenario: Parse returns error for invalid input
    Given a Gherkin source
      """
      not a valid feature file
      """
    When I call the parse function via the component
    Then the result should be an error
    And the error should contain "expected"

  Scenario: Parse returns error for missing Feature keyword
    Given a Gherkin source
      """
      Scenario: Orphan scenario
        Given something
      """
    When I call the parse function via the component
    Then the result should be an error
    And the error should contain "Feature"

  Scenario: Parse empty input returns document with no feature
    Given a Gherkin source
      """
      """
    When I call the parse function via the component
    Then the result should be ok
    And the JSON should contain "source"

  # --- Tokenizer ---

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

  Scenario: Tokenize a feature with all constructs
    Given a Gherkin source
      """
      @smoke
      Feature: Full
        Background:
          Given setup

        Scenario Outline: Template
          Given <input>
          Examples:
            | input |
            | foo   |
      """
    When I call the tokenize function via the component
    Then the result should be ok
    And the JSON should contain "TagLine"
    And the JSON should contain "FeatureLine"
    And the JSON should contain "BackgroundLine"
    And the JSON should contain "ScenarioLine"
    And the JSON should contain "StepLine"
    And the JSON should contain "ExamplesLine"
    And the JSON should contain "TableRow"

  Scenario: Tokenize a feature with data table
    Given a Gherkin source
      """
      Feature: Tables
        Scenario: With table
          Given users:
            | name  | age |
            | Alice | 30  |
      """
    When I call the tokenize function via the component
    Then the result should be ok
    And the JSON should contain "TableRow"
    And the JSON should contain "Alice"

  Scenario: Tokenize a feature with doc string
    Given a Gherkin source
      """
      Feature: DocStr
        Scenario: With doc
          Given a body:
            ```json
            {"key": "value"}
            ```
      """
    When I call the tokenize function via the component
    Then the result should be ok
    And the JSON should contain "DocString"

  Scenario: Tokenize a feature with comments
    Given a Gherkin source
      """
      # File comment
      Feature: Commented
        # Inline comment
        Scenario: Test
          Given a step
      """
    When I call the tokenize function via the component
    Then the result should be ok
    And the JSON should contain "Comment"
    And the JSON should contain "File comment"

  # --- Writer ---

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

  Scenario: Write round-trip preserves tags and background
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

  Scenario: Write round-trip preserves data tables
    Given a Gherkin source
      """
      Feature: Tables
        Scenario: With table
          Given users:
            | name  | age |
            | Alice | 30  |
      """
    When I call the parse function via the component
    And I call the write function with the parsed JSON
    Then the write result should be ok
    And the written output should contain "| name"
    And the written output should contain "| Alice"

  Scenario: Write round-trip preserves doc strings
    Given a Gherkin source
      """
      Feature: DocStr
        Scenario: With doc
          Given a body:
            ```
            Some content here
            ```
      """
    When I call the parse function via the component
    And I call the write function with the parsed JSON
    Then the write result should be ok
    And the written output should contain "Some content here"

  Scenario: Write round-trip preserves rules
    Given a Gherkin source
      """
      Feature: Rules
        Rule: First rule
          Scenario: In rule
            Given a step

        Rule: Second rule
          Scenario: In other rule
            Given another step
      """
    When I call the parse function via the component
    And I call the write function with the parsed JSON
    Then the write result should be ok
    And the written output should contain "Rule: First rule"
    And the written output should contain "Rule: Second rule"

  Scenario: Write round-trip preserves scenario outlines
    Given a Gherkin source
      """
      Feature: Outlines
        Scenario Outline: Template
          Given <input>
          Then <output>

          Examples:
            | input | output |
            | foo   | bar    |
      """
    When I call the parse function via the component
    And I call the write function with the parsed JSON
    Then the write result should be ok
    And the written output should contain "Scenario Outline: Template"
    And the written output should contain "Examples:"
    And the written output should contain "| input"

  Scenario: Write returns error for invalid JSON
    Given an invalid JSON string "{not valid json"
    When I call the write function with the invalid JSON
    Then the write result should be an error

  # --- Core WASM module validation ---

  Scenario: Core WASM module has expected exports
    Then the core WASM module should have a "memory" export
    And the core WASM module should have a "cabi_realloc" export
    And the core WASM module should have a parse function export
    And the core WASM module should have a tokenize function export
    And the core WASM module should have a write function export
