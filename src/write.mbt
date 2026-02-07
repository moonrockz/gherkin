///|
/// Configuration for formatting Gherkin output.
///
/// Use `WriteConfig::default()` for standard formatting, then
/// override specific fields via struct update syntax:
///
/// ```
/// let config = { ..WriteConfig::default(), indent: "    " }
/// ```
pub(all) struct WriteConfig {
  indent : String
  table_cell_padding : Int
  trailing_newline : Bool
  include_comments : Bool
} derive(Show, Eq)

///|
/// Create a `WriteConfig` with standard Gherkin formatting defaults.
pub fn WriteConfig::default() -> WriteConfig {
  {
    indent: "  ",
    table_cell_padding: 1,
    trailing_newline: true,
    include_comments: true,
  }
}

///|
/// A push-based Gherkin writer for building Gherkin text from arbitrary sources.
///
/// Manages indentation and formatting automatically. Call structural
/// methods (`feature`, `scenario`, etc.) with matching `end_*` methods,
/// and leaf methods (`step`, `tags`, etc.) for content.
///
/// Implements `GherkinHandler`, enabling reader-to-writer piping:
///
/// ```
/// let w = GherkinWriter::new()
/// parse_with_handler(source, w)
/// let output = w.to_string()
/// ```
pub struct GherkinWriter {
  priv buf : Array[String]
  priv config : WriteConfig
  priv mut depth : Int
  priv mut needs_blank : Bool
}

///|
/// Create a new `GherkinWriter` with the given configuration.
pub fn GherkinWriter::new(
  config? : WriteConfig = WriteConfig::default(),
) -> GherkinWriter {
  { buf: [], config, depth: 0, needs_blank: false }
}

