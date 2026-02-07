// Package gherkin provides a Go client for the Gherkin parser WASM module.
//
// It loads the core WASM module (built by MoonBit) via wazero and provides
// a clean Go API for parsing, tokenizing, and formatting Gherkin feature files.
//
// Since no Go WASM runtime supports the Component Model yet, this package
// calls the core module's canonical ABI exports directly. All ABI details
// are encapsulated — consumers interact with idiomatic Go types.
package gherkin

import "fmt"

// Document is the top-level result of parsing a Gherkin source file.
type Document struct {
	Feature  *Feature
	Comments []Comment
}

// Feature represents a Gherkin Feature with its metadata and children.
type Feature struct {
	Location    Location
	Tags        []Tag
	Language    string
	Keyword     string
	Name        string
	Description string
	Children    []FeatureChild
}

// FeatureChild is a child of a Feature: exactly one of Background, Scenario, or Rule is set.
type FeatureChild struct {
	Background *Background
	Scenario   *Scenario
	Rule       *Rule
}

// Background represents a Background section with shared setup steps.
type Background struct {
	Location    Location
	Keyword     string
	Name        string
	Description string
	ID          string
	Steps       []Step
}

// Scenario represents a Scenario or Scenario Outline.
type Scenario struct {
	Location    Location
	Tags        []Tag
	Kind        ScenarioKind
	Keyword     string
	Name        string
	Description string
	ID          string
	Steps       []Step
	Examples    []Examples
}

// Rule represents a business Rule grouping scenarios.
type Rule struct {
	Location    Location
	Tags        []Tag
	Keyword     string
	Name        string
	Description string
	ID          string
	Children    []RuleChild
}

// RuleChild is a child of a Rule: either Background or Scenario.
type RuleChild struct {
	Background *Background
	Scenario   *Scenario
}

// Step represents a single step (Given/When/Then/And/But).
type Step struct {
	Location    Location
	Keyword     string
	KeywordType KeywordType
	Text        string
	ID          string
	Argument    *StepArgument
}

// StepArgument is either a DataTable or a DocString attached to a step.
type StepArgument struct {
	DataTable *DataTable
	DocString *DocString
}

// DataTable is a table argument attached to a step.
type DataTable struct {
	Location Location
	Rows     []TableRow
}

// DocString is a multi-line string argument attached to a step.
type DocString struct {
	Location  Location
	MediaType string
	Content   string
	Delimiter string
}

// Examples represents an Examples section in a Scenario Outline.
type Examples struct {
	Location    Location
	Tags        []Tag
	Keyword     string
	Name        string
	Description string
	ID          string
	TableHeader *TableRow
	TableBody   []TableRow
}

// TableRow is a row in a data table or examples table.
type TableRow struct {
	Location Location
	ID       string
	Cells    []TableCell
}

// TableCell is a single cell in a table row.
type TableCell struct {
	Location Location
	Value    string
}

// Tag represents a Gherkin tag (e.g., @smoke).
type Tag struct {
	Location Location
	Name     string
	ID       string
}

// Comment represents a comment line in the source.
type Comment struct {
	Location Location
	Text     string
}

// Location is a source position with line and optional column.
type Location struct {
	Line   int32
	Column *int32
}

// ScenarioKind distinguishes Scenario from Scenario Outline.
type ScenarioKind string

const (
	ScenarioKindScenario        ScenarioKind = "scenario"
	ScenarioKindScenarioOutline ScenarioKind = "scenario-outline"
)

// KeywordType classifies step keywords semantically.
type KeywordType string

const (
	KeywordTypeContext     KeywordType = "context"
	KeywordTypeAction     KeywordType = "action"
	KeywordTypeOutcome    KeywordType = "outcome"
	KeywordTypeConjunction KeywordType = "conjunction"
	KeywordTypeUnknown    KeywordType = "unknown"
)

// Token represents a lexer token from the Gherkin tokenizer.
type Token struct {
	Type    TokenType
	Line    int32
	Column  *int32
	Keyword string // for keyword-bearing tokens (Feature, Scenario, Step, etc.)
	Name    string // for named tokens (Feature name, Scenario name, etc.)
	Text    string // for text-bearing tokens (step text, comment text, etc.)

	// StepLine-specific
	KeywordType KeywordType

	// ScenarioLine-specific
	Kind ScenarioKind

	// DocStringSeparator-specific
	Delimiter string
	MediaType string

	// TagLine-specific: list of tag names
	Tags []string

	// TokenTableRow-specific: list of cell values
	Cells []string

	// Language token
	Language string
}

// TokenType identifies the kind of token.
type TokenType int

const (
	TokenFeatureLine       TokenType = 0
	TokenRuleLine          TokenType = 1
	TokenBackgroundLine    TokenType = 2
	TokenScenarioLine      TokenType = 3
	TokenExamplesLine      TokenType = 4
	TokenStepLine          TokenType = 5
	TokenDocStringSeparator TokenType = 6
	TokenTableRow          TokenType = 7
	TokenTagLine           TokenType = 8
	TokenCommentLine       TokenType = 9
	TokenLanguage          TokenType = 10
	TokenEmpty             TokenType = 11
	TokenOther             TokenType = 12
	TokenEOF               TokenType = 13
)

var tokenTypeNames = [...]string{
	"feature-line", "rule-line", "background-line", "scenario-line",
	"examples-line", "step-line", "doc-string-separator", "token-table-row",
	"tag-line", "comment-line", "language", "empty", "other", "eof",
}

func (t TokenType) String() string {
	if int(t) < len(tokenTypeNames) {
		return tokenTypeNames[t]
	}
	return "unknown"
}

// ParseError is returned when the parser encounters invalid Gherkin syntax.
type ParseError struct {
	Message string
	Line    int32
	Column  *int32
}

func (e *ParseError) Error() string {
	if e.Column != nil {
		return fmt.Sprintf("line %d, column %d: %s", e.Line, *e.Column, e.Message)
	}
	return fmt.Sprintf("line %d: %s", e.Line, e.Message)
}

// ParseErrors collects multiple parse errors into a single error.
type ParseErrors []ParseError

func (e ParseErrors) Error() string {
	if len(e) == 1 {
		return e[0].Error()
	}
	msg := fmt.Sprintf("%d parse errors:", len(e))
	for _, pe := range e {
		msg += "\n  " + pe.Error()
	}
	return msg
}
