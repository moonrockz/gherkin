///|
/// A token produced by the lexer, representing a classified source line.
/// Each variant carries its Location and the relevant parsed fragments.
pub enum Token {
  FeatureLine(Location, String, String)
  RuleLine(Location, String, String)
  BackgroundLine(Location, String, String)
  ScenarioLine(Location, String, String, ScenarioKind)
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
} derive(Debug, Eq, ToJson)

///|
/// Internal state tracked between lines during tokenization.
/// Gherkin is mostly stateless line-by-line except inside doc strings.
pub enum LexerState {
  Normal
  InDocString(String)
} derive(Debug, Eq, ToJson)

///|
/// Classify a single source line into a Token, returning the updated LexerState.
///
/// This is the core pure function of the lexer. It examines one line at a time,
/// using the current state to handle doc string regions correctly.
/// The `language` parameter selects the keyword table for matching Gherkin
/// keywords (Feature, Scenario, Given, etc.). Defaults to English ("en").
pub fn classify_line(
  line : String,
  line_num : Int,
  state : LexerState,
  language? : String = "en",
) -> (Token, LexerState) {
  match state {
    InDocString(delim) => classify_in_docstring(line, line_num, delim)
    Normal => classify_normal(line, line_num, get_keywords(language))
  }
}

///|
/// Regex matching a doc string closing line (triple quotes, blanks around it).
const RE_DOCSTRING_END_QUOTES : Regex = re"^([[:blank:]]*)\"\"\"[[:blank:]]*$"

///|
/// Regex matching a doc string closing line (backticks, blanks around it).
const RE_DOCSTRING_END_BACKTICK : Regex = re"^([[:blank:]]*)```[[:blank:]]*$"

///|
/// Regex matching a doc string opening line with an optional media type.
const RE_DOCSTRING_START_QUOTES : Regex = re"^([[:blank:]]*)\"\"\"([^[:blank:]]*)[[:blank:]]*$"

///|
/// Regex matching a backtick doc string opening line with an optional media type.
const RE_DOCSTRING_START_BACKTICK : Regex = re"^([[:blank:]]*)```([^[:blank:]]*)[[:blank:]]*$"

///|
/// Regex matching a `# language: <lang>` directive line.
const RE_LANGUAGE_DIRECTIVE : Regex = re"^#[[:blank:]]*language[[:blank:]]*:[[:blank:]]*([^[:blank:]]+)[[:blank:]]*$"

///|
fn classify_in_docstring(
  line : String,
  line_num : Int,
  delim : String,
) -> (Token, LexerState) {
  let view : StringView = line[:]
  let closing = if delim == "\"\"\"" {
    RE_DOCSTRING_END_QUOTES.execute(view)
  } else {
    RE_DOCSTRING_END_BACKTICK.execute(view)
  }
  match closing {
    Some(m) => {
      let leading_len = match m.group(1) {
        Some(leading) => leading.length()
        None => 0
      }
      let col = leading_len + 1
      let loc : Location = { line: line_num, column: Some(col), }
      (Token::DocStringSeparator(loc, delim, None), Normal)
    }
    None => {
      let loc : Location = { line: line_num, column: None, }
      (Token::Other(loc, line), InDocString(delim))
    }
  }
}

///|
fn classify_normal(
  line : String,
  line_num : Int,
  keywords : I18nKeywords?,
) -> (Token, LexerState) {
  let view : StringView = line[:]
  let trimmed = view.trim_start(chars=" \t")
  // Empty or whitespace-only line
  if trimmed.is_empty() {
    let loc : Location = { line: line_num, column: None, }
    return (Token::Empty(loc), Normal)
  }
  let col = view.length() - trimmed.length() + 1
  let loc : Location = { line: line_num, column: Some(col), }
  // Language directive: # language: <lang>, otherwise a plain comment
  if trimmed.has_prefix("#") {
    if RE_LANGUAGE_DIRECTIVE.execute(trimmed) is Some(m) &&
      m.group(1) is Some(lang) {
      return (Token::Language(loc, lang.to_owned()), Normal)
    }
    return (Token::Comment(loc, trimmed.to_owned()), Normal)
  }
  // Tag line: starts with optional whitespace then @
  if trimmed.has_prefix("@") {
    let tags = parse_tags(trimmed.to_owned())
    return (Token::TagLine(loc, tags), Normal)
  }
  // Table row: starts with optional whitespace then |
  if trimmed.has_prefix("|") {
    let cells = parse_table_cells(trimmed.to_owned())
    return (Token::TableRow(loc, cells), Normal)
  }
  // Doc string: triple-quote with optional media type
  if RE_DOCSTRING_START_QUOTES.execute(view) is Some(m) {
    let media_type : String? = match m.group(2) {
      Some(media) =>
        if media.is_empty() {
          None
        } else {
          Some(media.to_owned())
        }
      None => None
    }
    return (
      Token::DocStringSeparator(loc, "\"\"\"", media_type),
      InDocString("\"\"\""),
    )
  }
  // Doc string: backtick with optional media type
  if RE_DOCSTRING_START_BACKTICK.execute(view) is Some(m) {
    let media_type : String? = match m.group(2) {
      Some(media) =>
        if media.is_empty() {
          None
        } else {
          Some(media.to_owned())
        }
      None => None
    }
    return (
      Token::DocStringSeparator(loc, "```", media_type),
      InDocString("```"),
    )
  }
  // Fallback: try keyword matching, then description/other text
  match keywords {
    Some(kw) => {
      let kw_text = trim_leading_whitespace(line)
      match try_keyword_line(kw_text, kw) {
        Some(tok) => (set_token_location(tok, loc), Normal)
        None => {
          let oloc : Location = { line: line_num, column: None, }
          (Token::Other(oloc, line), Normal)
        }
      }
    }
    None => {
      let oloc : Location = { line: line_num, column: None, }
      (Token::Other(oloc, line), Normal)
    }
  }
}

