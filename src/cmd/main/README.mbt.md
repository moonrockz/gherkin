# Gherkin CLI

Command-line tool for parsing Gherkin `.feature` files to JSON.

## Usage

Parse a file:

```bash
moon run src/cmd/main -- path/to/file.feature
```

Parse from stdin:

```bash
cat file.feature | moon run src/cmd/main -- -
```

When no argument is given, reads from stdin:

```bash
echo "Feature: Test" | moon run src/cmd/main
```

## Output

Outputs the parsed `GherkinDocument` as pretty-printed JSON (2-space indent):

```json
{
  "source": {
    "uri": "path/to/file.feature",
    "data": "Feature: Test\n  Scenario: Example\n    Given a step\n"
  },
  "feature": {
    "location": { "line": 1, "column": 1 },
    "tags": [],
    "language": "en",
    "keyword": "Feature",
    "name": "Test",
    "description": "",
    "children": [...]
  },
  "comments": []
}
```

## Errors

File not found:

```
Error reading missing.feature: Failed to read file missing.feature: No such file or directory (os error 2)
```

Parse errors print the error message with location context.
