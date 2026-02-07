"""Step definitions for WASM component BDD tests with typed interfaces."""

from behave import given, when, then


# --- Given steps ---


@given("a Gherkin source")
def step_given_gherkin_source(context):
    context.source = context.text


# --- When steps ---


@when("I parse the source via the component")
def step_when_parse(context):
    store, instance = context.make_instance()
    func = context.get_func(instance, store, context.PARSER_IFACE, "parse")
    source = context.make_source(context.source)
    result = func(store, source)
    # result<gherkin-document, list<parse-error>>:
    #   ok  → Record with .feature, .comments, .source  (unwrapped)
    #   err → list of Record with .message, .line, .column (unwrapped)
    context.parse_result = result


@when("I tokenize the source via the component")
def step_when_tokenize(context):
    store, instance = context.make_instance()
    func = context.get_func(instance, store, context.TOKENIZER_IFACE, "tokenize")
    source = context.make_source(context.source)
    result = func(store, source)
    # result<list<token>, list<parse-error>>:
    #   Both ok and err are lists → wrapped in Variant with .tag/.payload
    context.tokenize_result = result


@when("I write the parsed document via the component")
def step_when_write(context):
    doc = context.parse_result
    assert hasattr(doc, "feature"), (
        f"Expected a parsed document, got: {type(doc).__name__}"
    )
    store, instance = context.make_instance()
    func = context.get_func(instance, store, context.WRITER_IFACE, "write")
    result = func(store, doc)
    # result<string, string>: wrapped in Variant with .tag/.payload
    context.write_result = result


# --- Then: parse result type ---


@then("the parse result should be a document")
def step_then_parse_is_document(context):
    result = context.parse_result
    assert hasattr(result, "feature"), (
        f"Expected a document Record with 'feature' field, got {type(result).__name__}: "
        f"{[a for a in dir(result) if not a.startswith('_')]}"
    )


@then("the parse result should be an error list")
def step_then_parse_is_error(context):
    result = context.parse_result
    assert isinstance(result, list), (
        f"Expected an error list, got {type(result).__name__}"
    )
    assert len(result) > 0, "Expected at least one parse error"


# --- Then: document structure ---


@then("the document should have a feature")
def step_then_doc_has_feature(context):
    doc = context.parse_result
    assert doc.feature is not None, "Expected document to have a feature, got None"


@then("the document should not have a feature")
def step_then_doc_no_feature(context):
    doc = context.parse_result
    assert doc.feature is None, (
        f"Expected document to have no feature, got: {doc.feature}"
    )


@then("the document should have comments")
def step_then_doc_has_comments(context):
    doc = context.parse_result
    assert len(doc.comments) > 0, "Expected document to have comments"


# --- Then: feature properties ---


@then('the feature name should be "{name}"')
def step_then_feature_name(context, name):
    feat = context.parse_result.feature
    assert feat.name == name, (
        f"Expected feature name '{name}', got '{feat.name}'"
    )


@then('the feature keyword should be "{keyword}"')
def step_then_feature_keyword(context, keyword):
    feat = context.parse_result.feature
    assert feat.keyword == keyword, (
        f"Expected feature keyword '{keyword}', got '{feat.keyword}'"
    )


@then('the feature language should be "{lang}"')
def step_then_feature_language(context, lang):
    feat = context.parse_result.feature
    assert feat.language == lang, (
        f"Expected feature language '{lang}', got '{feat.language}'"
    )


@then('the feature description should contain "{text}"')
def step_then_feature_description_contains(context, text):
    feat = context.parse_result.feature
    assert text in feat.description, (
        f"Expected feature description to contain '{text}', "
        f"got: '{feat.description[:200]}'"
    )


@then("the feature should have {count:d} children")
def step_then_feature_children_count(context, count):
    feat = context.parse_result.feature
    children = feat.children
    assert len(children) == count, (
        f"Expected {count} children, got {len(children)}: "
        f"{[c.tag for c in children]}"
    )


@then('the feature should have tags "{tags_csv}"')
def step_then_feature_tags(context, tags_csv):
    feat = context.parse_result.feature
    expected = [t.strip() for t in tags_csv.split(",")]
    actual = [t.name for t in feat.tags]
    assert actual == expected, (
        f"Expected feature tags {expected}, got {actual}"
    )


# --- Then: feature children ---


@then('the feature should have a "{child_tag}" child')
def step_then_feature_has_child(context, child_tag):
    feat = context.parse_result.feature
    tags = [c.tag for c in feat.children]
    assert child_tag in tags, (
        f"Expected a '{child_tag}' child, got: {tags}"
    )


@then('the feature should have a "{child_tag}" child with kind "{kind}"')
def step_then_feature_has_child_with_kind(context, child_tag, kind):
    feat = context.parse_result.feature
    for child in feat.children:
        if child.tag == child_tag and hasattr(child.payload, "kind"):
            if child.payload.kind == kind:
                return
    tags = [(c.tag, getattr(c.payload, "kind", None)) for c in feat.children]
    assert False, (
        f"Expected a '{child_tag}' child with kind '{kind}', got: {tags}"
    )


@then('the rule child {index:d} should have name "{name}"')
def step_then_rule_child_name(context, index, name):
    feat = context.parse_result.feature
    rules = [c for c in feat.children if c.tag == "rule"]
    assert index < len(rules), (
        f"Rule index {index} out of range (only {len(rules)} rules)"
    )
    actual = rules[index].payload.name
    assert actual == name, (
        f"Expected rule[{index}] name '{name}', got '{actual}'"
    )


