"""Step definitions for validating parser output."""

import json
from behave import then


@then("the output should be valid JSON")
def step_then_output_valid_json(context):
    """Assert the parser output is valid JSON."""
    try:
        context.parsed_json = json.loads(context.parser_output)
    except json.JSONDecodeError as e:
        raise AssertionError(
            f"Parser output is not valid JSON: {e}\n"
            f"Output was: {context.parser_output[:500]}"
        )


@then('the output should contain a "{node_type}" node')
def step_then_output_contains_node(context, node_type):
    """Assert the JSON output contains a node of the given type."""
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    # Special case: "Comment" nodes are in a top-level "comments" array
    if node_type == "Comment":
        comments = context.parsed_json.get("comments", [])
        assert len(comments) > 0, "No Comment nodes found in output"
        return
    assert _find_node(context.parsed_json, node_type), (
        f"No '{node_type}' node found in output"
    )


@then('the output should contain keyword "{keyword}"')
def step_then_output_contains_keyword(context, keyword):
    """Assert the raw output contains the given keyword string."""
    assert keyword in context.parser_output, (
        f"Keyword '{keyword}' not found in output:\n"
        f"{context.parser_output[:500]}"
    )


@then("the output should contain {count:d} scenario(s)")
def step_then_output_contains_n_scenarios(context, count):
    """Assert the output contains exactly N scenarios."""
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    scenarios = _find_all_nodes(context.parsed_json, "Scenario")
    assert len(scenarios) == count, (
        f"Expected {count} scenarios, found {len(scenarios)}"
    )


@then("the feature description should not be empty")
def step_then_feature_description_not_empty(context):
    """Assert the feature has a non-empty description."""
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    feature = context.parsed_json.get("feature", {})
    desc = feature.get("description", "")
    assert desc.strip(), f"Feature description is empty"


@then('the error should mention "{text}"')
def step_then_error_mentions(context, text):
    """Accept the CLI's stdout fallback when stderr cannot be opened."""
    error_output = context.parser_stderr or context.parser_output
    assert text in error_output, (
        f"Expected '{text}' in parser output:\n{error_output[:500]}"
    )


@then('the scenario should have tag "{tag}"')
def step_then_scenario_has_tag(context, tag):
    """Assert a parsed scenario owns a tag, excluding raw source text."""
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    scenarios = _find_all_nodes(context.parsed_json["feature"]["children"], "Scenario")
    assert any(tag == item["name"] for scenario in scenarios for item in scenario["tags"]), (
        f"No parsed scenario has tag {tag}"
    )


@then("the data table should have {count:d} rows")
def step_then_data_table_rows(context, count):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    table = _find_node(context.parsed_json["feature"]["children"], "DataTable")
    assert table is not None, "No parsed data table"
    assert len(table["rows"]) == count, table


@then('the data table should contain cell "{value}"')
def step_then_data_table_cell(context, value):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    table = _find_node(context.parsed_json["feature"]["children"], "DataTable")
    assert table is not None, "No parsed data table"
    assert any(cell["value"] == value for row in table["rows"] for cell in row["cells"]), table


@then("the examples table should have {count:d} row")
@then("the examples table should have {count:d} rows")
def step_then_examples_table_rows(context, count):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    examples = _find_node(context.parsed_json["feature"]["children"], "Examples")
    assert examples is not None, "No parsed examples"
    assert len(examples["table_body"]) == count, examples


@then('the feature name should be "{name}"')
def step_then_feature_name(context, name):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    assert context.parsed_json["feature"]["name"] == name


@then("the scenario should have {count:d} step")
@then("the scenario should have {count:d} steps")
def step_then_scenario_steps(context, count):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    scenario = _find_node(context.parsed_json["feature"]["children"], "Scenario")
    assert scenario is not None, "No parsed scenario"
    assert len(scenario["steps"]) == count, scenario


@then("the feature description should be empty")
def step_then_feature_description_empty(context):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    assert context.parsed_json["feature"]["description"] == ""


@then("the doc string content should be '{content}'")
def step_then_doc_string_content(context, content):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    doc_string = _find_node(context.parsed_json["feature"]["children"], "DocString")
    assert doc_string is not None, "No parsed doc string"
    assert doc_string["content"] == content, doc_string


@then('the rule name should be "{name}"')
def step_then_rule_name(context, name):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    rule = _find_node(context.parsed_json["feature"]["children"], "Rule")
    assert rule is not None, "No parsed rule"
    assert rule["name"] == name, rule


@then('the scenario outline name should be "{name}"')
def step_then_scenario_outline_name(context, name):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    outline = _find_node(context.parsed_json["feature"]["children"], "ScenarioOutline")
    assert outline is not None, "No parsed scenario outline"
    assert outline["name"] == name, outline


@then('the examples table should contain row "{values}"')
def step_then_examples_row(context, values):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    examples = _find_node(context.parsed_json["feature"]["children"], "Examples")
    assert examples is not None, "No parsed examples"
    expected = values.split(",")
    assert any([cell["value"] for cell in row["cells"]] == expected
               for row in examples["table_body"]), examples


