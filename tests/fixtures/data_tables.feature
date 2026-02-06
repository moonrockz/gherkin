Feature: Data Tables

  Scenario: A step with a data table
    Given the following users exist:
      | name  | email          | role  |
      | Alice | alice@test.com | admin |
      | Bob   | bob@test.com   | user  |
    When I list all users
    Then I should see 2 users