# --- Then: scenario details ---


@then('the first scenario should have tags "{tags_csv}"')
def step_then_first_scenario_tags(context, tags_csv):
    feat = context.parse_result.feature
    scenario = _first_scenario(feat)
    expected = [t.strip() for t in tags_csv.split(",")]
    actual = [t.name for t in scenario.tags]
    assert actual == expected, (
        f"Expected scenario tags {expected}, got {actual}"
    )


@then('the first scenario should have examples with header "{header_csv}"')
def step_then_first_scenario_examples_header(context, header_csv):
    feat = context.parse_result.feature
    scenario = _first_scenario(feat)
    assert len(scenario.examples) > 0, "Expected scenario to have examples"
    header = getattr(scenario.examples[0], "table-header")
    assert header is not None, "Expected examples to have a table header"
    actual = [c.value for c in header.cells]
    expected = [h.strip() for h in header_csv.split(",")]
    assert actual == expected, (
        f"Expected examples header {expected}, got {actual}"
    )


# --- Then: step arguments ---


@then("the first step should have a data table argument")
def step_then_first_step_data_table(context):
    step = _first_step(context)
    arg = step.argument
    assert arg is not None, "Expected step to have an argument"
    assert arg.tag == "data-table", (
        f"Expected data-table argument, got '{arg.tag}'"
    )
    # Stash for further assertions
    context.data_table = arg.payload


@then("the data table should have {count:d} rows")
def step_then_data_table_row_count(context, count):
    dt = context.data_table
    assert len(dt.rows) == count, (
        f"Expected {count} rows, got {len(dt.rows)}"
    )


@then('the data table header should be "{header_csv}"')
def step_then_data_table_header(context, header_csv):
    dt = context.data_table
    assert len(dt.rows) > 0, "Expected at least one row"
    actual = [c.value for c in dt.rows[0].cells]
    expected = [h.strip() for h in header_csv.split(",")]
    assert actual == expected, (
        f"Expected header {expected}, got {actual}"
    )


@then("the first step should have a doc string argument")
def step_then_first_step_doc_string(context):
    step = _first_step(context)
    arg = step.argument
    assert arg is not None, "Expected step to have an argument"
    assert arg.tag == "doc-string", (
        f"Expected doc-string argument, got '{arg.tag}'"
    )
    context.doc_string = arg.payload


@then('the doc string content should contain "{text}"')
def step_then_doc_string_contains(context, text):
    ds = context.doc_string
    assert text in ds.content, (
        f"Expected doc string to contain '{text}', got: '{ds.content[:200]}'"
    )


# --- Then: comments ---


@then('a comment should contain "{text}"')
def step_then_comment_contains(context, text):
    doc = context.parse_result
    found = any(text in c.text for c in doc.comments)
    assert found, (
        f"Expected a comment containing '{text}', got: "
        f"{[c.text for c in doc.comments]}"
    )


# --- Then: parse errors ---


@then('the first parse error should mention "{text}"')
def step_then_parse_error_mentions(context, text):
    errors = context.parse_result
    assert isinstance(errors, list) and len(errors) > 0
    msg = errors[0].message
    assert text.lower() in msg.lower(), (
        f"Expected error to mention '{text}', got: '{msg}'"
    )


# --- Then: tokenizer ---


@then("the tokenize result should be ok")
def step_then_tokenize_ok(context):
    result = context.tokenize_result
    assert result.tag == "ok", (
        f"Expected tokenize ok, got '{result.tag}': {result.payload}"
    )
    context.tokens = result.payload


@then('the tokens should include a "{token_tag}" token')
def step_then_tokens_include(context, token_tag):
    tokens = context.tokens
    tags = [t.tag for t in tokens]
    assert token_tag in tags, (
        f"Expected a '{token_tag}' token, got: {tags}"
    )


@then('a token-table-row should have a cell containing "{text}"')
def step_then_table_row_token_cell(context, text):
    tokens = context.tokens
    for tok in tokens:
        if tok.tag == "token-table-row":
            cells = tok.payload.cells
            if any(text in cell for cell in cells):
                return
    assert False, (
        f"Expected a token-table-row with cell containing '{text}'"
    )


@then('a comment-line token should contain "{text}"')
def step_then_comment_token_contains(context, text):
    tokens = context.tokens
    for tok in tokens:
        if tok.tag == "comment-line":
            if text in tok.payload.text:
                return
    assert False, (
        f"Expected a comment-line token containing '{text}'"
    )


# --- Then: writer ---


@then("the write result should be ok")
def step_then_write_ok(context):
    result = context.write_result
    assert result.tag == "ok", (
        f"Expected write ok, got '{result.tag}': {result.payload}"
    )


@then('the written output should contain "{text}"')
def step_then_written_contains(context, text):
    result = context.write_result
    payload = result.payload
    assert text in payload, (
        f"Expected written output to contain '{text}', got: {payload[:500]}"
    )


# --- Then: core WASM module validation ---


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


def _first_scenario(feat):
    """Get the first scenario child from a feature."""
    for child in feat.children:
        if child.tag == "scenario":
            return child.payload
    raise AssertionError(
        f"No scenario child found, got: {[c.tag for c in feat.children]}"
    )


def _first_step(context):
    """Get the first step from the first scenario in the parsed document."""
    feat = context.parse_result.feature
    scenario = _first_scenario(feat)
    assert len(scenario.steps) > 0, "Expected scenario to have steps"
    return scenario.steps[0]