@then('the scenario name should be "{name}"')
def step_then_scenario_name(context, name):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    scenario = _find_node(context.parsed_json["feature"]["children"], "Scenario")
    assert scenario is not None, "No parsed scenario"
    assert scenario["name"] == name, scenario


@then("the scenario steps should be:")
def step_then_scenario_steps_match(context):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    scenario = _find_node(context.parsed_json["feature"]["children"], "Scenario")
    assert scenario is not None, "No parsed scenario"
    actual = [(step["keyword"].strip(), step["text"])
              for step in scenario["steps"]]
    expected = [(row["keyword"], row["text"]) for row in context.table]
    assert actual == expected, (actual, expected)


@then('the feature should have tag "{tag}"')
def step_then_feature_has_tag(context, tag):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    assert tag in [item["name"] for item in context.parsed_json["feature"]["tags"]]


@then("the background should have {count:d} step")
def step_then_background_steps(context, count):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    background = _find_node(context.parsed_json["feature"]["children"], "Background")
    assert background is not None, "No parsed background"
    assert len(background["steps"]) == count, background


@then("the scenario should have no data table")
def step_then_scenario_has_no_data_table(context):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    scenario = _find_node(context.parsed_json["feature"]["children"], "Scenario")
    assert scenario is not None, "No parsed scenario"
    assert all("argument" not in step or step["argument"][0] != "DataTable"
               for step in scenario["steps"]), scenario


@then('the doc string media type should be "{media_type}"')
def step_then_doc_string_media_type(context, media_type):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    doc_string = _find_node(context.parsed_json["feature"]["children"], "DocString")
    assert doc_string is not None, "No parsed doc string"
    assert doc_string["media_type"] == media_type, doc_string


@then('the doc string delimiter should be "{delimiter}"')
def step_then_doc_string_delimiter(context, delimiter):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    doc_string = _find_node(context.parsed_json["feature"]["children"], "DocString")
    assert doc_string is not None, "No parsed doc string"
    assert doc_string["delimiter"] == delimiter, doc_string


@then("the scenario should start at line {line:d} column {column:d}")
def step_then_scenario_location(context, line, column):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    scenario = _find_node(context.parsed_json["feature"]["children"], "Scenario")
    assert scenario is not None, "No parsed scenario"
    assert scenario["location"] == {"line": line, "column": column}, scenario


@then("the first step should start at line {line:d} column {column:d}")
def step_then_first_step_location(context, line, column):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    scenario = _find_node(context.parsed_json["feature"]["children"], "Scenario")
    assert scenario is not None, "No parsed scenario"
    assert scenario["steps"], "No parsed steps"
    assert scenario["steps"][0]["location"] == {"line": line, "column": column}, scenario


@then("the doc string should start at line {line:d} column {column:d}")
def step_then_doc_string_location(context, line, column):
    if not hasattr(context, "parsed_json"):
        context.parsed_json = json.loads(context.parser_output)
    doc_string = _find_node(context.parsed_json["feature"]["children"], "DocString")
    assert doc_string is not None, "No parsed doc string"
    assert doc_string["location"] == {"line": line, "column": column}, doc_string


def _matches_node(data, node_type):
    """Check if a dict matches the given node type.

    MoonBit's derive(ToJson) produces:
    - Enum variants as ["VariantName", {...}] arrays
    - Structs with "keyword" and/or "kind" fields
    """
    if isinstance(data, dict):
        if data.get("keyword") == node_type:
            return True
        if data.get("kind") == node_type:
            return True
    return False


def _is_tagged_array(data):
    """Check if data is a MoonBit enum variant: ["Tag", {...}]."""
    return (isinstance(data, list) and len(data) == 2
            and isinstance(data[0], str) and isinstance(data[1], dict))


def _find_node(data, node_type):
    """Recursively search for a node matching the type.

    Handles MoonBit's ToJson format where enum variants are
    serialized as ["VariantName", {...}] arrays, and structs
    use "keyword" or "kind" fields for type identification.
    """
    if isinstance(data, dict):
        if _matches_node(data, node_type):
            return data
        for value in data.values():
            found = _find_node(value, node_type)
            if found:
                return found
    elif isinstance(data, list):
        if _is_tagged_array(data):
            if data[0] == node_type:
                return data[1]
            if _matches_node(data[1], node_type):
                return data[1]
            return _find_node(data[1], node_type)
        for item in data:
            found = _find_node(item, node_type)
            if found:
                return found
    return None


def _find_all_nodes(data, node_type):
    """Recursively collect all nodes matching a type."""
    results = []
    if isinstance(data, dict):
        if _matches_node(data, node_type):
            results.append(data)
        for value in data.values():
            results.extend(_find_all_nodes(value, node_type))
    elif isinstance(data, list):
        if _is_tagged_array(data):
            matched = (data[0] == node_type
                       or _matches_node(data[1], node_type))
            if matched:
                results.append(data[1])
            # Recurse into payload's values (not payload itself)
            # to find nested nodes without re-matching the payload
            for value in data[1].values():
                results.extend(_find_all_nodes(value, node_type))
        else:
            for item in data:
                results.extend(_find_all_nodes(item, node_type))
    return results
