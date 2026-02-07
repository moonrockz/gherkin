@integration
Feature: Complex feature
  Background:
    Given a base setup

  Rule: Admin access
    @admin
    Scenario: Admin can manage
      Given an admin user
      When they access management
      Then they see the admin panel

  Rule: User access
    Scenario Outline: User permissions
      Given a <role> user
      When they access <page>
      Then they see <result>
      Examples:
        | role  | page    | result       |
        | user  | home    | dashboard    |
        | guest | home    | login prompt |
