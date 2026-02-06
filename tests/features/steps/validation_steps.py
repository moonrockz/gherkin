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
    assert hasattr(context, "parsed_json"), "Output not parsed as JSON yet"
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
    assert hasattr(context, "parsed_json"), "Output not parsed as JSON yet"
    scenarios = _find_all_nodes(context.parsed_json, "Scenario")
    assert len(scenarios) == count, (
        f"Expected {count} scenarios, found {len(scenarios)}"
    )


@then('the error should mention "{text}"')
def step_then_error_mentions(context, text):
    """Assert the stderr contains expected error text."""
    assert text in context.parser_stderr, (
        f"Expected '{text}' in stderr:\n{context.parser_stderr[:500]}"
    )


def _find_node(data, node_type):
    """Recursively search for a node with a matching type field."""
    if isinstance(data, dict):
        if data.get("type") == node_type:
            return data
        for value in data.values():
            found = _find_node(value, node_type)
            if found:
                return found
    elif isinstance(data, list):
        for item in data:
            found = _find_node(item, node_type)
            if found:
                return found
    return None


def _find_all_nodes(data, node_type):
    """Recursively collect all nodes matching a type."""
    results = []
    if isinstance(data, dict):
        if data.get("type") == node_type:
            results.append(data)
        for value in data.values():
            results.extend(_find_all_nodes(value, node_type))
    elif isinstance(data, list):
        for item in data:
            results.extend(_find_all_nodes(item, node_type))
    return results
