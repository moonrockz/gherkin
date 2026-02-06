# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) Gherkin parser project.

## Project Overview

This module (`moonrockz/gherkin`) is **primarily a library** for other MoonBit
projects to consume. The core value is the parsing library itself -- types,
parser, AST, visitors -- which other MoonBit users import as a dependency to
build BDD tooling, test runners, linters, formatters, and IDE integrations.

The library is the first-class artifact. API design, ergonomics, and type
safety for library consumers are the top priority.

### CLI for Non-Code Integration

In addition to the library, the project provides a **CLI tool** (`src/cmd/`)
that wraps the library for tooling that integrates at the process level rather
than the code level. The CLI supports output format flags such as:

- `--json` -- Emit the parsed Gherkin document as a single JSON object
  (suitable for tools that consume a complete document at once).
- `--jsonl` -- Emit the parsed Gherkin as newline-delimited JSON (one event
  per line, suitable for streaming pipelines and Unix-style tooling).

This allows non-MoonBit tools (shell scripts, CI pipelines, editors, other
language ecosystems) to use the parser by invoking it as a subprocess and
consuming structured output. The CLI is a thin wrapper -- all parsing logic
lives in the library.

The CLI uses [`TheWaWaR/clap`](https://mooncakes.io/docs/TheWaWaR/clap) for
command-line argument parsing.

### Architecture Summary

```
moonrockz/gherkin
├── src/              # The library (primary artifact)
│   ├── *.mbt         # Core library: types, parser, AST, visitors
│   ├── *_test.mbt    # Unit tests
│   └── cmd/          # CLI tool (secondary artifact)
│       └── main/     # CLI entry point, flag parsing, output formatting
├── tests/            # BDD acceptance tests (Behave)
│   ├── features/     # .feature files + step definitions
│   └── fixtures/     # Sample .feature files for testing
└── docs/             # Reference documentation
    ├── specs/        # Gherkin language specification
    └── references/   # Parser design references
```

## Project Structure

- MoonBit packages are organized per directory, for each directory, there is a
  `moon.pkg.json` file listing its dependencies. Each package has its files and
  blackbox test files (common, ending in `_test.mbt`) and whitebox test files
  (ending in `_wbtest.mbt`).

- In the toplevel directory, this is a `moon.mod.json` file listing about the
  module and some meta information.

## Design Philosophy

This project follows **functional design principles**. These are non-negotiable:

- **Algebraic data types (ADTs)**: Model domain concepts using enums (sum types)
  and structs (product types). Use ADTs to make the type system express the
  domain precisely.

- **Make invalid states unrepresentable**: Design types so that illegal
  combinations cannot be constructed. If a state shouldn't exist, the type
  system should prevent it -- not runtime checks.

- **Avoid primitive obsession**: Do not use raw `String`, `Int`, or `Bool` where
  a domain-specific type is appropriate. Wrap primitives in meaningful types
  (e.g., `Tag` instead of `String`, `Location` instead of `(Int, Int)`,
  `KeywordType` enum instead of `String`).

- **Prefer immutability**: Default to immutable data. Use `mut` only when
  mutation is clearly necessary and localized. Favor returning new values over
  modifying existing ones.

- **Pattern matching over conditionals**: Use `match` expressions to
  exhaustively handle all variants of an enum. The compiler will catch missing
  cases.

- **Composition over inheritance**: Build complex behavior by composing small,
  focused functions and types rather than deep hierarchies.

- **Total functions**: Functions should handle all possible inputs. Prefer
  returning `Option` or `Result` over panicking. Reserve `abort` for truly
  impossible states that the type system cannot prevent.

## Test-Driven Development (TDD)

This project practices **strict TDD**. Tests are written **before**
implementation code. This is not optional.

### The TDD Cycle

For every piece of new functionality, follow **Red-Green-Refactor**:

1. **Red**: Write a failing test that describes the desired behavior. Run it.
   Confirm it fails for the right reason.
2. **Green**: Write the **minimum** implementation code to make the test pass.
   No more.
3. **Refactor**: Clean up the implementation while keeping tests green. Improve
   names, remove duplication, simplify. Tests must still pass after refactoring.

Repeat for the next behavior.

### What This Means in Practice

- **Never write implementation code without a failing test first.** If you're
  about to write a function, write a test that calls it and asserts the expected
  result. Watch it fail (compilation error or assertion failure). Then implement.

- **Tests define the specification.** The test suite is the source of truth for
  what the code should do. If a behavior isn't tested, it doesn't exist.

- **Small steps.** Each TDD cycle should be small -- a single function, a single
  edge case, a single variant of an enum. Resist the urge to implement a large
  feature and then backfill tests.

- **Tests are not an afterthought.** They are the first artifact produced. They
  drive the design of the API by forcing you to think about how code will be
  called before you write it.

### Using `#declaration_only` for Spec-First Design

MoonBit's `#declaration_only` attribute is a powerful tool for the Red phase of
TDD. It lets you define function signatures and type declarations before
implementing them:

```moonbit
#declaration_only
type GherkinDocument

#declaration_only
pub fn GherkinDocument::parse(input : String) -> GherkinDocument raise {
  ...
}
```

The body is filled with `...` as a placeholder. This establishes the API
contract upfront -- types, function signatures, and method interfaces -- so
you can:

1. Write tests against the declared signatures (they compile but the
   declarations are unimplemented).
2. Verify the API design feels right by writing calling code first.
3. Fill in implementations one by one, turning each `#declaration_only` into
   a real implementation as its tests go green.

Use `#declaration_only` to sketch out an entire module's public surface before
writing any logic. This is spec-driven development -- define what your code
looks like to consumers, then make it work.

### Two Testing Layers

This project uses two distinct testing layers that serve different purposes:

1. **Unit tests** (MoonBit `_test.mbt` files, run via `moon test`):
   Test individual functions, types, and modules in isolation. These are written
   in MoonBit alongside the implementation code. Use `inspect` for snapshot
   tests and `assert_eq` in loops.

2. **BDD acceptance tests** (Behave `.feature` files in `tests/features/`):
   Test the parser's behavior from the outside, as a consumer would experience
   it. These are written in Gherkin and executed with Behave. They validate that
   complete features work end-to-end.

### Completing a Feature

A feature is not done until **both** testing layers pass:

- Unit tests confirm the internal components work correctly.
- Acceptance tests confirm the integrated feature meets its specification.

If you add a new parser capability (e.g., parsing `Rule` nodes), the workflow is:

1. Write or update the `.feature` acceptance test describing the expected
   behavior.
2. Run it -- confirm it fails (the feature isn't implemented yet).
3. Drop down to unit tests. TDD the internal components (tokenizer, parser
   rules, AST nodes) with `_test.mbt` files.
4. Once the unit-level pieces are green, wire them together.
5. Run the acceptance test again -- it should now pass.
6. Refactor with confidence: both layers are green.

See [docs/references/testing-strategy.md](docs/references/testing-strategy.md)
for the full reference on unit tests vs BDD tests vs acceptance tests.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check the test is passed. MoonBit supports snapshot
  testing, so when your changes indeed change the behavior of the code, you
  should run `moon test --update` to update the snapshot.

- You can run `moon check` to check the code is linted correctly.

- When writing tests, you are encouraged to use `inspect` and run
  `moon test --update` to update the snapshots, only use assertions like
  `assert_eq` when you are in some loops where each snapshot may vary. You can
  use `moon coverage analyze > uncovered.log` to see which parts of your code
  are not covered by tests.

- agent-todo.md has some small tasks that are easy for AI to pick up, agent is
  welcome to finish the tasks and check the box when you are done
