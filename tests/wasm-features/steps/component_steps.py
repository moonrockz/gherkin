"""Step definitions for WASM component BDD tests."""

import json
from behave import given, when, then


PARSER_IFACE = "moonrockz:gherkin/parser@0.1.0"
TOKENIZER_IFACE = "moonrockz:gherkin/tokenizer@0.1.0"
WRITER_IFACE = "moonrockz:gherkin/writer@0.1.0"


@given("a Gherkin source")
def step_given_gherkin_source(context):
    context.source = context.text


@given('an invalid JSON string "{text}"')
def step_given_invalid_json(context, text):
    context.invalid_json = text


@when("I call the parse function via the component")
def step_when_parse(context):
    store, instance = context.make_instance()
    func = context.get_func(instance, store, PARSER_IFACE, "parse")
    context.result = func(store, context.source)


@when("I call the tokenize function via the component")
def step_when_tokenize(context):
    store, instance = context.make_instance()
    func = context.get_func(instance, store, TOKENIZER_IFACE, "tokenize")
    context.result = func(store, context.source)


@when("I call the write function with the parsed JSON")
def step_when_write(context):
    assert context.result.tag == "ok", f"Parse failed: {context.result.payload}"
    store, instance = context.make_instance()
    func = context.get_func(instance, store, WRITER_IFACE, "write")
    context.write_result = func(store, context.result.payload)


@when("I call the write function with the invalid JSON")
def step_when_write_invalid(context):
    store, instance = context.make_instance()
    func = context.get_func(instance, store, WRITER_IFACE, "write")
    context.write_result = func(store, context.invalid_json)


@then("the result should be ok")
def step_then_result_ok(context):
    assert context.result.tag == "ok", (
        f"Expected ok result, got error: {context.result.payload}"
    )


@then("the result should be an error")
def step_then_result_error(context):
    assert context.result.tag == "err", (
        f"Expected error result, got ok: {context.result.payload}"
    )


@then('the error should contain "{text}"')
def step_then_error_contains(context, text):
    assert text in context.result.payload, (
        f"Expected error to contain '{text}', got: {context.result.payload}"
    )


@then('the JSON should contain "{text}"')
def step_then_json_contains(context, text):
    payload = context.result.payload
    assert text in payload, (
        f"Expected JSON to contain '{text}', got: {payload[:500]}"
    )


@then("the write result should be ok")
def step_then_write_ok(context):
    assert context.write_result.tag == "ok", (
        f"Expected ok write result, got error: {context.write_result.payload}"
    )


@then("the write result should be an error")
def step_then_write_error(context):
    assert context.write_result.tag == "err", (
        f"Expected ok write result, got: {context.write_result.payload}"
    )


@then('the written output should contain "{text}"')
def step_then_written_contains(context, text):
    payload = context.write_result.payload
    assert text in payload, (
        f"Expected written output to contain '{text}', got: {payload[:500]}"
    )


# --- Structured JSON assertions ---


@then('the parsed JSON should have a "{key}" node')
def step_then_parsed_json_has_node(context, key):
    payload = context.result.payload
    doc = json.loads(payload)
    assert key in doc, (
        f"Expected JSON to have '{key}' node, got keys: {list(doc.keys())}"
    )
    assert doc[key] is not None, f"Expected '{key}' to be non-null"


@then('the parsed JSON feature should have a "{keyword}" child')
def step_then_feature_has_child(context, keyword):
    payload = context.result.payload
    doc = json.loads(payload)
    feature = doc.get("feature", {})
    children = feature.get("children", [])
    found = any(_child_has_keyword(child, keyword) for child in children)
    assert found, (
        f"Expected feature to have a '{keyword}' child, "
        f"got: {[_describe_child(c) for c in children]}"
    )


@then("the parsed JSON feature should have {count:d} children")
def step_then_feature_has_n_children(context, count):
    payload = context.result.payload
    doc = json.loads(payload)
    feature = doc.get("feature", {})
    children = feature.get("children", [])
    assert len(children) == count, (
        f"Expected {count} children, got {len(children)}: "
        f"{[_describe_child(c) for c in children]}"
    )


# --- Core WASM module validation ---


@then('the core WASM module should have a "{name}" export')
def step_then_core_has_export(context, name):
    exports = context.core_exports
    assert name in exports, (
        f"Expected core module to export '{name}', "
        f"got: {sorted(exports.keys())}"
    )


@then("the core WASM module should have a parse function export")
def step_then_core_has_parse(context):
    exports = context.core_exports
    found = any("parse" in name.lower() for name in exports)
    assert found, (
        f"Expected core module to have a parse export, "
        f"got: {sorted(exports.keys())}"
    )


@then("the core WASM module should have a tokenize function export")
def step_then_core_has_tokenize(context):
    exports = context.core_exports
    found = any("tokenize" in name.lower() for name in exports)
    assert found, (
        f"Expected core module to have a tokenize export, "
        f"got: {sorted(exports.keys())}"
    )


@then("the core WASM module should have a write function export")
def step_then_core_has_write(context):
    exports = context.core_exports
    found = any("write" in name.lower() for name in exports)
    assert found, (
        f"Expected core module to have a write export, "
        f"got: {sorted(exports.keys())}"
    )


# --- Helpers ---


def _child_has_keyword(child, keyword):
    """Check if a feature child node matches a keyword.

    Children are serialized as ["Tag", {...}] arrays (MoonBit enum tuples).
    """
    if isinstance(child, list) and len(child) >= 2:
        tag, node = child[0], child[1]
        if isinstance(node, dict) and node.get("keyword", "") == keyword:
            return True
    return False


def _describe_child(child):
    """Return a short description of a feature child for error messages."""
    if isinstance(child, list) and len(child) >= 2:
        tag, node = child[0], child[1]
        if isinstance(node, dict):
            return f"{node.get('keyword', tag)}: {node.get('name', '')}"
    return str(child)[:80]
