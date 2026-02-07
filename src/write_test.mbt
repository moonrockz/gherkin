// ==========================================================================
// DOM-based write() tests
// ==========================================================================

///|
test "write: empty document" {
  let doc = GherkinDocument::empty()
  inspect(write(doc), content="")
}

///|
test "write: feature with no children" {
  let doc = parse(Source::from_string("Feature: Empty feature"))
  let expected =
    #|Feature: Empty feature
    #|
  inspect(write(doc), content=expected)
}

///|
test "write: feature with scenario and steps" {
  let input =
    #|Feature: Login
    #|  Scenario: Successful login
    #|    Given a registered user
    #|    When they enter valid credentials
    #|    Then they see the dashboard
  let expected =
    #|Feature: Login
    #|
    #|  Scenario: Successful login
    #|    Given a registered user
    #|    When they enter valid credentials
    #|    Then they see the dashboard
    #|
  inspect(write(parse(Source::from_string(input))), content=expected)
}

///|
test "write: multiple scenarios separated by blank lines" {
  let input =
    #|Feature: Multi
    #|  Scenario: First
    #|    Given a
    #|  Scenario: Second
    #|    Given b
  let expected =
    #|Feature: Multi
    #|
    #|  Scenario: First
    #|    Given a
    #|
    #|  Scenario: Second
    #|    Given b
    #|
  inspect(write(parse(Source::from_string(input))), content=expected)
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
  let expected =
    #|Feature: Tables
    #|
    #|  Scenario: Data
    #|    Given users:
    #|      | name  | email          |
    #|      | Alice | alice@test.com |
    #|      | Bob   | bob@test.com   |
    #|
  inspect(write(parse(Source::from_string(input))), content=expected)
}

///|
test "write: data table with empty cells" {
  let input =
    #|Feature: Empty cells
    #|  Scenario: Gaps
    #|    Given a table:
    #|      | a |   |
    #|      |   | b |
  let expected =
    #|Feature: Empty cells
    #|
    #|  Scenario: Gaps
    #|    Given a table:
    #|      | a |   |
    #|      |   | b |
    #|
  inspect(write(parse(Source::from_string(input))), content=expected)
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
  let expected =
    #|Feature: DocStrings
    #|
    #|  Scenario: Body
    #|    Given a body:
    #|      """
    #|      Hello
    #|      World
    #|      """
    #|
  inspect(write(parse(Source::from_string(input))), content=expected)
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
  let expected =
    #|Feature: Payloads
    #|
    #|  Scenario: JSON body
    #|    Given a request body:
    #|      ```json
    #|      {"key": "value"}
    #|      ```
    #|
  inspect(write(parse(Source::from_string(input))), content=expected)
}

///|
test "write: feature tags" {
  let input =
    #|@smoke @regression
    #|Feature: Tagged
    #|  Scenario: Test
    #|    Given a step
  let expected =
    #|@smoke @regression
    #|Feature: Tagged
    #|
    #|  Scenario: Test
    #|    Given a step
    #|
  inspect(write(parse(Source::from_string(input))), content=expected)
}

///|
test "write: scenario tags" {
  let input =
    #|Feature: Tags
    #|  @wip @critical
    #|  Scenario: Important
    #|    Given a step
  let expected =
    #|Feature: Tags
    #|
    #|  @wip @critical
    #|  Scenario: Important
    #|    Given a step
    #|
  inspect(write(parse(Source::from_string(input))), content=expected)
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
  let expected =
    #|Feature: With background
    #|
    #|  Background:
    #|    Given a common setup
    #|    And another setup step
    #|
    #|  Scenario: First
    #|    When an action
    #|    Then a result
    #|
  inspect(write(parse(Source::from_string(input))), content=expected)
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
  let expected =
    #|Feature: Business rules
    #|
    #|  Rule: First rule
    #|
    #|    Scenario: Rule scenario one
    #|      Given context
    #|
    #|  Rule: Second rule
    #|
    #|    Scenario: Rule scenario two
    #|      Given different context
    #|
  inspect(write(parse(Source::from_string(input))), content=expected)
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
  let expected =
    #|Feature: Outlines
    #|
    #|  Scenario Outline: Eating
    #|    Given there are <start> cucumbers
    #|    When I eat <eat> cucumbers
    #|    Then I should have <left> cucumbers
    #|
    #|    Examples:
    #|      | start | eat | left |
    #|      | 12    | 5   | 7    |
    #|      | 20    | 5   | 15   |
    #|
  inspect(write(parse(Source::from_string(input))), content=expected)
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
  let expected =
    #|Feature: Login
    #|  As a user
    #|  I want to login
    #|  So that I can access my account
    #|
    #|  Scenario: Success
    #|    Given a user
    #|
  inspect(write(parse(Source::from_string(input))), content=expected)
}

