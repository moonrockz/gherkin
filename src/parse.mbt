///|
/// Parse a Gherkin document from a `Source`.
pub fn parse(source : Source) -> GherkinDocument raise ParseError {
  let tokens = tokenize(source)
  let parser = Parser::new(tokens, source)
  parser.parse_document()
}

///|
priv struct Parser {
  tokens : Array[Token]
  source : Source
  mut pos : Int
  mut id_counter : Int
} derive(Show)

///|
fn Parser::new(tokens : Array[Token], source : Source) -> Parser {
  { tokens, source, pos: 0, id_counter: 0 }
}

///|
fn Parser::next_id(self : Parser) -> String {
  self.id_counter = self.id_counter + 1
  self.id_counter.to_string()
}

///|
fn Parser::peek(self : Parser) -> Token {
  if self.pos < self.tokens.length() {
    self.tokens[self.pos]
  } else {
    Token::Eof({ line: 0, column: None })
  }
}

///|
fn Parser::advance(self : Parser) -> Token {
  let tok = self.peek()
  if self.pos < self.tokens.length() {
    self.pos = self.pos + 1
  }
  tok
}

///|
fn Parser::parse_document(self : Parser) -> GherkinDocument raise ParseError {
  let comments : Array[Comment] = []
  // Skip leading empty lines, comments, and language directives
  let mut language = "en"
  while not(self.at_eof()) {
    match self.peek() {
      Empty(_) => self.advance() |> ignore
      Comment(loc, text) => {
        comments.push({ location: loc, text })
        self.advance() |> ignore
      }
      Language(_, lang) => {
        language = lang
        self.advance() |> ignore
      }
      _ => break
    }
  }
  // Collect feature-level tags
  let feature_tags : Array[Tag] = []
  while not(self.at_eof()) {
    match self.peek() {
      TagLine(loc, tag_names) => {
        for t in tag_names {
          feature_tags.push({ location: loc, name: t, id: self.next_id() })
        }
        self.advance() |> ignore
      }
      _ => break
    }
  }
  let feature : Feature? = match self.peek() {
    FeatureLine(_, _, _) =>
      Some(self.parse_feature(language, comments, feature_tags))
    Eof(_) => None
    other => {
      let loc = token_location(other)
      let hint = self.source_line_hint(loc)
      raise UnexpectedToken(
        message="expected 'Feature:' keyword or end of file at line \{loc.line}, but found \{token_name(other)}\{hint}",
        location=loc,
      )
    }
  }
  { source: self.source, feature, comments }
}

///|
fn Parser::parse_feature(
  self : Parser,
  language : String,
  comments : Array[Comment],
  tags : Array[Tag],
) -> Feature raise ParseError {
  // Consume FeatureLine
  let (loc, keyword, name) = match self.advance() {
    FeatureLine(loc, kw, name) => (loc, kw, name)
    other => {
      let loc = token_location(other)
      let hint = self.source_line_hint(loc)
      raise UnexpectedToken(
        message="expected 'Feature:' keyword at line \{loc.line}, but found \{token_name(other)}\{hint}",
        location=loc,
      )
    }
  }
  // Collect description lines and children
  let description_lines : Array[String] = []
  let children : Array[FeatureChild] = []
  while not(self.at_eof()) {
    match self.peek() {
      Empty(_) => {
        // Empty lines in description area are kept as blank lines
        if children.is_empty() {
          description_lines.push("")
        }
        self.advance() |> ignore
      }
      Comment(cloc, text) => {
        comments.push({ location: cloc, text })
        self.advance() |> ignore
      }
      Other(_, text) => {
        if children.is_empty() {
          description_lines.push(trim_description(text))
        }
        self.advance() |> ignore
      }
      ScenarioLine(_, _, _) => {
        let scenario = self.parse_scenario()
        children.push(FeatureChild::Scenario(scenario))
      }
      BackgroundLine(_, _, _) => {
        let bg = self.parse_background()
        children.push(FeatureChild::Background(bg))
      }
      RuleLine(_, _, _) => {
        let rule = self.parse_rule(comments)
        children.push(FeatureChild::Rule(rule))
      }
      TagLine(_, _) => {
        // Tags before a scenario
        let scenario = self.parse_scenario()
        children.push(FeatureChild::Scenario(scenario))
      }
      Eof(_) => break
      _ => self.advance() |> ignore
    }
  }
  let description = build_description(description_lines)
  { location: loc, tags, language, keyword, name, description, children }
}

