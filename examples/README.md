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

## Go

No Go WASM runtime supports the Component Model yet, so the Go example uses the **core WASM module** directly via [wazero](https://github.com/tetratelabs/wazero) (pure Go, zero CGO). A clean `gherkin` package encapsulates all canonical ABI details behind an idiomatic Go API.

Build the core WASM module (not the component):

```bash
mise run build:wasm

# Run the example
cd examples/go
go run . [path/to/file.feature]
```

The `gherkin` package provides an `Engine` that compiles the WASM module once and creates fresh instances per call:

```go
engine, err := gherkin.NewEngine(ctx, wasmPath)
defer engine.Close(ctx)

doc, err := engine.Parse(ctx, source)       // → *Document
tokens, err := engine.Tokenize(ctx, source) // → []Token
formatted, err := engine.Format(ctx, source) // → string (round-trip)
```

Key patterns for Go with wazero:
- Compile once, instantiate per call (component model doesn't support re-entrance)
- All canonical ABI details (UTF-16 encoding, memory layout, post-return cleanup) are hidden inside the `gherkin` package
- `Format()` avoids re-encoding a `Document` — it passes the raw parse result memory directly to the write export
- Types mirror the WIT interface: `Document`, `Feature`, `Scenario`, `Step`, `Token`, etc.

See [go/gherkin/](go/gherkin/) for the package and [go/main.go](go/main.go) for the full example.

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