///|
test "write: comments before feature" {
  let input =
    #|# This is a comment
    #|Feature: Commented
    #|  Scenario: Test
    #|    Given a step
  let expected =
    #|# This is a comment
    #|Feature: Commented
    #|
    #|  Scenario: Test
    #|    Given a step
    #|
  inspect(write(parse(Source::from_string(input))), content=expected)
}

///|
test "write: French i18n with language directive" {
  let input =
    #|# language: fr
    #|Fonctionnalité: Connexion
    #|  Scénario: Succès
    #|    Soit un utilisateur
  let expected =
    #|# language: fr
    #|Fonctionnalité: Connexion
    #|
    #|  Scénario: Succès
    #|    Soit un utilisateur
    #|
  inspect(write(parse(Source::from_string(input))), content=expected)
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
  let doc1 = parse(Source::from_string(input))
  let output = write(doc1)
  let doc2 = parse(Source::from_string(output))
  let f1 = doc1.feature.unwrap()
  let f2 = doc2.feature.unwrap()
  inspect(f1.name, content="Round trip")
  inspect(f2.name, content="Round trip")
  guard f1.children[0] is Scenario(s1)
  guard f2.children[0] is Scenario(s2)
  inspect(s1.steps.length(), content="3")
  inspect(s2.steps.length(), content="3")
  inspect(s1.steps[0].text, content="a step")
  inspect(s2.steps[0].text, content="a step")
}

///|
test "write: round-trip preserves table data" {
  let input =
    #|Feature: Tables
    #|  Scenario: Data
    #|    Given users:
    #|      | name  | age |
    #|      | Alice | 30  |
  let doc1 = parse(Source::from_string(input))
  let output = write(doc1)
  let doc2 = parse(Source::from_string(output))
  guard doc1.feature.unwrap().children[0] is Scenario(s1)
  guard doc2.feature.unwrap().children[0] is Scenario(s2)
  guard s1.steps[0].argument is Some(DataTable(t1))
  guard s2.steps[0].argument is Some(DataTable(t2))
  inspect(t1.rows[1].cells[0].value, content="Alice")
  inspect(t2.rows[1].cells[0].value, content="Alice")
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
  let config : WriteConfig = { ..WriteConfig::default(), indent: "    " }
  let expected =
    #|Feature: Indented
    #|
    #|    Scenario: Test
    #|        Given a step
    #|
  inspect(write(parse(Source::from_string(input)), config~), content=expected)
}

///|
test "write: no trailing newline" {
  let config : WriteConfig = {
    ..WriteConfig::default(),
    trailing_newline: false,
  }
  let doc = parse(Source::from_string("Feature: No trail"))
  inspect(write(doc, config~), content="Feature: No trail")
}

///|
test "write: zero table cell padding" {
  let input =
    #|Feature: Tight
    #|  Scenario: Compact
    #|    Given a table:
    #|      | a | b |
    #|      | 1 | 2 |
  let config : WriteConfig = { ..WriteConfig::default(), table_cell_padding: 0 }
  let expected =
    #|Feature: Tight
    #|
    #|  Scenario: Compact
    #|    Given a table:
    #|      |a|b|
    #|      |1|2|
    #|
  inspect(write(parse(Source::from_string(input)), config~), content=expected)
}

///|
test "write: comments excluded via config" {
  let input =
    #|# A comment
    #|Feature: NoComments
    #|  Scenario: Test
    #|    Given a step
  let config : WriteConfig = {
    ..WriteConfig::default(),
    include_comments: false,
  }
  let expected =
    #|Feature: NoComments
    #|
    #|  Scenario: Test
    #|    Given a step
    #|
  inspect(write(parse(Source::from_string(input)), config~), content=expected)
}

// ==========================================================================
// Streaming GherkinWriter tests
// ==========================================================================

///|
test "GherkinWriter: build simple feature" {
  let w = GherkinWriter::new()
  w.feature("Feature", "Login")
  w.scenario("Scenario", "Success")
  w.step("Given ", "a user")
  w.step("When ", "they log in")
  w.step("Then ", "they see the dashboard")
  w.end_scenario()
  w.end_feature()
  let expected =
    #|Feature: Login
    #|
    #|  Scenario: Success
    #|    Given a user
    #|    When they log in
    #|    Then they see the dashboard
    #|
  inspect(w.to_string(), content=expected)
}

