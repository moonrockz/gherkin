`@library`
# Feature: Keyword kinds

## Background: Setup

* Given a prepared cart

## Scenario: Checkout

- When the customer pays
* And a receipt is created
- Then the order is complete
* But no duplicate order exists
