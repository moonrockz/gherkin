// Parse, tokenize, and format a Gherkin feature file using the WASM module via wazero.
//
// This example demonstrates using the Gherkin WASM core module from Go with
// the canonical ABI. Since no Go WASM runtime supports the Component Model yet,
// the gherkin package calls the core module's exports directly.
//
// Build the core WASM module first:
//
//	mise run build:wasm
//
// Then run:
//
//	go run . [path/to/file.feature]
package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gherkin-go-example/gherkin"
)

const defaultSource = `@smoke
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
`

func main() {
	ctx := context.Background()

	source := defaultSource
	if len(os.Args) > 1 {
		data, err := os.ReadFile(os.Args[1])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error reading file: %v\n", err)
			os.Exit(1)
		}
		source = string(data)
	}

	// Locate the core WASM module relative to this example.
	wasmPath := findWasmModule()

	engine, err := gherkin.NewEngine(ctx, wasmPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating engine: %v\n", err)
		os.Exit(1)
	}
	defer engine.Close(ctx)

	demoParse(ctx, engine, source)
	demoTokenize(ctx, engine, source)
	demoFormat(ctx, engine, source)
}

func demoParse(ctx context.Context, engine *gherkin.Engine, source string) {
	fmt.Println("=== Parsing ===")
	doc, err := engine.Parse(ctx, source)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Parse error: %v\n", err)
		return
	}

	feat := doc.Feature
	if feat == nil {
		fmt.Println("(no feature found)")
		return
	}

	fmt.Printf("Feature: %s\n", feat.Name)
	fmt.Printf("Keyword: %s\n", feat.Keyword)
	fmt.Printf("Language: %s\n", feat.Language)

	if len(feat.Tags) > 0 {
		tags := make([]string, len(feat.Tags))
		for i, t := range feat.Tags {
			tags[i] = t.Name
		}
		fmt.Printf("Tags: %s\n", strings.Join(tags, ", "))
	}

	for _, child := range feat.Children {
		switch {
		case child.Background != nil:
			fmt.Printf("  Background: %d steps\n", len(child.Background.Steps))
		case child.Scenario != nil:
			sc := child.Scenario
			tags := ""
			if len(sc.Tags) > 0 {
				names := make([]string, len(sc.Tags))
				for i, t := range sc.Tags {
					names[i] = t.Name
				}
				tags = strings.Join(names, ", ")
			}
			fmt.Printf("  %s: %s (tags: %s, steps: %d)\n",
				sc.Kind, sc.Name, orNone(tags), len(sc.Steps))
		case child.Rule != nil:
			fmt.Printf("  Rule: %s (%d children)\n",
				child.Rule.Name, len(child.Rule.Children))
		}
	}

	if len(doc.Comments) > 0 {
		fmt.Printf("Comments: %d\n", len(doc.Comments))
	}
}

func demoTokenize(ctx context.Context, engine *gherkin.Engine, source string) {
	fmt.Println("\n=== Tokenizing ===")
	tokens, err := engine.Tokenize(ctx, source)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Tokenize error: %v\n", err)
		return
	}

	limit := 10
	if len(tokens) < limit {
		limit = len(tokens)
	}

	for _, tok := range tokens[:limit] {
		info := ""
		if tok.Keyword != "" {
			info += fmt.Sprintf(" keyword=%q", tok.Keyword)
		}
		if tok.Name != "" {
			info += fmt.Sprintf(" name=%q", tok.Name)
		}
		if tok.Text != "" {
			info += fmt.Sprintf(" text=%q", tok.Text)
		}
		if tok.Language != "" {
			info += fmt.Sprintf(" language=%q", tok.Language)
		}
		fmt.Printf("  %s%s\n", tok.Type, info)
	}
	if len(tokens) > limit {
		fmt.Printf("  ... and %d more tokens\n", len(tokens)-limit)
	}
}

func demoFormat(ctx context.Context, engine *gherkin.Engine, source string) {
	fmt.Println("\n=== Round-trip (parse -> write) ===")
	formatted, err := engine.Format(ctx, source)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Format error: %v\n", err)
		return
	}
	fmt.Println(formatted)
}

// findWasmModule locates the core WASM module relative to the example directory.
func findWasmModule() string {
	// Try relative to the executable, then relative to CWD.
	candidates := []string{
		"../../_build/wasm/release/build/component/component.wasm",
	}

	// If we can determine the source directory, try relative to it.
	if exe, err := os.Executable(); err == nil {
		dir := filepath.Dir(exe)
		candidates = append(candidates,
			filepath.Join(dir, "../../_build/wasm/release/build/component/component.wasm"))
	}

	for _, p := range candidates {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}

	// Fallback: assume CWD is the project root.
	return "_build/wasm/release/build/component/component.wasm"
}

func orNone(s string) string {
	if s == "" {
		return "(none)"
	}
	return s
}