///|
fn Parser::parse_scenario(self : Parser) -> Scenario raise ParseError {
  // Collect tags if present
  let tags : Array[Tag] = []
  while not(self.at_eof()) {
    match self.peek() {
      TagLine(loc, tag_names) => {
        for t in tag_names {
          tags.push({ location: loc, name: t, id: self.next_id() })
        }
        self.advance() |> ignore
      }
      _ => break
    }
  }
  // Consume ScenarioLine
  let (loc, keyword, name) = match self.advance() {
    ScenarioLine(loc, kw, name) => (loc, kw, name)
    other => {
      let loc = token_location(other)
      let hint = self.source_line_hint(loc)
      raise UnexpectedToken(
        message="expected 'Scenario:' keyword at line \{loc.line}, but found \{token_name(other)}\{hint}",
        location=loc,
      )
    }
  }
  // Collect description and steps
  let description_lines : Array[String] = []
  let steps : Array[Step] = []
  let examples : Array[Examples] = []
  while not(self.at_eof()) {
    match self.peek() {
      Empty(_) => self.advance() |> ignore
      Other(_, text) => {
        if steps.is_empty() {
          description_lines.push(trim_description(text))
        }
        self.advance() |> ignore
      }
      StepLine(_, _, _, _) => {
        let step = self.parse_step()
        steps.push(step)
      }
      Comment(_, _) => self.advance() |> ignore
      ExamplesLine(_, _, _) | TagLine(_, _) => {
        let example = self.parse_examples()
        examples.push(example)
      }
      // Stop when we hit another structural element
      ScenarioLine(_, _, _)
      | BackgroundLine(_, _, _)
      | RuleLine(_, _, _)
      | FeatureLine(_, _, _)
      | Eof(_) => break
      _ => self.advance() |> ignore
    }
  }
  let description = build_description(description_lines)
  {
    location: loc,
    tags,
    keyword,
    name,
    description,
    id: self.next_id(),
    steps,
    examples,
  }
}

///|
fn Parser::parse_step(self : Parser) -> Step raise ParseError {
  match self.advance() {
    StepLine(loc, keyword, keyword_type, text) => {
      // Check for step argument (doc string or data table)
      let argument : StepArgument? = match self.peek() {
        DocStringSeparator(_, _, _) =>
          Some(StepArgument::DocString(self.parse_doc_string()))
        TableRow(_, _) => Some(StepArgument::DataTable(self.parse_data_table()))
        _ => None
      }
      {
        location: loc,
        keyword,
        keyword_type,
        text,
        id: self.next_id(),
        argument,
      }
    }
    other => {
      let loc = token_location(other)
      let hint = self.source_line_hint(loc)
      raise UnexpectedToken(
        message="expected a step keyword (Given/When/Then/And/But/*) at line \{loc.line}, but found \{token_name(other)}\{hint}",
        location=loc,
      )
    }
  }
}

///|
fn Parser::parse_examples(self : Parser) -> Examples raise ParseError {
  // Collect tags if present before ExamplesLine
  let tags : Array[Tag] = []
  while not(self.at_eof()) {
    match self.peek() {
      TagLine(loc, tag_names) => {
        for t in tag_names {
          tags.push({ location: loc, name: t, id: self.next_id() })
        }
        self.advance() |> ignore
      }
      _ => break
    }
  }
  // Consume ExamplesLine
  let (loc, keyword, name) = match self.advance() {
    ExamplesLine(loc, kw, name) => (loc, kw, name)
    other => {
      let loc = token_location(other)
      let hint = self.source_line_hint(loc)
      raise UnexpectedToken(
        message="expected 'Examples:' keyword at line \{loc.line}, but found \{token_name(other)}\{hint}",
        location=loc,
      )
    }
  }
  // Collect description lines
  let description_lines : Array[String] = []
  while not(self.at_eof()) {
    match self.peek() {
      Empty(_) => self.advance() |> ignore
      Other(_, text) => {
        description_lines.push(trim_description(text))
        self.advance() |> ignore
      }
      _ => break
    }
  }
  // Parse table: first row is header, rest are body
  let table_header : TableRow? = match self.peek() {
    TableRow(rloc, cells) => {
      let table_cells : Array[TableCell] = []
      for i, cell in cells {
        table_cells.push({
          location: { line: rloc.line, column: Some(i + 1) },
          value: cell,
        })
      }
      self.advance() |> ignore
      Some({ location: rloc, id: self.next_id(), cells: table_cells })
    }
    _ => None
  }
  let table_body : Array[TableRow] = []
  while not(self.at_eof()) {
    match self.peek() {
      TableRow(rloc, cells) => {
        let table_cells : Array[TableCell] = []
        for i, cell in cells {
          table_cells.push({
            location: { line: rloc.line, column: Some(i + 1) },
            value: cell,
          })
        }
        table_body.push({
          location: rloc,
          id: self.next_id(),
          cells: table_cells,
        })
        self.advance() |> ignore
      }
      _ => break
    }
  }
  let description = build_description(description_lines)
  {
    location: loc,
    tags,
    keyword,
    name,
    description,
    id: self.next_id(),
    table_header,
    table_body,
  }
}

