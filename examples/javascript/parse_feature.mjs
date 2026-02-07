/**
 * Parse a Gherkin feature file using the WASM component via jco.
 *
 * This example demonstrates using the Gherkin WASM component with the
 * JavaScript Component Model tooling (jco/preview2-shim).
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

// --- Parse to AST ---
console.log("=== Parsing ===");
const result = parse(source);
if (result.tag === "err") {
  console.error("Parse error:", result.val);
  process.exit(1);
}
const ast = JSON.parse(result.val);
const feature = ast.feature;
if (feature) {
  console.log(`Feature: ${feature.name}`);
  console.log(`Language: ${feature.language}`);
  console.log(
    `Tags: ${(feature.tags || []).map((t) => t.name).join(", ") || "(none)"}`
  );
  for (const child of feature.children || []) {
    const [tag, node] = child;
    if (tag === "Background") {
      console.log(`  Background: ${node.steps.length} steps`);
    } else if (tag === "Scenario") {
      const tags = (node.tags || []).map((t) => t.name).join(", ");
      console.log(
        `  Scenario: ${node.name} (tags: ${tags || "(none)"}, steps: ${node.steps.length})`
      );
    }
  }
}

// --- Tokenize ---
console.log("\n=== Tokenizing ===");
const tokResult = tokenize(source);
if (tokResult.tag === "ok") {
  const tokens = JSON.parse(tokResult.val);
  for (const token of tokens.slice(0, 10)) {
    console.log(`  ${token[0]}`);
  }
  if (tokens.length > 10) {
    console.log(`  ... and ${tokens.length - 10} more tokens`);
  }
}

// --- Round-trip: parse then write ---
console.log("\n=== Round-trip (parse -> write) ===");
const writeResult = write(result.val);
if (writeResult.tag === "ok") {
  console.log(writeResult.val);
} else {
  console.error("Write error:", writeResult.val);
}
