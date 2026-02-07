# Usage Examples

These examples demonstrate how to use the Gherkin parser WASM component from different host languages.

## Prerequisites

Build the WASM component first:

```bash
mise run build:component
```

This produces `_build/gherkin.component.wasm` — a WASM Component Model module that exports three strongly-typed interfaces:

| Interface | Function | Description |
|-----------|----------|-------------|
| `moonrockz:gherkin/parser` | `parse(source) → result<gherkin-document, list<parse-error>>` | Parse Gherkin into a typed AST |
| `moonrockz:gherkin/tokenizer` | `tokenize(source) → result<list<token>, list<parse-error>>` | Tokenize Gherkin into typed tokens |
| `moonrockz:gherkin/writer` | `write(document) → result<string, string>` | Convert a typed AST back to Gherkin text |
| `moonrockz:gherkin/writer` | `write-events(events) → result<string, string>` | Convert events back to Gherkin text |

All functions accept a typed `source` record as input:

```wit
record source {
    uri: option<string>,
    data: string,
}
```

The parser returns a fully typed `gherkin-document` record (not JSON). See `wit/gherkin.wit` for the complete type definitions.

## Python

Requires [wasmtime-py](https://pypi.org/project/wasmtime/) (v41+):

```bash
pip install wasmtime
python examples/python/parse_feature.py [path/to/file.feature]
```

Key patterns for Python with wasmtime-py:
- Create source records with `SimpleNamespace(uri=None, data=text)`
- Access record fields via attributes: `doc.feature.name`
- Variant children have `.tag` and `.payload`: `child.tag == "scenario"`
- Enum values are strings: `scenario.kind == "scenario-outline"`
- Kebab-case WIT fields are accessed via `getattr(obj, 'keyword-type')`

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

Key patterns for JavaScript with jco:
- Create source records as plain objects: `{ uri: undefined, data: text }`
- Access record fields as properties: `doc.feature.name`
- Variant children have `.tag` and `.val`: `child.tag === "scenario"`
- Kebab-case WIT fields are mapped to camelCase: `step.keywordType`

See [javascript/parse_feature.mjs](javascript/parse_feature.mjs) for the full example.

## Typed AST Structure

The parsed document is returned as typed records and variants (not JSON). The structure is:

```
gherkin-document
├── source: { uri?, data }
├── feature?: {
│   ├── location: { line, column? }
│   ├── tags: [{ location, name, id }]
│   ├── language: string (e.g., "en", "fr")
│   ├── keyword: string (e.g., "Feature")
│   ├── name: string
│   ├── description: string
│   └── children: [feature-child]
│       ├── background { keyword, name, description, id, steps }
│       ├── scenario { keyword, name, kind, tags, description, id, steps, examples }
│       └── rule { keyword, name, tags, description, id, children: [rule-child] }
│           ├── background { ... }
│           └── scenario { ... }
└── comments: [{ location, text }]
```

Steps have an optional `argument` which is either a `doc-string` or `data-table` variant.

Tokens are returned as a list of typed variants (e.g., `feature-line`, `scenario-line`, `step-line`, `tag-line`, etc.) with structured payloads.
