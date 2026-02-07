# Usage Examples

These examples demonstrate how to use the Gherkin parser WASM component from different host languages.

## Prerequisites

Build the WASM component first:

```bash
mise run build:component
```

This produces `_build/gherkin.component.wasm` — a WASM Component Model module that exports three interfaces:

| Interface | Function | Description |
|-----------|----------|-------------|
| `moonrockz:gherkin/parser` | `parse(source) → result<string, string>` | Parse Gherkin to JSON AST |
| `moonrockz:gherkin/tokenizer` | `tokenize(source) → result<string, string>` | Tokenize Gherkin to JSON tokens |
| `moonrockz:gherkin/writer` | `write(json-ast) → result<string, string>` | Convert JSON AST back to Gherkin |

All functions accept and return strings. On success, the `ok` variant contains the result (JSON or Gherkin text). On failure, the `err` variant contains an error message.

## Python

Requires [wasmtime-py](https://pypi.org/project/wasmtime/) (v41+):

```bash
pip install wasmtime
python examples/python/parse_feature.py [path/to/file.feature]
```

See [python/parse_feature.py](python/parse_feature.py) for the full example.

## JavaScript / Node.js

Requires [jco](https://github.com/nicknisi/jco) to transpile the component for JavaScript:

```bash
npm install @bytecodealliance/jco @bytecodealliance/preview2-shim

# Transpile the component to a JS module
npx jco transpile _build/gherkin.component.wasm -o examples/javascript/gherkin

# Run the example
node examples/javascript/parse_feature.mjs [path/to/file.feature]
```

See [javascript/parse_feature.mjs](javascript/parse_feature.mjs) for the full example.

## JSON AST Structure

The parsed JSON AST follows this structure:

```json
{
  "source": { "uri": null, "data": "..." },
  "feature": {
    "location": { "line": 1, "column": 1 },
    "tags": [{ "location": {...}, "name": "@smoke", "id": "0" }],
    "language": "en",
    "keyword": "Feature",
    "name": "Feature Name",
    "description": "Optional description",
    "children": [
      ["Background", { "keyword": "Background", "steps": [...] }],
      ["Scenario", { "keyword": "Scenario", "name": "...", "steps": [...], "tags": [...] }],
      ["Rule", { "keyword": "Rule", "name": "...", "children": [...] }]
    ],
    "id": "1"
  },
  "comments": [{ "location": {...}, "text": "# comment text" }]
}
```

Children are serialized as `["Tag", { ...node }]` tuples where `Tag` is one of `Background`, `Scenario`, or `Rule`.
