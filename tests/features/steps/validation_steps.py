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
    """Assert the stderr contains expected error text."""
    assert text in context.parser_stderr, (
        f"Expected '{text}' in stderr:\n{context.parser_stderr[:500]}"
    )


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
