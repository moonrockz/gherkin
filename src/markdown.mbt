///|
/// Tokenize Markdown with Gherkin from its Markdown block structure.
/// Only headings and list items can introduce Gherkin keywords.
fn tokenize_markdown(source : Source) -> Array[Token] {
  let tokens : Array[Token] = []
  for i = 1; i <= source.line_count(); i = i + 1 {
    tokens.push(Token::Empty({ line: i, column: None, }))
  }
  let markdown = @markdown.parse(source.content()).document
  let mut language = "en"
  for block in markdown.children {
    match block {
      Heading(span~, ..) => {
        let line = markdown_line_number(source, span.from)
        if source.line(line) is Some(text) {
          let (directive, _) = classify_line(text, line, Normal)
          match directive {
            Language(_, lang) => {
              tokens[line - 1] = directive
              language = lang
              continue
            }
            _ => ()
          }
          let trimmed = text[:].trim_start(chars=" \t")
          let mut prefix = 0
          while prefix < trimmed.length() && trimmed[prefix] == '#' {
            prefix = prefix + 1
          }
          if prefix > 0 && prefix < trimmed.length() && trimmed[prefix] == ' ' {
            let content = trimmed[prefix + 1:].to_owned()
            let (token, _) = classify_line(content, line, Normal, language~)
            match token {
              FeatureLine(_, _, _)
              | RuleLine(_, _, _)
              | BackgroundLine(_, _, _)
              | ScenarioLine(_, _, _, _)
              | ExamplesLine(_, _, _) =>
                tokens[line - 1] = set_token_location(token, {
                  line,
                  column: Some(text.length() - trimmed.length() + prefix + 2),
                })
              _ => ()
            }
          }
        }
      }
      BulletList(items~, ..) =>
        for item in items {
          let line = markdown_line_number(source, item.span.from)
          let mut is_step = false
          if source.line(line) is Some(text) {
            let trimmed = text[:].trim_start(chars=" \t")
            if trimmed.length() > 2 &&
              (trimmed[0] == '-' || trimmed[0] == '*') &&
              trimmed[1] == ' ' {
              let content = trimmed[2:].to_owned()
              let (token, _) = classify_line(content, line, Normal, language~)
              match token {
                StepLine(_, _, _, _) => {
                  tokens[line - 1] = set_token_location(token, {
                    line,
                    column: Some(text.length() - trimmed.length() + 3),
                  })
                  is_step = true
                }
                _ => ()
              }
            }
          }
          if is_step {
            for child in item.children {
              match child {
                Table(span~, ..) => mark_markdown_table(source, tokens, span)
                FencedCode(span~, info~, fence_marker~, fence_length~, ..) =>
                  mark_markdown_fence(
                    source, tokens, span, info, fence_marker, fence_length,
                  )
                _ => ()
              }
            }
            mark_markdown_list_tables(source, tokens, item.span)
          }
        }
      Table(span~, ..) => mark_markdown_table(source, tokens, span)
      FencedCode(span~, info~, fence_marker~, fence_length~, ..) => {
        let line = markdown_line_number(source, span.from)
        if line > 1 {
          match tokens[line - 2] {
            StepLine(_, _, _, _) =>
              mark_markdown_fence(
                source, tokens, span, info, fence_marker, fence_length,
              )
            _ => ()
          }
        }
      }
      Paragraph(children~, span~, ..) => {
        let line = markdown_line_number(source, span.from)
        let tags : Array[String] = []
        let mut valid = true
        for inline in children {
          match inline {
            @markdown.Inline::Code(content~, backtick_count~, ..) =>
              if backtick_count == 1 &&
                content.has_prefix("@") &&
                content.length() > 1 {
                tags.push(content)
              } else {
                valid = false
              }
            @markdown.Inline::Text(content~, ..) =>
              if !content[:].trim().is_empty() {
                valid = false
              }
            _ => valid = false
          }
        }
        if valid && !tags.is_empty() {
          tokens[line - 1] = Token::TagLine({ line, column: Some(1), }, tags)
        }
      }
      _ => ()
    }
  }
  for token in tokens {
    match token {
      ExamplesLine(loc, _, _) =>
        for line = loc.line + 1; line < source.line_count(); line = line + 1 {
          match tokens[line - 1] {
            Empty(_) | TableRow(_, _) => ()
            _ => break
          }
          let header = source.line(line).unwrap_or("")
          let delimiter = source.line(line + 1).unwrap_or("")
          if is_markdown_table_row(header) &&
            is_markdown_table_row(delimiter) &&
            markdown_table_delimiter(delimiter) &&
            markdown_table_cells(header).length() ==
            markdown_table_cells(delimiter).length() {
            mark_markdown_table_rows(source, tokens, line)
            break
          }
        }
      _ => ()
    }
  }
  let mut has_feature = false
  for token in tokens {
    match token {
      FeatureLine(_, _, _) => has_feature = true
      _ => ()
    }
  }
  if !has_feature {
    for line = 1; line <= source.line_count(); line = line + 1 {
      match tokens[line - 1] {
        Language(_, _) => continue
        _ => ()
      }
      let text = source.line(line).unwrap_or("")
      let trimmed = text[:].trim()
      if !trimmed.is_empty() {
        let mut title = trimmed
        while title.has_prefix("#") {
          title = title[1:]
        }
        tokens[line - 1] = Token::FeatureLine(
          { line, column: Some(1), },
          "Feature",
          title.trim().to_owned(),
        )
        break
      }
    }
  }
  tokens.push(Token::Eof({ line: source.line_count() + 1, column: None, }))
  tokens
}

