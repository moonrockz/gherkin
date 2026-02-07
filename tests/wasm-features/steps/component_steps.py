"""Step definitions for WASM component BDD tests."""

import json
from behave import given, when, then


PARSER_IFACE = "moonrockz:gherkin/parser@0.1.0"
TOKENIZER_IFACE = "moonrockz:gherkin/tokenizer@0.1.0"
WRITER_IFACE = "moonrockz:gherkin/writer@0.1.0"


@given("a Gherkin source")
def step_given_gherkin_source(context):
    context.source = context.text


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


@then('the written output should contain "{text}"')
def step_then_written_contains(context, text):
    payload = context.write_result.payload
    assert text in payload, (
        f"Expected written output to contain '{text}', got: {payload[:500]}"
    )