///|
fn Parser::parse_doc_string(self : Parser) -> DocString raise ParseError {
  let (loc, delimiter, media_type) = match self.advance() {
    DocStringSeparator(loc, delim, mt) => (loc, delim, mt)
    other => {
      let loc = token_location(other)
      let hint = self.source_line_hint(loc)
      raise UnexpectedToken(
        message="expected doc string delimiter at line \{loc.line}, but found \{token_name(other)}\{hint}",
        location=loc,
      )
    }
  }
  let content_lines : Array[String] = []
  while not(self.at_eof()) {
    match self.peek() {
      DocStringSeparator(_, _, _) => {
        self.advance() |> ignore
        break
      }
      Other(_, text) => {
        content_lines.push(text)
        self.advance() |> ignore
      }
      Empty(_) => {
        content_lines.push("")
        self.advance() |> ignore
      }
      _ =>
        // Unexpected token inside doc string — treat as content
        self.advance() |> ignore
    }
  }
  // Dedent content: find minimum indentation and strip it
  let content = dedent_doc_string(content_lines, loc)
  { location: loc, media_type, content, delimiter }
}

///|
fn dedent_doc_string(lines : Array[String], opener_loc : Location) -> String {
  // The indent level is determined by the opening delimiter's column
  let indent = match opener_loc.column {
    Some(col) => col - 1
    None => 0
  }
  let result : Array[String] = []
  for line in lines {
    if line.length() == 0 {
      result.push("")
    } else {
      // Strip up to `indent` characters of leading whitespace
      let chars = line.to_array()
      let mut start = 0
      while start < indent &&
            start < chars.length() &&
            (chars[start] == ' ' || chars[start] == '\t') {
        start = start + 1
      }
      result.push(String::from_array(chars[start:].to_array()))
    }
  }
  result.join("\n")
}

///|
fn Parser::parse_data_table(self : Parser) -> DataTable raise ParseError {
  let rows : Array[TableRow] = []
  let mut expected_cols = -1
  while not(self.at_eof()) {
    match self.peek() {
      TableRow(loc, cells) => {
        let table_cells : Array[TableCell] = []
        for i, cell in cells {
          table_cells.push({
            location: { line: loc.line, column: Some(i + 1) },
            value: cell,
          })
        }
        if expected_cols < 0 {
          expected_cols = cells.length()
        } else if cells.length() != expected_cols {
          let hint = self.source_line_hint(loc)
          raise InconsistentTableCells(
            message="inconsistent cell count at line \{loc.line}: expected \{expected_cols} cells, but found \{cells.length()}\{hint}",
            location=loc,
          )
        }
        rows.push({ location: loc, id: self.next_id(), cells: table_cells })
        self.advance() |> ignore
      }
      _ => break
    }
  }
  let table_loc = if rows.length() > 0 {
    rows[0].location
  } else {
    { line: 0, column: None }
  }
  { location: table_loc, rows }
}

///|
fn Parser::parse_background(self : Parser) -> Background raise ParseError {
  let (loc, keyword, name) = match self.advance() {
    BackgroundLine(loc, kw, name) => (loc, kw, name)
    other => {
      let loc = token_location(other)
      let hint = self.source_line_hint(loc)
      raise UnexpectedToken(
        message="expected 'Background:' keyword at line \{loc.line}, but found \{token_name(other)}\{hint}",
        location=loc,
      )
    }
  }
  let description_lines : Array[String] = []
  let steps : Array[Step] = []
  while not(self.at_eof()) {
    match self.peek() {
      Empty(_) => self.advance() |> ignore
      Other(_, text) => {
        if steps.is_empty() {
          description_lines.push(trim_description(text))
        }
        self.advance() |> ignore
      }
      StepLine(_, _, _, _) => {
        let step = self.parse_step()
        steps.push(step)
      }
      Comment(_, _) => self.advance() |> ignore
      _ => break
    }
  }
  let description = build_description(description_lines)
  { location: loc, keyword, name, description, id: self.next_id(), steps }
}

