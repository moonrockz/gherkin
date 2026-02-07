Feature: Scenario kinds
  Scenario: Regular scenario
    Given a user

  Scenario Outline: Parameterized scenario
    Given a <role> user
    Examples:
      | role  |
      | admin |
      | guest |