///|
fn parse_tags(text : String) -> Array[String] {
  let tags : Array[String] = []
  for view = text[:] {
    lexmatch view {
      (re"^[[:blank:]]*@[^[:blank:]]+" as matched, after=rest) => {
        tags.push(matched.trim_start(chars=" \t").to_owned())
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
    String::from_array(chars[start:end + 1].to_owned())
  }
}

///|
pub fn tokenize(source : Source) -> Array[Token] {
  match source.uri() {
    Some(uri) if uri.has_suffix(".feature.md") =>
      return tokenize_markdown(source)
    _ => ()
  }
  let tokens : Array[Token] = []
  let mut state : LexerState = Normal
  let mut language = "en"
  for i = 1; i <= source.line_count(); i = i + 1 {
    match source.line(i) {
      Some(line) => {
        let (tok, next_state) = classify_line(line, i, state, language~)
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
  let eof_loc : Location = { line: source.line_count() + 1, column: None, }
  tokens.push(Token::Eof(eof_loc))
  tokens
}

///|
pub struct Lexer {
  priv source : Source
  priv markdown_tokens : Array[Token]?
  priv mut markdown_pos : Int
  priv mut line_num : Int
  priv mut state : LexerState
  priv mut done : Bool
  priv mut language : String
} derive(Debug)

///|
pub fn Lexer::new(source : Source) -> Lexer {
  let markdown_tokens = match source.uri() {
    Some(uri) if uri.has_suffix(".feature.md") =>
      Some(tokenize_markdown(source))
    _ => None
  }
  {
    source,
    markdown_tokens,
    markdown_pos: 0,
    line_num: 1,
    state: Normal,
    done: false,
    language: "en",
  }
}

///|
/// Return the next token, advancing the lexer state.
pub fn Lexer::next(self : Lexer) -> Token? {
  match self.markdown_tokens {
    Some(tokens) => {
      if self.markdown_pos < tokens.length() {
        let token = tokens[self.markdown_pos]
        self.markdown_pos = self.markdown_pos + 1
        return Some(token)
      }
      return None
    }
    None => ()
  }
  while self.line_num <= self.source.line_count() {
    match self.source.line(self.line_num) {
      Some(line) => {
        let (tok, next_state) = classify_line(
          line,
          self.line_num,
          self.state,
          language=self.language,
        )
        self.line_num = self.line_num + 1
        self.state = next_state
        match tok {
          Language(_, lang) => self.language = lang
          _ => ()
        }
        return Some(tok)
      }
      None => self.line_num = self.line_num + 1
    }
  }
  if !self.done {
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
    "en" =>
      Some({
        feature: ["Feature"],
        rule: ["Rule"],
        background: ["Background"],
        scenario: ["Scenario", "Example"],
        scenario_outline: ["Scenario Outline", "Scenario Template"],
        examples: ["Examples", "Scenarios"],
        given: ["Given "],
        when_: ["When "],
        then_: ["Then "],
        and_: ["And "],
        but_: ["But "],
      })
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
fn try_keyword_line(trimmed : String, kw : I18nKeywords) -> Token? {
  let dummy : Location = { line: 0, column: None, }
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
      Some(name) =>
        return Some(Token::ScenarioLine(dummy, k, name, ScenarioOutline))
      None => ()
    }
  }
  for k in kw.scenario {
    match try_match_keyword_colon(trimmed, k) {
      Some(name) => return Some(Token::ScenarioLine(dummy, k, name, Scenario))
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
  // Universal step keyword: "* " (language-independent)
  match try_match_step(trimmed, "* ") {
    Some(text) => return Some(Token::StepLine(dummy, "* ", Unknown, text))
    None => ()
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
  Some(String::from_array(chars[pos:].to_owned()))
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
  Some(String::from_array(chars[kw_chars.length():].to_owned()))
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
    String::from_array(chars[start:].to_owned())
  }
}

///|
fn set_token_location(tok : Token, loc : Location) -> Token {
  match tok {
    FeatureLine(_, kw, name) => FeatureLine(loc, kw, name)
    RuleLine(_, kw, name) => RuleLine(loc, kw, name)
    BackgroundLine(_, kw, name) => BackgroundLine(loc, kw, name)
    ScenarioLine(_, kw, name, kind) => ScenarioLine(loc, kw, name, kind)
    ExamplesLine(_, kw, name) => ExamplesLine(loc, kw, name)
    StepLine(_, kw, kt, text) => StepLine(loc, kw, kt, text)
    other => other
  }
}

///|
pub extend Token with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Token with Eq::{not_equal, equal}

///|
pub extend Token with ToJson::{to_json}

///|
pub extend LexerState with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend LexerState with Eq::{not_equal, equal}

///|
pub extend LexerState with ToJson::{to_json}

///|
pub extend Lexer with @moonbitlang/core/debug.Debug::{to_repr}