///|
fn mark_markdown_fence(
  source : Source,
  tokens : Array[Token],
  span : @markdown.Span,
  info : String,
  marker : @markdown.FenceMarker,
  fence_length : Int,
) -> Unit {
  let first = markdown_line_number(source, span.from)
  let marker_char = match marker {
    Backtick => '`'
    Tilde => '~'
  }
  let fence_chars : Array[Char] = []
  for i = 0; i < fence_length; i = i + 1 {
    fence_chars.push(marker_char)
  }
  let delimiter = String::from_array(fence_chars)
  let opener = source.line(first).unwrap_or("")
  let opener_trimmed = opener[:].trim_start(chars=" ")
  let column = opener.length() - opener_trimmed.length() + 1
  tokens[first - 1] = Token::DocStringSeparator(
    { line: first, column: Some(column), },
    delimiter,
    if info.is_empty() {
      None
    } else {
      Some(info)
    },
  )
  for line = first + 1; line <= source.line_count(); line = line + 1 {
    let raw = source.line(line).unwrap_or("")
    if is_markdown_fence_close(raw, marker_char, fence_length) {
      tokens[line - 1] = Token::DocStringSeparator(
        { line, column: Some(column), },
        delimiter,
        None,
      )
      break
    } else {
      tokens[line - 1] = Token::Other({ line, column: None, }, raw)
    }
  }
}

///|
fn is_markdown_fence_close(
  line : String,
  marker : Char,
  opening_length : Int,
) -> Bool {
  let chars = line[:].trim().to_owned().to_array()
  let mut count = 0
  while count < chars.length() && chars[count] == marker {
    count = count + 1
  }
  count >= opening_length && count == chars.length()
}

///|
fn mark_markdown_list_tables(
  source : Source,
  tokens : Array[Token],
  span : @markdown.Span,
) -> Unit {
  let first = markdown_line_number(source, span.from)
  let last = markdown_line_number(source, span.to - 1)
  for line = first + 1; line <= last; line = line + 1 {
    let header = source.line(line).unwrap_or("")
    let delimiter = source.line(line + 1).unwrap_or("")
    let delimiter_trimmed = delimiter[:].trim_start(chars=" ")
    if is_markdown_table_row(header) &&
      is_markdown_table_row(delimiter) &&
      markdown_table_delimiter(delimiter_trimmed.to_owned()) {
      let cells = markdown_table_cells(header)
      if cells.length() == markdown_table_cells(delimiter).length() {
        mark_markdown_table_rows(source, tokens, line)
      }
    }
  }
}

///|
fn markdown_table_delimiter(line : String) -> Bool {
  let cells = markdown_table_cells(line)
  if cells.is_empty() {
    return false
  }
  for cell in cells {
    let mut dashes = 0
    for char in cell.iter() {
      match char {
        '-' => dashes = dashes + 1
        ':' => ()
        _ => return false
      }
    }
    if dashes < 1 {
      return false
    }
  }
  true
}

///|
fn mark_markdown_table(
  source : Source,
  tokens : Array[Token],
  span : @markdown.Span,
) -> Unit {
  let header_line = markdown_line_number(source, span.from)
  mark_markdown_table_rows(source, tokens, header_line)
}

///|
fn mark_markdown_table_rows(
  source : Source,
  tokens : Array[Token],
  header_line : Int,
) -> Unit {
  let mut line = header_line
  while line <= source.line_count() {
    if line == header_line + 1 {
      line = line + 1
      continue
    }
    let text = source.line(line).unwrap_or("")
    if !is_markdown_table_row(text) {
      break
    }
    let trimmed = text[:].trim_start(chars=" ")
    tokens[line - 1] = Token::TableRow(
      { line, column: Some(text.length() - trimmed.length() + 1), },
      markdown_table_cells(text),
    )
    line = line + 1
  }
}

///|
fn is_markdown_table_row(line : String) -> Bool {
  let trimmed = line[:].trim_start(chars=" ")
  let indent = line.length() - trimmed.length()
  indent >= 2 && indent <= 5 && trimmed.to_owned().contains("|")
}

///|
fn markdown_table_cells(line : String) -> Array[String] {
  let chars = line[:].trim().to_owned().to_array()
  let cells : Array[String] = []
  let mut start = 0
  if chars.length() > 0 && chars[0] == '|' {
    start = 1
  }
  let mut end = chars.length()
  if end > start && chars[end - 1] == '|' && (end < 2 || chars[end - 2] != '\\') {
    end = end - 1
  }
  let mut current : Array[Char] = []
  let mut i = start
  while i < end {
    if chars[i] == '\\' && i + 1 < end && chars[i + 1] == '|' {
      current.push('|')
      i = i + 2
      continue
    }
    if chars[i] == '|' {
      cells.push(trim_cell(String::from_array(current)))
      current = []
    } else {
      current.push(chars[i])
    }
    i = i + 1
  }
  cells.push(trim_cell(String::from_array(current)))
  cells
}

///|
fn markdown_line_number(source : Source, offset : Int) -> Int {
  let mut pos = 0
  for i = 1; i <= source.line_count(); i = i + 1 {
    if source.line(i) is Some(line) {
      if offset <= pos + line.length() {
        return i
      }
      pos = pos + line.length() + 1
    }
  }
  source.line_count()
}