///|
test "GherkinWriter: build with tags" {
  let w = GherkinWriter::new()
  w.tags(["@smoke", "@regression"])
  w.feature("Feature", "Tagged")
  w.tags(["@wip"])
  w.scenario("Scenario", "Important")
  w.step("Given ", "a step")
  w.end_scenario()
  w.end_feature()
  let expected =
    #|@smoke @regression
    #|Feature: Tagged
    #|
    #|  @wip
    #|  Scenario: Important
    #|    Given a step
    #|
  inspect(w.to_string(), content=expected)
}

///|
test "GherkinWriter: build with data table" {
  let w = GherkinWriter::new()
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
  let expected =
    #|Feature: Tables
    #|
    #|  Scenario: Data
    #|    Given users:
    #|      | name  | email          |
    #|      | Alice | alice@test.com |
    #|      | Bob   | bob@test.com   |
    #|
  inspect(w.to_string(), content=expected)
}

///|
test "GherkinWriter: build with doc string" {
  let w = GherkinWriter::new()
  w.feature("Feature", "DocStrings")
  w.scenario("Scenario", "Body")
  w.step("Given ", "a body:")
  w.doc_string("Hello\nWorld")
  w.end_scenario()
  w.end_feature()
  let expected =
    #|Feature: DocStrings
    #|
    #|  Scenario: Body
    #|    Given a body:
    #|      """
    #|      Hello
    #|      World
    #|      """
    #|
  inspect(w.to_string(), content=expected)
}

///|
test "GherkinWriter: build with examples" {
  let w = GherkinWriter::new()
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
  let expected =
    #|Feature: Outlines
    #|
    #|  Scenario Outline: Eating
    #|    Given there are <start> cucumbers
    #|    When I eat <eat> cucumbers
    #|
    #|    Examples:
    #|      | start | eat | left |
    #|      | 12    | 5   | 7    |
    #|      | 20    | 5   | 15   |
    #|
  inspect(w.to_string(), content=expected)
}

///|
test "GherkinWriter: build with description" {
  let w = GherkinWriter::new()
  w.feature("Feature", "Login", description="As a user\nI want to login")
  w.scenario("Scenario", "Success")
  w.step("Given ", "a user")
  w.end_scenario()
  w.end_feature()
  let expected =
    #|Feature: Login
    #|  As a user
    #|  I want to login
    #|
    #|  Scenario: Success
    #|    Given a user
    #|
  inspect(w.to_string(), content=expected)
}

///|
test "GherkinWriter: build French feature" {
  let w = GherkinWriter::new()
  w.feature("Fonctionnalité", "Connexion", language="fr")
  w.scenario("Scénario", "Succès")
  w.step("Soit ", "un utilisateur")
  w.end_scenario()
  w.end_feature()
  let expected =
    #|# language: fr
    #|Fonctionnalité: Connexion
    #|
    #|  Scénario: Succès
    #|    Soit un utilisateur
    #|
  inspect(w.to_string(), content=expected)
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
  let w = GherkinWriter::new()
  parse_with_handler(Source::from_string(input), w)
  let doc = parse(Source::from_string(w.to_string()))
  let feature = doc.feature.unwrap()
  inspect(feature.name, content="Handler round-trip")
  guard feature.children[0] is Scenario(s)
  inspect(s.steps.length(), content="3")
}

///|
test "GherkinWriter: handler round-trip preserves tables" {
  let input =
    #|Feature: Tables
    #|  Scenario: Data
    #|    Given users:
    #|      | name  | age |
    #|      | Alice | 30  |
  let w = GherkinWriter::new()
  parse_with_handler(Source::from_string(input), w)
  let doc = parse(Source::from_string(w.to_string()))
  guard doc.feature.unwrap().children[0] is Scenario(s)
  guard s.steps[0].argument is Some(DataTable(t))
  inspect(t.rows[1].cells[0].value, content="Alice")
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
  let w = GherkinWriter::new()
  parse_with_handler(Source::from_string(input), w)
  let doc = parse(Source::from_string(w.to_string()))
  guard doc.feature.unwrap().children[0] is Scenario(s)
  guard s.steps[0].argument is Some(DocString(ds))
  inspect(ds.media_type, content="Some(\"json\")")
  assert_true(ds.content.contains("key"))
}
