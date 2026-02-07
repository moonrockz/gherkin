///|
/// A token produced by the lexer, representing a classified source line.
/// Each variant carries its Location and the relevant parsed fragments.
pub enum Token {
  FeatureLine(Location, String, String)
  RuleLine(Location, String, String)
  BackgroundLine(Location, String, String)
  ScenarioLine(Location, String, String)
  ExamplesLine(Location, String, String)
  StepLine(Location, String, KeywordType, String)
  DocStringSeparator(Location, String, String?)
  TableRow(Location, Array[String])
  TagLine(Location, Array[String])
  Comment(Location, String)
  Language(Location, String)
  Empty(Location)
  Other(Location, String)
  Eof(Location)
} derive(Show, Eq)

///|
/// Internal state tracked between lines during tokenization.
/// Gherkin is mostly stateless line-by-line except inside doc strings.
pub enum LexerState {
  Normal
  InDocString(String)
} derive(Show, Eq)

///|
/// Classify a single source line into a Token, returning the updated LexerState.
///
/// This is the core pure function of the lexer. It examines one line at a time,
/// using the current state to handle doc string regions correctly.
pub fn classify_line(
  line : String,
  line_num : Int,
  state : LexerState,
) -> (Token, LexerState) {
  match state {
    InDocString(delim) => classify_in_docstring(line, line_num, delim)
    Normal => classify_normal(line, line_num)
  }
}

///|
fn classify_in_docstring(
  line : String,
  line_num : Int,
  delim : String,
) -> (Token, LexerState) {
  let view = line[:]
  if delim == "\"\"\"" {
    lexmatch view {
      (("[[:blank:]]*" as leading) "\"\"\"" "[[:blank:]]*") => {
        let col = leading.length() + 1
        let loc : Location = { line: line_num, column: Some(col) }
        (Token::DocStringSeparator(loc, "\"\"\"", None), Normal)
      }
      _ => {
        let loc : Location = { line: line_num, column: None }
        (Token::Other(loc, line), InDocString(delim))
      }
    }
  } else {
    lexmatch view {
      (("[[:blank:]]*" as leading) "```" "[[:blank:]]*") => {
        let col = leading.length() + 1
        let loc : Location = { line: line_num, column: Some(col) }
        (Token::DocStringSeparator(loc, "```", None), Normal)
      }
      _ => {
        let loc : Location = { line: line_num, column: None }
        (Token::Other(loc, line), InDocString(delim))
      }
    }
  }
}

///|
fn classify_normal(line : String, line_num : Int) -> (Token, LexerState) {
  let view = line[:]
  lexmatch view {
    // Empty or whitespace-only line
    "[[:blank:]]*" => {
      let loc : Location = { line: line_num, column: None }
      (Token::Empty(loc), Normal)
    }
    // Language directive: # language: <lang>
    (
      ("[[:blank:]]*" as leading)
      "#"
      "[[:blank:]]*"
      "language"
      "[[:blank:]]*"
      ":"
      "[[:blank:]]*"
      ("[^[:blank:]]+" as lang)
      "[[:blank:]]*"
    ) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::Language(loc, lang.to_string()), Normal)
    }
    // Comment line: starts with optional whitespace then #
    (("[[:blank:]]*" as leading) ("#.*" as text)) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::Comment(loc, text.to_string()), Normal)
    }
    // Tag line: starts with optional whitespace then @
    (("[[:blank:]]*" as leading) ("@.*" as tag_text)) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      let tags = parse_tags(tag_text.to_string())
      (Token::TagLine(loc, tags), Normal)
    }
    // Table row: starts with optional whitespace then |
    (("[[:blank:]]*" as leading) ("[|].*" as row_text)) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      let cells = parse_table_cells(row_text.to_string())
      (Token::TableRow(loc, cells), Normal)
    }
    // Doc string: triple-quote with optional media type
    (
      ("[[:blank:]]*" as leading)
      "\"\"\""
      ("[^[:blank:]]*" as media)
      "[[:blank:]]*"
    ) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      let media_type : String? = if media.length() > 0 {
        Some(media.to_string())
      } else {
        None
      }
      (
        Token::DocStringSeparator(loc, "\"\"\"", media_type),
        InDocString("\"\"\""),
      )
    }
    // Doc string: backtick with optional media type
    (
      ("[[:blank:]]*" as leading)
      "```"
      ("[^[:blank:]]*" as media)
      "[[:blank:]]*"
    ) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      let media_type : String? = if media.length() > 0 {
        Some(media.to_string())
      } else {
        None
      }
      (Token::DocStringSeparator(loc, "```", media_type), InDocString("```"))
    }
    // Multi-word keywords (must come before single-word to take priority)
    (
      ("[[:blank:]]*" as leading)
      "Scenario Outline"
      "[[:blank:]]*"
      ":"
      "[[:blank:]]*"
      (".*" as name)
    ) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::ScenarioLine(loc, "Scenario Outline", name.to_string()), Normal)
    }
    (
      ("[[:blank:]]*" as leading)
      "Scenario Template"
      "[[:blank:]]*"
      ":"
      "[[:blank:]]*"
      (".*" as name)
    ) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::ScenarioLine(loc, "Scenario Template", name.to_string()), Normal)
    }
    // Single-word keywords
    (
      ("[[:blank:]]*" as leading)
      "Feature"
      "[[:blank:]]*"
      ":"
      "[[:blank:]]*"
      (".*" as name)
    ) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::FeatureLine(loc, "Feature", name.to_string()), Normal)
    }
    (
      ("[[:blank:]]*" as leading)
      "Rule"
      "[[:blank:]]*"
      ":"
      "[[:blank:]]*"
      (".*" as name)
    ) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::RuleLine(loc, "Rule", name.to_string()), Normal)
    }
    (
      ("[[:blank:]]*" as leading)
      "Background"
      "[[:blank:]]*"
      ":"
      "[[:blank:]]*"
      (".*" as name)
    ) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::BackgroundLine(loc, "Background", name.to_string()), Normal)
    }
    (
      ("[[:blank:]]*" as leading)
      "Scenario"
      "[[:blank:]]*"
      ":"
      "[[:blank:]]*"
      (".*" as name)
    ) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::ScenarioLine(loc, "Scenario", name.to_string()), Normal)
    }
    (
      ("[[:blank:]]*" as leading)
      "Example"
      "[[:blank:]]*"
      ":"
      "[[:blank:]]*"
      (".*" as name)
    ) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::ScenarioLine(loc, "Example", name.to_string()), Normal)
    }
    (
      ("[[:blank:]]*" as leading)
      "Examples"
      "[[:blank:]]*"
      ":"
      "[[:blank:]]*"
      (".*" as name)
    ) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::ExamplesLine(loc, "Examples", name.to_string()), Normal)
    }
    (
      ("[[:blank:]]*" as leading)
      "Scenarios"
      "[[:blank:]]*"
      ":"
      "[[:blank:]]*"
      (".*" as name)
    ) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::ExamplesLine(loc, "Scenarios", name.to_string()), Normal)
    }
    // Step keywords
    (("[[:blank:]]*" as leading) "Given " (".*" as text)) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::StepLine(loc, "Given ", Context, text.to_string()), Normal)
    }
    (("[[:blank:]]*" as leading) "When " (".*" as text)) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::StepLine(loc, "When ", Action, text.to_string()), Normal)
    }
    (("[[:blank:]]*" as leading) "Then " (".*" as text)) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::StepLine(loc, "Then ", Outcome, text.to_string()), Normal)
    }
    (("[[:blank:]]*" as leading) "And " (".*" as text)) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::StepLine(loc, "And ", Conjunction, text.to_string()), Normal)
    }
    (("[[:blank:]]*" as leading) "But " (".*" as text)) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::StepLine(loc, "But ", Conjunction, text.to_string()), Normal)
    }
    (("[[:blank:]]*" as leading) "[*] " (".*" as text)) => {
      let col = leading.length() + 1
      let loc : Location = { line: line_num, column: Some(col) }
      (Token::StepLine(loc, "* ", Unknown, text.to_string()), Normal)
    }
    // Fallback: description / other text
    _ => {
      let loc : Location = { line: line_num, column: None }
      (Token::Other(loc, line), Normal)
    }
  }
}

