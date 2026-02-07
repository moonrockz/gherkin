/**
 * Parse a Gherkin feature file using the WASM component via jco.
 *
 * This example demonstrates using the Gherkin WASM component with the
 * JavaScript Component Model tooling (jco/preview2-shim) and typed interfaces.
 *
 * Setup:
 *   npm install @bytecodealliance/jco @bytecodealliance/preview2-shim
 *
 * Transpile the component first:
 *   npx jco transpile _build/gherkin.component.wasm -o examples/javascript/gherkin
 *
 * Then run:
 *   node examples/javascript/parse_feature.mjs [path/to/file.feature]
 *
 * The WASM component must be built first:
 *   mise run build:component
 */

import { readFileSync } from "node:fs";
import { parse, tokenize, write } from "./gherkin/gherkin.js";

const source =
  process.argv[2] != null
    ? readFileSync(process.argv[2], "utf-8")
    : `\
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
`;

// --- Parse to typed AST ---
// parse() takes a source record { uri, data } and returns a typed document.
// jco maps WIT records to plain JS objects and WIT variants to tagged objects.
console.log("=== Parsing ===");
const doc = parse({ uri: undefined, data: source });
const feature = doc.feature;
if (feature) {
  console.log(`Feature: ${feature.name}`);
  console.log(`Keyword: ${feature.keyword}`);
  console.log(`Language: ${feature.language}`);
  console.log(
    `Tags: ${(feature.tags || []).map((t) => t.name).join(", ") || "(none)"}`
  );
  for (const child of feature.children || []) {
    // jco represents WIT variants as { tag: string, val: payload }
    const { tag, val } = child;
    if (tag === "background") {
      console.log(`  Background: ${val.steps.length} steps`);
    } else if (tag === "scenario") {
      const tags = (val.tags || []).map((t) => t.name).join(", ");
      console.log(
        `  ${val.kind}: ${val.name} (tags: ${tags || "(none)"}, steps: ${val.steps.length})`
      );
    } else if (tag === "rule") {
      console.log(`  Rule: ${val.name} (${val.children.length} children)`);
    }
  }
}

// --- Tokenize ---
// tokenize() takes a source record and returns a list of typed tokens.
console.log("\n=== Tokenizing ===");
const tokens = tokenize({ uri: undefined, data: source });
for (const tok of tokens.slice(0, 10)) {
  let info = "";
  if (tok.val != null) {
    if (tok.val.keyword) info += ` keyword=${JSON.stringify(tok.val.keyword)}`;
    if (tok.val.name !== undefined)
      info += ` name=${JSON.stringify(tok.val.name)}`;
    if (tok.val.text) info += ` text=${JSON.stringify(tok.val.text)}`;
  }
  console.log(`  ${tok.tag}${info}`);
}
if (tokens.length > 10) {
  console.log(`  ... and ${tokens.length - 10} more tokens`);
}

// --- Round-trip: parse then write ---
// write() takes a typed document record and returns Gherkin text.
console.log("\n=== Round-trip (parse -> write) ===");
const written = write(doc);
console.log(written);