///|
fn Parser::parse_rule(
  self : Parser,
  _comments : Array[Comment],
) -> Rule raise ParseError {
  let (loc, keyword, name) = match self.advance() {
    RuleLine(loc, kw, name) => (loc, kw, name)
    other => {
      let loc = token_location(other)
      let hint = self.source_line_hint(loc)
      raise UnexpectedToken(
        message="expected 'Rule:' keyword at line \{loc.line}, but found \{token_name(other)}\{hint}",
        location=loc,
      )
    }
  }
  let description_lines : Array[String] = []
  let children : Array[RuleChild] = []
  while not(self.at_eof()) {
    match self.peek() {
      Empty(_) => self.advance() |> ignore
      Other(_, text) => {
        if children.is_empty() {
          description_lines.push(trim_description(text))
        }
        self.advance() |> ignore
      }
      Comment(_, _) => self.advance() |> ignore
      ScenarioLine(_, _, _) | TagLine(_, _) => {
        let scenario = self.parse_scenario()
        children.push(RuleChild::Scenario(scenario))
      }
      BackgroundLine(_, _, _) => {
        let bg = self.parse_background()
        children.push(RuleChild::Background(bg))
      }
      // Stop at feature-level boundaries
      FeatureLine(_, _, _) | RuleLine(_, _, _) | Eof(_) => break
      _ => self.advance() |> ignore
    }
  }
  let description = build_description(description_lines)
  {
    location: loc,
    tags: [],
    keyword,
    name,
    description,
    id: self.next_id(),
    children,
  }
}

///|
fn Parser::at_eof(self : Parser) -> Bool {
  match self.peek() {
    Eof(_) => true
    _ => self.pos >= self.tokens.length()
  }
}

///|
fn token_location(tok : Token) -> Location {
  match tok {
    FeatureLine(loc, _, _) => loc
    RuleLine(loc, _, _) => loc
    BackgroundLine(loc, _, _) => loc
    ScenarioLine(loc, _, _) => loc
    ExamplesLine(loc, _, _) => loc
    StepLine(loc, _, _, _) => loc
    DocStringSeparator(loc, _, _) => loc
    TableRow(loc, _) => loc
    TagLine(loc, _) => loc
    Comment(loc, _) => loc
    Language(loc, _) => loc
    Empty(loc) => loc
    Other(loc, _) => loc
    Eof(loc) => loc
  }
}

///|
fn token_name(tok : Token) -> String {
  match tok {
    FeatureLine(_, kw, _) => "'\{kw}:' keyword"
    RuleLine(_, kw, _) => "'\{kw}:' keyword"
    BackgroundLine(_, kw, _) => "'\{kw}:' keyword"
    ScenarioLine(_, kw, _) => "'\{kw}:' keyword"
    ExamplesLine(_, kw, _) => "'\{kw}:' keyword"
    StepLine(_, kw, _, _) => "'\{kw}' step"
    DocStringSeparator(_, delim, _) => "doc string delimiter (\{delim})"
    TableRow(_, _) => "table row"
    TagLine(_, _) => "tag line"
    Comment(_, _) => "comment"
    Language(_, lang) => "language directive (\{lang})"
    Empty(_) => "empty line"
    Other(_, _) => "text"
    Eof(_) => "end of file"
  }
}

///|
fn Parser::source_line_hint(self : Parser, loc : Location) -> String {
  match self.source.line(loc.line) {
    Some(line) => {
      let trimmed = trim_description(line)
      if trimmed.length() > 0 {
        "\n  |\n  | \{line}\n  |"
      } else {
        ""
      }
    }
    None => ""
  }
}

///|
fn trim_description(text : String) -> String {
  let chars = text.to_array()
  let mut start = 0
  while start < chars.length() && (chars[start] == ' ' || chars[start] == '\t') {
    start = start + 1
  }
  if start >= chars.length() {
    ""
  } else {
    String::from_array(chars[start:].to_array())
  }
}

///|
fn build_description(lines : Array[String]) -> String {
  // Trim trailing empty lines
  let mut end = lines.length()
  while end > 0 && lines[end - 1] == "" {
    end = end - 1
  }
  if end == 0 {
    ""
  } else {
    let result : Array[String] = []
    for i = 0; i < end; i = i + 1 {
      result.push(lines[i])
    }
    result.join("\n")
  }
}
