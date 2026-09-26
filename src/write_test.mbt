// ==========================================================================
// DOM-based write() tests
// ==========================================================================

///|
test "write: empty document" {
  let doc = @gherkin.GherkinDocument::empty()
  @debug.debug_inspect(
    @gherkin.write(doc),
    content=(
      #|""
    ),
  )
}

///|
test "write: feature with no children" {
  let doc = @gherkin.parse(
    @gherkin.Source::from_string("Feature: Empty feature"),
  )
  @debug.debug_inspect(
    @gherkin.write(doc),
    content=(
      #|"Feature: Empty feature\n"
    ),
  )
}

///|
test "write: feature with scenario and steps" {
  let input =
    #|Feature: Login
    #|  Scenario: Successful login
    #|    Given a registered user
    #|    When they enter valid credentials
    #|    Then they see the dashboard
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input))),
    content=(
      #|"Feature: Login\n\n  Scenario: Successful login\n    Given a registered user\n    When they enter valid credentials\n    Then they see the dashboard\n"
    ),
  )
}

///|
test "write: multiple scenarios separated by blank lines" {
  let input =
    #|Feature: Multi
    #|  Scenario: First
    #|    Given a
    #|  Scenario: Second
    #|    Given b
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input))),
    content=(
      #|"Feature: Multi\n\n  Scenario: First\n    Given a\n\n  Scenario: Second\n    Given b\n"
    ),
  )
}

///|
test "write: data table column alignment" {
  let input =
    #|Feature: Tables
    #|  Scenario: Data
    #|    Given users:
    #|      | name  | email          |
    #|      | Alice | alice@test.com |
    #|      | Bob   | bob@test.com   |
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input))),
    content=(
      #|"Feature: Tables\n\n  Scenario: Data\n    Given users:\n      | name  | email          |\n      | Alice | alice@test.com |\n      | Bob   | bob@test.com   |\n"
    ),
  )
}

///|
test "write: data table with empty cells" {
  let input =
    #|Feature: Empty cells
    #|  Scenario: Gaps
    #|    Given a table:
    #|      | a |   |
    #|      |   | b |
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input))),
    content=(
      #|"Feature: Empty cells\n\n  Scenario: Gaps\n    Given a table:\n      | a |   |\n      |   | b |\n"
    ),
  )
}

///|
test "write: doc string with triple-quote delimiter" {
  let input =
    #|Feature: DocStrings
    #|  Scenario: Body
    #|    Given a body:
    #|      """
    #|      Hello
    #|      World
    #|      """
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input))),
    content=(
      #|"Feature: DocStrings\n\n  Scenario: Body\n    Given a body:\n      \"\"\"\n      Hello\n      World\n      \"\"\"\n"
    ),
  )
}

///|
test "write: doc string with backtick delimiter and media type" {
  let input =
    #|Feature: Payloads
    #|  Scenario: JSON body
    #|    Given a request body:
    #|      ```json
    #|      {"key": "value"}
    #|      ```
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input))),
    content=(
      #|"Feature: Payloads\n\n  Scenario: JSON body\n    Given a request body:\n      ```json\n      {\"key\": \"value\"}\n      ```\n"
    ),
  )
}

///|
test "write: feature tags" {
  let input =
    #|@smoke @regression
    #|Feature: Tagged
    #|  Scenario: Test
    #|    Given a step
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input))),
    content=(
      #|"@smoke @regression\nFeature: Tagged\n\n  Scenario: Test\n    Given a step\n"
    ),
  )
}

///|
test "write: scenario tags" {
  let input =
    #|Feature: Tags
    #|  @wip @critical
    #|  Scenario: Important
    #|    Given a step
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input))),
    content=(
      #|"Feature: Tags\n\n  @wip @critical\n  Scenario: Important\n    Given a step\n"
    ),
  )
}

///|
test "write: background before scenarios" {
  let input =
    #|Feature: With background
    #|  Background:
    #|    Given a common setup
    #|    And another setup step
    #|  Scenario: First
    #|    When an action
    #|    Then a result
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input))),
    content=(
      #|"Feature: With background\n\n  Background:\n    Given a common setup\n    And another setup step\n\n  Scenario: First\n    When an action\n    Then a result\n"
    ),
  )
}

