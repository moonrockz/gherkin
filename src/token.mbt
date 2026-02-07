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
  let mut language = "en"
  for i = 1; i <= source.line_count(); i = i + 1 {
    match source.line(i) {
      Some(line) => {
        let (tok, next_state) = classify_line(line, i, state)
        // Detect language directive
        match tok {
          Language(_, lang) => language = lang
          _ => ()
        }
        tokens.push(tok)
        state = next_state
      }
      None => ()
    }
  }
  let eof_loc : Location = { line: source.line_count() + 1, column: None }
  tokens.push(Token::Eof(eof_loc))
  // If non-English, re-classify Other tokens as i18n keywords
  if language != "en" {
    reclassify_i18n(tokens, language)
  }
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

// ── i18n keyword support ──

///|
/// A keyword table for a specific language.
priv struct I18nKeywords {
  feature : Array[String]
  rule : Array[String]
  background : Array[String]
  scenario : Array[String]
  scenario_outline : Array[String]
  examples : Array[String]
  given : Array[String]
  when_ : Array[String]
  then_ : Array[String]
  and_ : Array[String]
  but_ : Array[String]
}

///|
fn get_keywords(lang : String) -> I18nKeywords? {
  match lang {
    "fr" =>
      Some({
        feature: ["Fonctionnalité"],
        rule: ["Règle"],
        background: ["Contexte"],
        scenario: ["Scénario", "Exemple"],
        scenario_outline: ["Plan du Scénario"],
        examples: ["Exemples"],
        given: ["Soit ", "Etant donné ", "Étant donné "],
        when_: ["Quand ", "Lorsque "],
        then_: ["Alors "],
        and_: ["Et "],
        but_: ["Mais "],
      })
    _ => None
  }
}

///|
/// Re-classify Other tokens as i18n keywords for non-English languages.
fn reclassify_i18n(tokens : Array[Token], lang : String) -> Unit {
  let kw = match get_keywords(lang) {
    Some(k) => k
    None => return
  }
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      Other(loc, text) => {
        let trimmed = trim_leading_whitespace(text)
        let leading_len = text.length() - trimmed.length()
        let col = leading_len + 1
        let kloc : Location = { line: loc.line, column: Some(col) }
        match try_keyword_line(trimmed, kw) {
          Some(tok) => tokens[i] = set_token_location(tok, kloc)
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
fn try_keyword_line(trimmed : String, kw : I18nKeywords) -> Token? {
  let dummy : Location = { line: 0, column: None }
  // Check structural keywords (keyword + ":" + name)
  for k in kw.feature {
    match try_match_keyword_colon(trimmed, k) {
      Some(name) => return Some(Token::FeatureLine(dummy, k, name))
      None => ()
    }
  }
  for k in kw.rule {
    match try_match_keyword_colon(trimmed, k) {
      Some(name) => return Some(Token::RuleLine(dummy, k, name))
      None => ()
    }
  }
  for k in kw.background {
    match try_match_keyword_colon(trimmed, k) {
      Some(name) => return Some(Token::BackgroundLine(dummy, k, name))
      None => ()
    }
  }
  // Scenario outline before scenario (longer match first)
  for k in kw.scenario_outline {
    match try_match_keyword_colon(trimmed, k) {
      Some(name) => return Some(Token::ScenarioLine(dummy, k, name))
      None => ()
    }
  }
  for k in kw.scenario {
    match try_match_keyword_colon(trimmed, k) {
      Some(name) => return Some(Token::ScenarioLine(dummy, k, name))
      None => ()
    }
  }
  for k in kw.examples {
    match try_match_keyword_colon(trimmed, k) {
      Some(name) => return Some(Token::ExamplesLine(dummy, k, name))
      None => ()
    }
  }
  // Check step keywords (keyword includes trailing space)
  for k in kw.given {
    match try_match_step(trimmed, k) {
      Some(text) => return Some(Token::StepLine(dummy, k, Context, text))
      None => ()
    }
  }
  for k in kw.when_ {
    match try_match_step(trimmed, k) {
      Some(text) => return Some(Token::StepLine(dummy, k, Action, text))
      None => ()
    }
  }
  for k in kw.then_ {
    match try_match_step(trimmed, k) {
      Some(text) => return Some(Token::StepLine(dummy, k, Outcome, text))
      None => ()
    }
  }
  for k in kw.and_ {
    match try_match_step(trimmed, k) {
      Some(text) => return Some(Token::StepLine(dummy, k, Conjunction, text))
      None => ()
    }
  }
  for k in kw.but_ {
    match try_match_step(trimmed, k) {
      Some(text) => return Some(Token::StepLine(dummy, k, Conjunction, text))
      None => ()
    }
  }
  None
}

///|
/// Check if trimmed text starts with keyword followed by ":" and extract name.
fn try_match_keyword_colon(text : String, keyword : String) -> String? {
  if text.length() < keyword.length() {
    return None
  }
  let chars = text.to_array()
  let kw_chars = keyword.to_array()
  for j = 0; j < kw_chars.length(); j = j + 1 {
    if chars[j] != kw_chars[j] {
      return None
    }
  }
  // After keyword, skip whitespace then expect ':'
  let mut pos = kw_chars.length()
  while pos < chars.length() && (chars[pos] == ' ' || chars[pos] == '\t') {
    pos = pos + 1
  }
  if pos >= chars.length() || chars[pos] != ':' {
    return None
  }
  pos = pos + 1
  // Skip whitespace after ':'
  while pos < chars.length() && (chars[pos] == ' ' || chars[pos] == '\t') {
    pos = pos + 1
  }
  Some(String::from_array(chars[pos:].to_array()))
}

///|
/// Check if trimmed text starts with a step keyword (which includes trailing space).
fn try_match_step(text : String, keyword : String) -> String? {
  if text.length() < keyword.length() {
    return None
  }
  let chars = text.to_array()
  let kw_chars = keyword.to_array()
  for j = 0; j < kw_chars.length(); j = j + 1 {
    if chars[j] != kw_chars[j] {
      return None
    }
  }
  Some(String::from_array(chars[kw_chars.length():].to_array()))
}

///|
fn trim_leading_whitespace(text : String) -> String {
  let chars = text.to_array()
  let mut start = 0
  while start < chars.length() && (chars[start] == ' ' || chars[start] == '\t') {
    start = start + 1
  }
  if start == 0 {
    text
  } else {
    String::from_array(chars[start:].to_array())
  }
}

///|
fn set_token_location(tok : Token, loc : Location) -> Token {
  match tok {
    FeatureLine(_, kw, name) => FeatureLine(loc, kw, name)
    RuleLine(_, kw, name) => RuleLine(loc, kw, name)
    BackgroundLine(_, kw, name) => BackgroundLine(loc, kw, name)
    ScenarioLine(_, kw, name) => ScenarioLine(loc, kw, name)
    ExamplesLine(_, kw, name) => ExamplesLine(loc, kw, name)
    StepLine(_, kw, kt, text) => StepLine(loc, kw, kt, text)
    other => other
  }
}
