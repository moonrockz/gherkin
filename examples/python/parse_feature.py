#!/usr/bin/env python3
"""Parse a Gherkin feature file using the WASM component.

Usage:
    python parse_feature.py [path/to/file.feature]

Requires:
    pip install wasmtime

The WASM component must be built first:
    mise run build:component
"""

import json
import sys
from pathlib import Path
from wasmtime import Engine, Store
from wasmtime.component import Component, Linker

# Path to the built component
COMPONENT_PATH = Path(__file__).parent.parent.parent / "_build" / "gherkin.component.wasm"

# WIT interface names
PARSER_IFACE = "moonrockz:gherkin/parser@0.1.0"
TOKENIZER_IFACE = "moonrockz:gherkin/tokenizer@0.1.0"
WRITER_IFACE = "moonrockz:gherkin/writer@0.1.0"


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


def parse(source: str) -> dict:
    """Parse Gherkin source text into a JSON AST."""
    _, store, instance = create_instance()
    func = get_func(instance, store, PARSER_IFACE, "parse")
    result = func(store, source)
    if result.tag == "err":
        raise RuntimeError(f"Parse error: {result.payload}")
    return json.loads(result.payload)


def tokenize(source: str) -> list:
    """Tokenize Gherkin source text into a token array."""
    _, store, instance = create_instance()
    func = get_func(instance, store, TOKENIZER_IFACE, "tokenize")
    result = func(store, source)
    if result.tag == "err":
        raise RuntimeError(f"Tokenize error: {result.payload}")
    return json.loads(result.payload)


def write(ast_json: str) -> str:
    """Convert a JSON AST back to formatted Gherkin text."""
    _, store, instance = create_instance()
    func = get_func(instance, store, WRITER_IFACE, "write")
    result = func(store, ast_json)
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

    # --- Parse to AST ---
    print("=== Parsing ===")
    ast = parse(source)
    feature = ast.get("feature")
    if feature:
        print(f"Feature: {feature['name']}")
        print(f"Language: {feature['language']}")
        print(f"Tags: {[t['name'] for t in feature.get('tags', [])]}")
        for child in feature.get("children", []):
            tag, node = child[0], child[1]
            if tag == "Background":
                print(f"  Background: {len(node['steps'])} steps")
            elif tag == "Scenario":
                tags = [t["name"] for t in node.get("tags", [])]
                print(f"  Scenario: {node['name']} (tags: {tags}, steps: {len(node['steps'])})")

    # --- Tokenize ---
    print("\n=== Tokenizing ===")
    tokens = tokenize(source)
    for token in tokens[:10]:
        tag = token[0]
        print(f"  {tag}")
    if len(tokens) > 10:
        print(f"  ... and {len(tokens) - 10} more tokens")

    # --- Round-trip: parse then write ---
    print("\n=== Round-trip (parse -> write) ===")
    written = write(json.dumps(ast))
    print(written)


if __name__ == "__main__":
    main()