///|
test "write: rules with nested scenarios" {
  let input =
    #|Feature: Business rules
    #|  Rule: First rule
    #|    Scenario: Rule scenario one
    #|      Given context
    #|  Rule: Second rule
    #|    Scenario: Rule scenario two
    #|      Given different context
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input))),
    content=(
      #|"Feature: Business rules\n\n  Rule: First rule\n\n    Scenario: Rule scenario one\n      Given context\n\n  Rule: Second rule\n\n    Scenario: Rule scenario two\n      Given different context\n"
    ),
  )
}

///|
test "write: scenario outline with examples table" {
  let input =
    #|Feature: Outlines
    #|  Scenario Outline: Eating
    #|    Given there are <start> cucumbers
    #|    When I eat <eat> cucumbers
    #|    Then I should have <left> cucumbers
    #|    Examples:
    #|      | start | eat | left |
    #|      | 12    | 5   | 7    |
    #|      | 20    | 5   | 15   |
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input))),
    content=(
      #|"Feature: Outlines\n\n  Scenario Outline: Eating\n    Given there are <start> cucumbers\n    When I eat <eat> cucumbers\n    Then I should have <left> cucumbers\n\n    Examples:\n      | start | eat | left |\n      | 12    | 5   | 7    |\n      | 20    | 5   | 15   |\n"
    ),
  )
}

///|
test "write: feature with description" {
  let input =
    #|Feature: Login
    #|  As a user
    #|  I want to login
    #|  So that I can access my account
    #|
    #|  Scenario: Success
    #|    Given a user
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input))),
    content=(
      #|"Feature: Login\n  As a user\n  I want to login\n  So that I can access my account\n\n  Scenario: Success\n    Given a user\n"
    ),
  )
}

///|
test "write: comments before feature" {
  let input =
    #|# This is a comment
    #|Feature: Commented
    #|  Scenario: Test
    #|    Given a step
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input))),
    content=(
      #|"# This is a comment\nFeature: Commented\n\n  Scenario: Test\n    Given a step\n"
    ),
  )
}

///|
test "write: French i18n with language directive" {
  let input =
    #|# language: fr
    #|Fonctionnalité: Connexion
    #|  Scénario: Succès
    #|    Soit un utilisateur
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input))),
    content=(
      #|"# language: fr\nFonctionnalité: Connexion\n\n  Scénario: Succès\n    Soit un utilisateur\n"
    ),
  )
}

// --------------------------------------------------------------------------
// Round-trip tests (parse -> write -> parse -> compare)
// --------------------------------------------------------------------------

///|
test "write: round-trip preserves feature and step data" {
  let input =
    #|Feature: Round trip
    #|  Scenario: Basic
    #|    Given a step
    #|    When an action
    #|    Then a result
  let doc1 = @gherkin.parse(@gherkin.Source::from_string(input))
  let output = @gherkin.write(doc1)
  let doc2 = @gherkin.parse(@gherkin.Source::from_string(output))
  let f1 = doc1.feature.unwrap()
  let f2 = doc2.feature.unwrap()
  @debug.debug_inspect(
    f1.name,
    content=(
      #|"Round trip"
    ),
  )
  @debug.debug_inspect(
    f2.name,
    content=(
      #|"Round trip"
    ),
  )
  guard! f1.children[0] is Scenario(s1)
  guard! f2.children[0] is Scenario(s2)
  @debug.debug_inspect(s1.steps.length(), content="3")
  @debug.debug_inspect(s2.steps.length(), content="3")
  @debug.debug_inspect(
    s1.steps[0].text,
    content=(
      #|"a step"
    ),
  )
  @debug.debug_inspect(
    s2.steps[0].text,
    content=(
      #|"a step"
    ),
  )
}

///|
test "write: round-trip preserves table data" {
  let input =
    #|Feature: Tables
    #|  Scenario: Data
    #|    Given users:
    #|      | name  | age |
    #|      | Alice | 30  |
  let doc1 = @gherkin.parse(@gherkin.Source::from_string(input))
  let output = @gherkin.write(doc1)
  let doc2 = @gherkin.parse(@gherkin.Source::from_string(output))
  guard! doc1.feature.unwrap().children[0] is Scenario(s1)
  guard! doc2.feature.unwrap().children[0] is Scenario(s2)
  guard! s1.steps[0].argument is Some(DataTable(t1))
  guard! s2.steps[0].argument is Some(DataTable(t2))
  @debug.debug_inspect(
    t1.rows[1].cells[0].value,
    content=(
      #|"Alice"
    ),
  )
  @debug.debug_inspect(
    t2.rows[1].cells[0].value,
    content=(
      #|"Alice"
    ),
  )
}

