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

## Conventional Commits

This project uses **[Conventional Commits](https://www.conventionalcommits.org)**.
All commit messages MUST follow this format:

```
type(scope): description

[optional body]

[optional footer(s)]
```

### Commit Types

| Type       | Purpose                        | Changelog section | Version bump |
|------------|--------------------------------|-------------------|-------------|
| `feat`     | New feature                    | Added             | MINOR        |
| `fix`      | Bug fix                        | Fixed             | PATCH        |
| `refactor` | Code restructuring             | Changed           | -            |
| `perf`     | Performance improvement        | Performance       | -            |
| `docs`     | Documentation only             | Documentation     | -            |
| `test`     | Adding/updating tests          | (skipped)         | -            |
| `build`    | Build system changes           | (skipped)         | -            |
| `ci`       | CI/CD configuration            | (skipped)         | -            |
| `chore`    | Maintenance tasks              | (skipped)         | -            |
| `style`    | Code formatting (no logic)     | (skipped)         | -            |

### Breaking Changes

Use `!` after the type to indicate a breaking change (triggers MAJOR bump):

```
feat(parser)!: change parse() return type to Result
```

Or use a `BREAKING CHANGE:` footer in the commit body.

### Scopes

Scopes are encouraged to provide context:

- `feat(parser):` / `fix(lexer):` / `refactor(writer):` -- library components
- `feat(cli):` / `fix(cli):` -- CLI tool
- `ci(release):` / `build(wasm):` -- infrastructure
- `docs(api):` -- documentation

### Changelog Generation

Changelogs are generated automatically from commit history using **git-cliff**.
Never edit `CHANGELOG.md` manually -- it is regenerated from git history.

- `mise run release:changelog` -- regenerate CHANGELOG.md
- `mise run release:notes` -- generate release notes for latest version
- `mise run release:version` -- compute next version from commits
- `mise run release:bump` -- update `moon.mod.json` version to match

## Mise Tasks

All build, test, and release operations are defined as **mise file-based tasks**
in the `mise-tasks/` directory. Use `mise run <task>` to execute them.

### Available Tasks

Run `mise tasks` to list all tasks. Key tasks:

| Task                    | Purpose                                           |
|-------------------------|---------------------------------------------------|
| `test:unit`             | Run MoonBit unit tests                            |
| `test:bdd`              | Run CLI BDD tests with behave                     |
| `test:wasm`             | Run WASM component BDD tests                      |
| `test:all`              | Run all tests (unit + BDD + WASM)                 |
| `build:native`          | Build native CLI binary                           |
| `build:wasm`            | Build core WASM module                            |
| `build:component`       | Build WASM component (embed + new)                |
| `generate:wit-bindgen`  | Regenerate WIT bindings                           |
| `release:version`       | Compute next version from conventional commits    |
| `release:changelog`     | Generate CHANGELOG.md                             |
| `release:notes`         | Generate release notes for latest version         |
| `release:bump`          | Update moon.mod.json version                      |
| `release:pre-check`    | Validate release readiness                        |
| `release:credentials`  | Set up mooncakes.io credentials (CI only)         |
| `release:publish`      | Publish package to mooncakes.io                   |
| `release:prepare-assets`| Prepare release assets from build artifacts       |

### Creating New Tasks

New tasks go in `mise-tasks/` as executable scripts:

```bash
#!/usr/bin/env bash
#MISE description="What this task does"
#MISE depends=["other:task"]
set -euo pipefail

# task implementation
```

Use subdirectories for namespacing: `mise-tasks/build/native` becomes `build:native`.

**Rules:**
- **Always** use file-based tasks in `mise-tasks/` -- never add inline TOML
  tasks to `.mise.toml`.
- **GitHub workflows** must call `mise run <task>` instead of inline shell
  scripts. If a workflow needs a new operation, create a mise task for it first.
- The `.mise.toml` file contains only `[tools]` -- no `[tasks]` sections.

## Release Process

This project publishes to **mooncakes.io** (MoonBit package registry) and
**GitHub Releases**.

### Release Pipeline (5 Phases)

1. **Validate** -- Pre-checks, version computation, release notes generation
2. **Tag** -- Create immutable git tag `v{version}` (workflow_dispatch only)
3. **Publish to Mooncakes** -- `moon publish` to mooncakes.io (MUST succeed
   before artifacts are built)
4. **Build Artifacts** -- Native binaries (Linux, macOS, Windows) + WASM
   components
5. **Create GitHub Release** -- Upload artifacts with release notes

### Immutability Rules

- Tags are **immutable**: never `git tag --force`, never `git push --force` tags
- GitHub Releases are **immutable**: never delete and recreate
- If a release has problems, create a new **patch release** (e.g., 0.2.1 to
  fix 0.2.0)

### How to Release

Releases are triggered by:
- **Tag push**: Push a tag matching `v*` to trigger the pipeline from Phase 3
- **workflow_dispatch**: Manually trigger from GitHub Actions (computes version,
  creates tag, then runs full pipeline)

For manual releases from the CLI:
```bash
# 1. Ensure on main, all tests pass
mise run release:pre-check

# 2. Bump version and changelog
mise run release:bump
mise run release:changelog

# 3. Commit and tag
VERSION=$(mise run release:version)
git add moon.mod.json CHANGELOG.md
git commit -m "chore(release): v${VERSION}"
git tag -a "v${VERSION}" -m "Release v${VERSION}"
git push origin main --tags
```

### Mooncakes.io Publishing

- Package published as `moonrockz/gherkin` on mooncakes.io
- Requires `MOONCAKES_USER_TOKEN` secret in GitHub Actions
- Credentials stored at `~/.moon/credentials.json`
- Pre-publish checks: `moon check`, `moon test`, `moon fmt`

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

- Run `mise run test:unit` to check the tests pass. MoonBit supports snapshot
  testing, so when your changes indeed change the behavior of the code, you
  should run `moon test --update` to update the snapshot.

- You can run `moon check` to check the code is linted correctly.

- When writing tests, you are encouraged to use `inspect` and run
  `moon test --update` to update the snapshots, only use assertions like
  `assert_eq` when you are in some loops where each snapshot may vary. You can
  use `moon coverage analyze > uncovered.log` to see which parts of your code
  are not covered by tests.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