///|
/// Return the accumulated Gherkin text.
pub fn GherkinWriter::to_string(self : GherkinWriter) -> String {
  let result = self.buf.join("\n")
  if self.config.trailing_newline && result.length() > 0 {
    result + "\n"
  } else {
    result
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

///|
fn GherkinWriter::current_indent(self : GherkinWriter) -> String {
  let mut s = ""
  for i = 0; i < self.depth; i = i + 1 {
    s = s + self.config.indent
  }
  s
}

///|
/// Emit blank line if needed, then emit an indented line.
fn GherkinWriter::emit_line(self : GherkinWriter, text : String) -> Unit {
  if self.needs_blank {
    self.buf.push("")
    self.needs_blank = false
  }
  self.buf.push(self.current_indent() + text)
}

///|
/// Split a string by newline characters.
fn split_lines(s : String) -> Array[String] {
  let lines : Array[String] = []
  let mut current : Array[Char] = []
  for c in s.iter() {
    if c == '\n' {
      lines.push(String::from_array(current))
      current = []
    } else if c != '\r' {
      current.push(c)
    }
  }
  lines.push(String::from_array(current))
  lines
}

///|
/// Format table rows as column-aligned pipe-delimited lines.
/// Returns an array of formatted row strings (without leading indent).
fn format_table(rows : Array[Array[String]], padding : Int) -> Array[String] {
  if rows.is_empty() {
    return []
  }
  let num_cols = rows[0].length()
  // Calculate max width per column
  let widths : Array[Int] = Array::make(num_cols, 0)
  for row in rows {
    for i, cell in row {
      if cell.length() > widths[i] {
        widths[i] = cell.length()
      }
    }
  }
  // Build padding string
  let mut pad = ""
  for i = 0; i < padding; i = i + 1 {
    pad = pad + " "
  }
  // Format each row
  let result : Array[String] = []
  for row in rows {
    let mut line = "|"
    for i, cell in row {
      // Right-pad cell value to column width
      let mut padded = cell
      let needed = widths[i] - cell.length()
      for j = 0; j < needed; j = j + 1 {
        padded = padded + " "
      }
      line = line + pad + padded + pad + "|"
    }
    result.push(line)
  }
  result
}

// ---------------------------------------------------------------------------
// Structural methods (start/end pairs manage indent depth)
// ---------------------------------------------------------------------------

///|
/// Emit a feature header. Call `end_feature()` when done.
///
/// When `language` is not `"en"`, a `# language:` directive is emitted first.
pub fn GherkinWriter::feature(
  self : GherkinWriter,
  keyword : String,
  name : String,
  language? : String = "en",
  description? : String = "",
) -> Unit {
  if language != "en" {
    self.buf.push("# language: " + language)
  }
  self.emit_line(keyword + ": " + name)
  self.depth = 1
  if description.length() > 0 {
    for line in split_lines(description) {
      self.buf.push(self.current_indent() + line)
    }
  }
  self.needs_blank = true
}

///|
/// Close the current feature scope.
pub fn GherkinWriter::end_feature(self : GherkinWriter) -> Unit {
  self.depth = 0
}

///|
/// Emit a scenario header. Call `end_scenario()` when done.
pub fn GherkinWriter::scenario(
  self : GherkinWriter,
  keyword : String,
  name : String,
  description? : String = "",
) -> Unit {
  self.emit_line(keyword + ": " + name)
  self.depth += 1
  if description.length() > 0 {
    for line in split_lines(description) {
      self.buf.push(self.current_indent() + line)
    }
  }
}

///|
/// Close the current scenario scope.
pub fn GherkinWriter::end_scenario(self : GherkinWriter) -> Unit {
  self.depth -= 1
  self.needs_blank = true
}

///|
/// Emit a background header. Call `end_background()` when done.
pub fn GherkinWriter::background(
  self : GherkinWriter,
  keyword : String,
  name? : String = "",
  description? : String = "",
) -> Unit {
  let header = if name.length() > 0 {
    keyword + ": " + name
  } else {
    keyword + ":"
  }
  self.emit_line(header)
  self.depth += 1
  if description.length() > 0 {
    for line in split_lines(description) {
      self.buf.push(self.current_indent() + line)
    }
  }
}

///|
/// Close the current background scope.
pub fn GherkinWriter::end_background(self : GherkinWriter) -> Unit {
  self.depth -= 1
  self.needs_blank = true
}

///|
/// Emit a rule header. Call `end_rule()` when done.
pub fn GherkinWriter::rule(
  self : GherkinWriter,
  keyword : String,
  name : String,
  description? : String = "",
) -> Unit {
  self.emit_line(keyword + ": " + name)
  self.depth += 1
  if description.length() > 0 {
    for line in split_lines(description) {
      self.buf.push(self.current_indent() + line)
    }
  }
  self.needs_blank = true
}

///|
/// Close the current rule scope.
pub fn GherkinWriter::end_rule(self : GherkinWriter) -> Unit {
  self.depth -= 1
  self.needs_blank = true
}

// ---------------------------------------------------------------------------
// Leaf methods
// ---------------------------------------------------------------------------

///|
/// Emit a step line.
pub fn GherkinWriter::step(
  self : GherkinWriter,
  keyword : String,
  text : String,
) -> Unit {
  self.emit_line(keyword + text)
}

///|
/// Emit a doc string block after a step.
pub fn GherkinWriter::doc_string(
  self : GherkinWriter,
  content : String,
  delimiter? : String = "\"\"\"",
  media_type? : String? = None,
) -> Unit {
  let saved_depth = self.depth
  self.depth += 1
  let indent = self.current_indent()
  let opener = match media_type {
    Some(mt) => delimiter + mt
    None => delimiter
  }
  self.buf.push(indent + opener)
  for line in split_lines(content) {
    self.buf.push(indent + line)
  }
  self.buf.push(indent + delimiter)
  self.depth = saved_depth
}

///|
/// Emit a data table with column-aligned cells after a step.
///
/// Each inner array is one row of cell values. All rows must have
/// the same number of elements.
pub fn GherkinWriter::data_table(
  self : GherkinWriter,
  rows : Array[Array[String]],
) -> Unit {
  let saved_depth = self.depth
  self.depth += 1
  let indent = self.current_indent()
  let formatted = format_table(rows, self.config.table_cell_padding)
  for line in formatted {
    self.buf.push(indent + line)
  }
  self.depth = saved_depth
}

///|
/// Emit an examples section with a pretty-printed table.
///
/// `header` is the column names, `body` is the data rows.
/// Both are arrays of cell value strings.
pub fn GherkinWriter::examples(
  self : GherkinWriter,
  keyword : String,
  name? : String = "",
  description? : String = "",
  header? : Array[String] = [],
  body? : Array[Array[String]] = [],
) -> Unit {
  self.needs_blank = true
  let kw_line = if name.length() > 0 {
    keyword + ": " + name
  } else {
    keyword + ":"
  }
  self.emit_line(kw_line)
  if description.length() > 0 {
    let saved = self.depth
    self.depth += 1
    for line in split_lines(description) {
      self.buf.push(self.current_indent() + line)
    }
    self.depth = saved
  }
  // Build table rows from header + body
  let all_rows : Array[Array[String]] = []
  if header.length() > 0 {
    all_rows.push(header)
  }
  for row in body {
    all_rows.push(row)
  }
  if all_rows.length() > 0 {
    let saved_depth = self.depth
    self.depth += 1
    let indent = self.current_indent()
    let formatted = format_table(all_rows, self.config.table_cell_padding)
    for line in formatted {
      self.buf.push(indent + line)
    }
    self.depth = saved_depth
  }
}

///|
/// Emit tags on one line, space-separated.
///
/// Call before the structural element the tags decorate.
/// Tags are emitted at the current indent level.
pub fn GherkinWriter::tags(self : GherkinWriter, names : Array[String]) -> Unit {
  if names.is_empty() {
    return
  }
  self.emit_line(names.join(" "))
}

///|
/// Emit a comment line.
pub fn GherkinWriter::comment(self : GherkinWriter, text : String) -> Unit {
  self.emit_line(text)
}

// ---------------------------------------------------------------------------
// write() DOM function
// ---------------------------------------------------------------------------

///|
/// Write a `GherkinDocument` AST as formatted Gherkin text.
///
/// Produces well-formatted output with column-aligned tables,
/// properly indented steps, and preserved i18n keywords.
///
/// This is the inverse of `parse`: calling `write(parse(source))`
/// produces valid Gherkin that, when re-parsed, yields an equivalent AST.
pub fn write(
  doc : GherkinDocument,
  config? : WriteConfig = WriteConfig::default(),
) -> String {
  let w = GherkinWriter::new(config~)
  if config.include_comments {
    for c in doc.comments {
      w.comment(c.text)
    }
  }
  match doc.feature {
    Some(f) => write_feature(w, f)
    None => ()
  }
  w.to_string()
}

///|
fn write_feature(w : GherkinWriter, f : Feature) -> Unit {
  if f.tags.length() > 0 {
    w.tags(f.tags.map(fn(t) { t.name }))
  }
  w.feature(f.keyword, f.name, language=f.language, description=f.description)
  for child in f.children {
    match child {
      FeatureChild::Background(bg) => write_background(w, bg)
      FeatureChild::Scenario(s) => write_scenario(w, s)
      FeatureChild::Rule(r) => write_rule(w, r)
    }
  }
  w.end_feature()
}

///|
fn write_scenario(w : GherkinWriter, s : Scenario) -> Unit {
  if s.tags.length() > 0 {
    w.tags(s.tags.map(fn(t) { t.name }))
  }
  w.scenario(s.keyword, s.name, description=s.description)
  for step in s.steps {
    write_step(w, step)
  }
  for e in s.examples {
    write_examples(w, e)
  }
  w.end_scenario()
}

///|
fn write_background(w : GherkinWriter, bg : Background) -> Unit {
  w.background(bg.keyword, description=bg.description)
  for step in bg.steps {
    write_step(w, step)
  }
  w.end_background()
}

///|
fn write_rule(w : GherkinWriter, r : Rule) -> Unit {
  if r.tags.length() > 0 {
    w.tags(r.tags.map(fn(t) { t.name }))
  }
  w.rule(r.keyword, r.name, description=r.description)
  for child in r.children {
    match child {
      RuleChild::Background(bg) => write_background(w, bg)
      RuleChild::Scenario(s) => write_scenario(w, s)
    }
  }
  w.end_rule()
}

///|
fn write_step(w : GherkinWriter, s : Step) -> Unit {
  w.step(s.keyword, s.text)
  match s.argument {
    Some(StepArgument::DocString(ds)) =>
      w.doc_string(ds.content, delimiter=ds.delimiter, media_type=ds.media_type)
    Some(StepArgument::DataTable(dt)) => {
      let rows : Array[Array[String]] = []
      for row in dt.rows {
        rows.push(row.cells.map(fn(c) { c.value }))
      }
      w.data_table(rows)
    }
    None => ()
  }
}

///|
fn write_examples(w : GherkinWriter, e : Examples) -> Unit {
  let header : Array[String] = match e.table_header {
    Some(row) => row.cells.map(fn(c) { c.value })
    None => []
  }
  let body : Array[Array[String]] = []
  for row in e.table_body {
    body.push(row.cells.map(fn(c) { c.value }))
  }
  w.examples(e.keyword, name=e.name, description=e.description, header~, body~)
}

// ---------------------------------------------------------------------------
// GherkinHandler implementation (enables parse_with_handler → writer piping)
// ---------------------------------------------------------------------------

///|
pub impl GherkinHandler for GherkinWriter with on_feature(self, e) {
  if e.tags.length() > 0 {
    self.tags(e.tags.map(fn(t) { t.name }))
  }
  self.feature(
    e.keyword,
    e.name,
    language=e.language,
    description=e.description,
  )
}

///|
pub impl GherkinHandler for GherkinWriter with on_end_feature(self) {
  self.end_feature()
}

///|
pub impl GherkinHandler for GherkinWriter with on_scenario(self, e) {
  if e.tags.length() > 0 {
    self.tags(e.tags.map(fn(t) { t.name }))
  }
  self.scenario(e.keyword, e.name, description=e.description)
}

///|
pub impl GherkinHandler for GherkinWriter with on_end_scenario(self) {
  self.end_scenario()
}

///|
pub impl GherkinHandler for GherkinWriter with on_background(self, e) {
  self.background(e.keyword, description=e.description)
}

///|
pub impl GherkinHandler for GherkinWriter with on_end_background(self) {
  self.end_background()
}

///|
pub impl GherkinHandler for GherkinWriter with on_rule(self, e) {
  if e.tags.length() > 0 {
    self.tags(e.tags.map(fn(t) { t.name }))
  }
  self.rule(e.keyword, e.name, description=e.description)
}

///|
pub impl GherkinHandler for GherkinWriter with on_end_rule(self) {
  self.end_rule()
}

///|
pub impl GherkinHandler for GherkinWriter with on_step(self, e) {
  self.step(e.keyword, e.text)
}

///|
pub impl GherkinHandler for GherkinWriter with on_doc_string(self, e) {
  self.doc_string(e.content, delimiter=e.delimiter, media_type=e.media_type)
}

///|
pub impl GherkinHandler for GherkinWriter with on_data_table(self, e) {
  let rows : Array[Array[String]] = []
  for row in e.rows {
    rows.push(row.cells.map(fn(c) { c.value }))
  }
  self.data_table(rows)
}

///|
pub impl GherkinHandler for GherkinWriter with on_examples(self, e) {
  let header : Array[String] = match e.table_header {
    Some(row) => row.cells.map(fn(c) { c.value })
    None => []
  }
  let body : Array[Array[String]] = []
  for row in e.table_body {
    body.push(row.cells.map(fn(c) { c.value }))
  }
  self.examples(
    e.keyword,
    name=e.name,
    description=e.description,
    header~,
    body~,
  )
}

///|
pub impl GherkinHandler for GherkinWriter with on_comment(self, e) {
  if self.config.include_comments {
    self.comment(e.text)
  }
}