// --------------------------------------------------------------------------
// WriteConfig customization tests
// --------------------------------------------------------------------------

///|
test "write: custom indent (4 spaces)" {
  let input =
    #|Feature: Indented
    #|  Scenario: Test
    #|    Given a step
  let config : @gherkin.WriteConfig = {
    ..@gherkin.WriteConfig::default(),
    indent: "    ",
  }
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input)), config~),
    content=(
      #|"Feature: Indented\n\n    Scenario: Test\n        Given a step\n"
    ),
  )
}

///|
test "write: no trailing newline" {
  let config : @gherkin.WriteConfig = {
    ..@gherkin.WriteConfig::default(),
    trailing_newline: false,
  }
  let doc = @gherkin.parse(@gherkin.Source::from_string("Feature: No trail"))
  @debug.debug_inspect(
    @gherkin.write(doc, config~),
    content=(
      #|"Feature: No trail"
    ),
  )
}

///|
test "write: zero table cell padding" {
  let input =
    #|Feature: Tight
    #|  Scenario: Compact
    #|    Given a table:
    #|      | a | b |
    #|      | 1 | 2 |
  let config : @gherkin.WriteConfig = {
    ..@gherkin.WriteConfig::default(),
    table_cell_padding: 0,
  }
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input)), config~),
    content=(
      #|"Feature: Tight\n\n  Scenario: Compact\n    Given a table:\n      |a|b|\n      |1|2|\n"
    ),
  )
}

///|
test "write: comments excluded via config" {
  let input =
    #|# A comment
    #|Feature: NoComments
    #|  Scenario: Test
    #|    Given a step
  let config : @gherkin.WriteConfig = {
    ..@gherkin.WriteConfig::default(),
    include_comments: false,
  }
  @debug.debug_inspect(
    @gherkin.write(@gherkin.parse(@gherkin.Source::from_string(input)), config~),
    content=(
      #|"Feature: NoComments\n\n  Scenario: Test\n    Given a step\n"
    ),
  )
}

// ==========================================================================
// Streaming GherkinWriter tests
// ==========================================================================

///|
test "GherkinWriter: build simple feature" {
  let w = @gherkin.GherkinWriter::new()
  w.feature("Feature", "Login")
  w.scenario("Scenario", "Success")
  w.step("Given ", "a user")
  w.step("When ", "they log in")
  w.step("Then ", "they see the dashboard")
  w.end_scenario()
  w.end_feature()
  @debug.debug_inspect(
    w.to_string(),
    content=(
      #|"Feature: Login\n\n  Scenario: Success\n    Given a user\n    When they log in\n    Then they see the dashboard\n"
    ),
  )
}

///|
test "GherkinWriter: build with tags" {
  let w = @gherkin.GherkinWriter::new()
  w.tags(["@smoke", "@regression"])
  w.feature("Feature", "Tagged")
  w.tags(["@wip"])
  w.scenario("Scenario", "Important")
  w.step("Given ", "a step")
  w.end_scenario()
  w.end_feature()
  @debug.debug_inspect(
    w.to_string(),
    content=(
      #|"@smoke @regression\nFeature: Tagged\n\n  @wip\n  Scenario: Important\n    Given a step\n"
    ),
  )
}

///|
test "GherkinWriter: build with data table" {
  let w = @gherkin.GherkinWriter::new()
  w.feature("Feature", "Tables")
  w.scenario("Scenario", "Data")
  w.step("Given ", "users:")
  w.data_table([
    ["name", "email"],
    ["Alice", "alice@test.com"],
    ["Bob", "bob@test.com"],
  ])
  w.end_scenario()
  w.end_feature()
  @debug.debug_inspect(
    w.to_string(),
    content=(
      #|"Feature: Tables\n\n  Scenario: Data\n    Given users:\n      | name  | email          |\n      | Alice | alice@test.com |\n      | Bob   | bob@test.com   |\n"
    ),
  )
}

///|
test "GherkinWriter: build with doc string" {
  let w = @gherkin.GherkinWriter::new()
  w.feature("Feature", "DocStrings")
  w.scenario("Scenario", "Body")
  w.step("Given ", "a body:")
  w.doc_string("Hello\nWorld")
  w.end_scenario()
  w.end_feature()
  @debug.debug_inspect(
    w.to_string(),
    content=(
      #|"Feature: DocStrings\n\n  Scenario: Body\n    Given a body:\n      \"\"\"\n      Hello\n      World\n      \"\"\"\n"
    ),
  )
}

