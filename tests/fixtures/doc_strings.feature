Feature: Doc Strings

  Scenario: A step with a doc string
    Given the following text:
      """
      This is a doc string.
      It can span multiple lines.
      """
    When I process the text
    Then it should be captured
