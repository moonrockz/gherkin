///|
/// Tokenize Markdown with Gherkin from its Markdown block structure.
/// Only headings and list items can introduce Gherkin keywords.
fn tokenize_markdown(source : Source) -> Array[Token] {
  let tokens : Array[Token] = []
  for i = 1; i <= source.line_count(); i = i + 1 {
    tokens.push(Token::Empty({ line: i, column: None, }))
  }
  let markdown = @cmark.Doc::from_string(
    locs=true,
    layout=true,
    strict=false,
    source.content(),
  )
  let mut language = "en"
  for block in markdown_blocks(markdown.block) {
    match block {
      Heading(heading) => {
        let line = markdown_first_line(heading)
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
      List(list) =>
        for item in list.v.items {
          let line = markdown_first_line(item)
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
            for child in markdown_blocks(item.v.block) {
              match child {
                ExtTable(table) =>
                  mark_markdown_table_rows(
                    source,
                    tokens,
                    markdown_first_line(table),
                  )
                CodeBlock(code) =>
                  if markdown_fence(code.v) is Some(fence) {
                    mark_markdown_fence(
                      source,
                      tokens,
                      markdown_first_line(code),
                      fence,
                    )
                  }
                _ => ()
              }
            }
            mark_markdown_list_tables(
              source,
              tokens,
              line,
              markdown_last_line(item),
            )
          }
        }
      ExtTable(table) =>
        mark_markdown_table_rows(source, tokens, markdown_first_line(table))
      CodeBlock(code) =>
        if markdown_fence(code.v) is Some(fence) {
          let line = markdown_first_line(code)
          if line > 1 {
            match tokens[line - 2] {
              StepLine(_, _, _, _) =>
                mark_markdown_fence(source, tokens, line, fence)
              _ => ()
            }
          }
        }
      Paragraph(paragraph) => {
        let line = markdown_first_line(paragraph)
        let tags : Array[String] = []
        let mut valid = true
        for inline in markdown_inlines(paragraph.v.inline) {
          match inline {
            CodeSpan(span) => {
              let content = span.v.code()
              if span.v.backticks == 1 &&
                content.has_prefix("@") &&
                content.length() > 1 {
                tags.push(content)
              } else {
                valid = false
              }
            }
            Text(text) => if !text.v[:].trim().is_empty() { valid = false }
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
/// The opening fence of a fenced code block: marker, length and info string.
priv struct MarkdownFence {
  marker : Char
  length : Int32
  info : String?
}

///|
fn markdown_fence(code : @cmark.CodeBlock) -> MarkdownFence? {
  match code.layout {
    Indented => None
    Fenced(layout) => {
      let opening = layout.opening_fence.v[:].trim_start(chars=" ")
      guard opening.get_char(0) is Some(marker) else { None }
      let mut length = 0
      for char in opening {
        guard char == marker else { break }
        length = length + 1
      }
      let info = match code.info_string {
        Some(info) if !info.v.is_empty() => Some(info.v)
        _ => None
      }
      Some({ marker, length, info, })
    }
  }
}

///|
fn mark_markdown_fence(
  source : Source,
  tokens : Array[Token],
  first : Int32,
  fence : MarkdownFence,
) -> Unit {
  let fence_chars : Array[Char] = []
  for i = 0; i < fence.length; i = i + 1 {
    fence_chars.push(fence.marker)
  }
  let delimiter = String::from_array(fence_chars)
  let opener = source.line(first).unwrap_or("")
  let opener_trimmed = opener[:].trim_start(chars=" ")
  let column = opener.length() - opener_trimmed.length() + 1
  tokens[first - 1] = Token::DocStringSeparator(
    { line: first, column: Some(column), },
    delimiter,
    fence.info,
  )
  for line = first + 1; line <= source.line_count(); line = line + 1 {
    let raw = source.line(line).unwrap_or("")
    if is_markdown_fence_close(raw, fence.marker, fence.length) {
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
  opening_length : Int32,
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
  first : Int32,
  last : Int32,
) -> Unit {
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
fn mark_markdown_table_rows(
  source : Source,
  tokens : Array[Token],
  header_line : Int32,
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
fn markdown_blocks(block : @cmark.Block) -> Array[@cmark.Block] {
  match block {
    Blocks(blocks) => blocks.v.to_array()
    block => [block]
  }
}

///|
fn markdown_inlines(inline : @cmark.Inline) -> Array[@cmark.Inline] {
  match inline {
    Inlines(inlines) => inlines.v.to_array()
    inline => [inline]
  }
}

///|
/// The 1-based source line where a cmark node starts.
fn[A] markdown_first_line(node : @cmark.Node[A]) -> Int32 {
  node.meta.loc.first_line.0
}

///|
/// The 1-based source line where a cmark node ends.
fn[A] markdown_last_line(node : @cmark.Node[A]) -> Int32 {
  node.meta.loc.last_line.0
}
