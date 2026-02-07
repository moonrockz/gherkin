#!/usr/bin/env python3
"""Parse a Gherkin feature file using the WASM component with typed interfaces.

Usage:
    python parse_feature.py [path/to/file.feature]

Requires:
    pip install wasmtime

The WASM component must be built first:
    mise run build:component
"""

import sys
from pathlib import Path
from types import SimpleNamespace
from wasmtime import Engine, Store
from wasmtime.component import Component, Linker
from wasmtime.component._types import VariantLikeType, VariantType

# Workaround for wasmtime-py MRO bug with option<variant> lowering.
# VariantType.add_classes resolves to the abstract no-op in ValType
# instead of the concrete implementation in VariantLikeType.
VariantType.add_classes = VariantLikeType.add_classes

# Path to the built component
COMPONENT_PATH = Path(__file__).parent.parent.parent / "_build" / "gherkin.component.wasm"

# WIT interface names (v0.2.0 — typed interfaces)
PARSER_IFACE = "moonrockz:gherkin/parser@0.2.0"
TOKENIZER_IFACE = "moonrockz:gherkin/tokenizer@0.2.0"
WRITER_IFACE = "moonrockz:gherkin/writer@0.2.0"


def create_instance():
    """Create a WASM component instance."""
    engine = Engine()
    component = Component.from_file(engine, str(COMPONENT_PATH))
    linker = Linker(engine)
    store = Store(engine)
    instance = linker.instantiate(store, component)
    return engine, store, instance


def get_func(instance, store, interface, name):
    """Get an exported function from the component."""
    iface_idx = instance.get_export_index(store, interface)
    func_idx = instance.get_export_index(store, name, iface_idx)
    return instance.get_func(store, func_idx)


def make_source(data, uri=None):
    """Create a typed source record for the component."""
    return SimpleNamespace(uri=uri, data=data)


def parse(source_text):
    """Parse Gherkin source text into a typed document.

    Returns a Record with fields: source, feature, comments.
    On error returns a list of parse error Records.
    """
    _, store, instance = create_instance()
    func = get_func(instance, store, PARSER_IFACE, "parse")
    result = func(store, make_source(source_text))
    # result<gherkin-document, list<parse-error>>:
    #   ok  -> Record with .source, .feature, .comments
    #   err -> list of Record with .message, .line, .column
    if isinstance(result, list):
        messages = [f"  line {e.line}: {e.message}" for e in result]
        raise RuntimeError(f"Parse error:\n" + "\n".join(messages))
    return result


def tokenize(source_text):
    """Tokenize Gherkin source text into typed tokens.

    Returns a list of Variant objects with .tag and .payload.
    """
    _, store, instance = create_instance()
    func = get_func(instance, store, TOKENIZER_IFACE, "tokenize")
    result = func(store, make_source(source_text))
    # result<list<token>, list<parse-error>>:
    #   Both are lists, so result is a Variant with .tag/.payload
    if result.tag == "err":
        raise RuntimeError(f"Tokenize error: {result.payload}")
    return result.payload


def write(document):
    """Convert a typed document back to formatted Gherkin text."""
    _, store, instance = create_instance()
    func = get_func(instance, store, WRITER_IFACE, "write")
    result = func(store, document)
    # result<string, string>: Variant with .tag/.payload
    if result.tag == "err":
        raise RuntimeError(f"Write error: {result.payload}")
    return result.payload


def main():
    if len(sys.argv) > 1:
        source = Path(sys.argv[1]).read_text()
    else:
        source = """\
@smoke
Feature: User Authentication
  As a registered user
  I want to log in to the application
  So that I can access my account

  Background:
    Given the application is running

  Scenario: Successful login
    Given a registered user with email "alice@example.com"
    When they enter valid credentials
    Then they should see the dashboard
    And they should see a welcome message

  Scenario: Failed login with wrong password
    Given a registered user with email "alice@example.com"
    When they enter an incorrect password
    Then they should see an error message
"""

    # --- Parse to typed AST ---
    print("=== Parsing ===")
    doc = parse(source)
    feature = doc.feature
    if feature:
        print(f"Feature: {feature.name}")
        print(f"Keyword: {feature.keyword}")
        print(f"Language: {feature.language}")
        print(f"Tags: {[t.name for t in feature.tags]}")
        if feature.description:
            print(f"Description: {feature.description.strip()[:80]}...")
        for child in feature.children:
            val = child.payload
            if child.tag == "background":
                print(f"  Background: {len(val.steps)} steps")
            elif child.tag == "scenario":
                tags = [t.name for t in val.tags]
                kind = val.kind  # "scenario" or "scenario-outline"
                print(f"  {kind}: {val.name} (tags: {tags}, steps: {len(val.steps)})")
            elif child.tag == "rule":
                print(f"  Rule: {val.name} ({len(val.children)} children)")
    else:
        print("(no feature found)")

    if doc.comments:
        print(f"Comments: {len(doc.comments)}")

    # --- Tokenize ---
    print("\n=== Tokenizing ===")
    tokens = tokenize(source)
    for tok in tokens[:10]:
        info = ""
        if tok.payload is not None:
            p = tok.payload
            if hasattr(p, "keyword"):
                info = f" keyword={p.keyword!r}"
            if hasattr(p, "name"):
                info += f" name={p.name!r}"
            if hasattr(p, "text"):
                info += f" text={p.text!r}"
        print(f"  {tok.tag}{info}")
    if len(tokens) > 10:
        print(f"  ... and {len(tokens) - 10} more tokens")

    # --- Round-trip: parse then write ---
    print("\n=== Round-trip (parse -> write) ===")
    written = write(doc)
    print(written)


if __name__ == "__main__":
    main()
