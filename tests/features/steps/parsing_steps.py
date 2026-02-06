"""Step definitions for parsing Gherkin fixtures."""

import os
import tempfile
from behave import given, when, then


@given('a Gherkin file "{filename}"')
def step_given_gherkin_file(context, filename):
    """Locate a fixture file by name."""
    filepath = os.path.join(context.fixtures_dir, filename)
    assert os.path.isfile(filepath), f"Fixture not found: {filepath}"
    context.input_file = filepath


@given("a Gherkin input")
def step_given_gherkin_input_text(context):
    """Use inline text from the step as parser input."""
    fd, path = tempfile.mkstemp(suffix=".feature", prefix="behave_input_")
    with os.fdopen(fd, "w") as f:
        f.write(context.text)
    context.input_file = path
    if not hasattr(context, "_temp_files"):
        context._temp_files = []
    context._temp_files.append(path)


@when("I parse the file")
def step_when_parse_file(context):
    """Invoke the parser against the current input file."""
    from environment import run_parser

    assert context.input_file, "No input file set"
    run_parser(context, context.input_file)


@when('I parse the file with format "{fmt}"')
def step_when_parse_file_with_format(context, fmt):
    """Invoke the parser with a specific output format."""
    from environment import run_parser

    assert context.input_file, "No input file set"
    run_parser(context, context.input_file, "--format", fmt)


@then("the parser should succeed")
def step_then_parser_succeeds(context):
    """Assert the parser exited with code 0."""
    assert context.parser_returncode == 0, (
        f"Parser failed (exit {context.parser_returncode}):\n"
        f"stderr: {context.parser_stderr}"
    )


@then("the parser should fail")
def step_then_parser_fails(context):
    """Assert the parser exited with a non-zero code."""
    assert context.parser_returncode != 0, (
        "Parser succeeded but was expected to fail"
    )