///|
test "GherkinWriter: build with examples" {
  let w = @gherkin.GherkinWriter::new()
  w.feature("Feature", "Outlines")
  w.scenario("Scenario Outline", "Eating")
  w.step("Given ", "there are <start> cucumbers")
  w.step("When ", "I eat <eat> cucumbers")
  w.examples("Examples", header=["start", "eat", "left"], body=[
    ["12", "5", "7"],
    ["20", "5", "15"],
  ])
  w.end_scenario()
  w.end_feature()
  @debug.debug_inspect(
    w.to_string(),
    content=(
      #|"Feature: Outlines\n\n  Scenario Outline: Eating\n    Given there are <start> cucumbers\n    When I eat <eat> cucumbers\n\n    Examples:\n      | start | eat | left |\n      | 12    | 5   | 7    |\n      | 20    | 5   | 15   |\n"
    ),
  )
}

///|
test "GherkinWriter: build with description" {
  let w = @gherkin.GherkinWriter::new()
  w.feature("Feature", "Login", description="As a user\nI want to login")
  w.scenario("Scenario", "Success")
  w.step("Given ", "a user")
  w.end_scenario()
  w.end_feature()
  @debug.debug_inspect(
    w.to_string(),
    content=(
      #|"Feature: Login\n  As a user\n  I want to login\n\n  Scenario: Success\n    Given a user\n"
    ),
  )
}

///|
test "GherkinWriter: build French feature" {
  let w = @gherkin.GherkinWriter::new()
  w.feature("Fonctionnalité", "Connexion", language="fr")
  w.scenario("Scénario", "Succès")
  w.step("Soit ", "un utilisateur")
  w.end_scenario()
  w.end_feature()
  @debug.debug_inspect(
    w.to_string(),
    content=(
      #|"# language: fr\nFonctionnalité: Connexion\n\n  Scénario: Succès\n    Soit un utilisateur\n"
    ),
  )
}

// ==========================================================================
// Handler bridge tests (GherkinWriter as GherkinHandler)
// ==========================================================================

///|
test "GherkinWriter: round-trip via handler" {
  let input =
    #|Feature: Handler round-trip
    #|  Scenario: Basic
    #|    Given a step
    #|    When an action
    #|    Then a result
  let w = @gherkin.GherkinWriter::new()
  @gherkin.parse_with_handler(@gherkin.Source::from_string(input), w)
  let doc = @gherkin.parse(@gherkin.Source::from_string(w.to_string()))
  let feature = doc.feature.unwrap()
  @debug.debug_inspect(
    feature.name,
    content=(
      #|"Handler round-trip"
    ),
  )
  guard! feature.children[0] is Scenario(s)
  @debug.debug_inspect(s.steps.length(), content="3")
}

///|
test "GherkinWriter: handler round-trip preserves tables" {
  let input =
    #|Feature: Tables
    #|  Scenario: Data
    #|    Given users:
    #|      | name  | age |
    #|      | Alice | 30  |
  let w = @gherkin.GherkinWriter::new()
  @gherkin.parse_with_handler(@gherkin.Source::from_string(input), w)
  let doc = @gherkin.parse(@gherkin.Source::from_string(w.to_string()))
  guard! doc.feature.unwrap().children[0] is Scenario(s)
  guard! s.steps[0].argument is Some(DataTable(t))
  @debug.debug_inspect(
    t.rows[1].cells[0].value,
    content=(
      #|"Alice"
    ),
  )
}

///|
test "GherkinWriter: handler round-trip preserves doc strings" {
  let input =
    #|Feature: DocStrings
    #|  Scenario: Body
    #|    Given a body:
    #|      """json
    #|      {"key": "value"}
    #|      """
  let w = @gherkin.GherkinWriter::new()
  @gherkin.parse_with_handler(@gherkin.Source::from_string(input), w)
  let doc = @gherkin.parse(@gherkin.Source::from_string(w.to_string()))
  guard! doc.feature.unwrap().children[0] is Scenario(s)
  guard! s.steps[0].argument is Some(DocString(ds))
  @debug.debug_inspect(ds.media_type, content="Some(\"json\")")
  assert_true(ds.content.contains("key"))
}