///|
fn parse_tags(text : String) -> Array[String] {
  let tags : Array[String] = []
  for view = text[:] {
    lexmatch view {
      ("[[:blank:]]*" ("@[^[:blank:]]+" as tag), rest) => {
        tags.push(tag.to_string())
        continue rest
      }
      _ => break tags
    }
  }
}

///|
fn parse_table_cells(text : String) -> Array[String] {
  let cells : Array[String] = []
  let parts = split_by_pipe(text)
  // Skip first part (before first |) and last part (after last |)
  for i = 1; i < parts.length() - 1; i = i + 1 {
    cells.push(trim_cell(parts[i]))
  }
  cells
}

///|
fn split_by_pipe(text : String) -> Array[String] {
  let parts : Array[String] = []
  let current : Array[Char] = []
  for c in text.iter() {
    if c == '|' {
      parts.push(String::from_array(current))
      current.clear()
    } else {
      current.push(c)
    }
  }
  parts.push(String::from_array(current))
  parts
}

///|
fn trim_cell(s : String) -> String {
  let chars = s.to_array()
  let mut start = 0
  let mut end = chars.length() - 1
  while start <= end && (chars[start] == ' ' || chars[start] == '\t') {
    start = start + 1
  }
  while end >= start && (chars[end] == ' ' || chars[end] == '\t') {
    end = end - 1
  }
  if start > end {
    ""
  } else {
    String::from_array(chars[start:end + 1].to_array())
  }
}

///|
pub fn tokenize(source : Source) -> Array[Token] {
  let tokens : Array[Token] = []
  let mut state : LexerState = Normal
  for i = 1; i <= source.line_count(); i = i + 1 {
    match source.line(i) {
      Some(line) => {
        let (tok, next_state) = classify_line(line, i, state)
        tokens.push(tok)
        state = next_state
      }
      None => ()
    }
  }
  let eof_loc : Location = { line: source.line_count() + 1, column: None }
  tokens.push(Token::Eof(eof_loc))
  tokens
}

///|
pub struct Lexer {
  priv source : Source
  priv mut line_num : Int
  priv mut state : LexerState
  priv mut done : Bool
} derive(Show)

///|
pub fn Lexer::new(source : Source) -> Lexer {
  { source, line_num: 1, state: Normal, done: false }
}

///|
/// Return the next token, advancing the lexer state.
pub fn Lexer::next(self : Lexer) -> Token? {
  while self.line_num <= self.source.line_count() {
    match self.source.line(self.line_num) {
      Some(line) => {
        let (tok, next_state) = classify_line(line, self.line_num, self.state)
        self.line_num = self.line_num + 1
        self.state = next_state
        return Some(tok)
      }
      None => self.line_num = self.line_num + 1
    }
  }
  if not(self.done) {
    self.done = true
    let eof_loc : Location = {
      line: self.source.line_count() + 1,
      column: None,
    }
    return Some(Token::Eof(eof_loc))
  }
  None
}

///|
/// Return an Iter[Token] that lazily produces tokens from the source.
pub fn Lexer::iter(self : Lexer) -> Iter[Token] {
  Iter::new(fn() { self.next() })
}
