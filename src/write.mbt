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
/// Write a `GherkinDocument` AST as formatted Gherkin text.
///
/// Produces well-formatted output with column-aligned tables,
/// properly indented steps, and preserved i18n keywords.
///
/// This is the inverse of `parse`: calling `write(parse(source))`
/// produces valid Gherkin that, when re-parsed, yields an equivalent AST.
pub fn write(
  doc : GherkinDocument,
  config~ : WriteConfig = WriteConfig::default(),
) -> String {
  ignore(doc)
  ignore(config)
  abort("write: not yet implemented")
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
  config~ : WriteConfig = WriteConfig::default(),
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
  language~ : String = "en",
  description~ : String = "",
) -> Unit {
  ignore(self)
  ignore(keyword)
  ignore(name)
  ignore(language)
  ignore(description)
  abort("GherkinWriter::feature: not yet implemented")
}

///|
/// Close the current feature scope.
pub fn GherkinWriter::end_feature(self : GherkinWriter) -> Unit {
  ignore(self)
  abort("GherkinWriter::end_feature: not yet implemented")
}

///|
/// Emit a scenario header. Call `end_scenario()` when done.
pub fn GherkinWriter::scenario(
  self : GherkinWriter,
  keyword : String,
  name : String,
  description~ : String = "",
) -> Unit {
  ignore(self)
  ignore(keyword)
  ignore(name)
  ignore(description)
  abort("GherkinWriter::scenario: not yet implemented")
}

///|
/// Close the current scenario scope.
pub fn GherkinWriter::end_scenario(self : GherkinWriter) -> Unit {
  ignore(self)
  abort("GherkinWriter::end_scenario: not yet implemented")
}

///|
/// Emit a background header. Call `end_background()` when done.
pub fn GherkinWriter::background(
  self : GherkinWriter,
  keyword : String,
  name~ : String = "",
  description~ : String = "",
) -> Unit {
  ignore(self)
  ignore(keyword)
  ignore(name)
  ignore(description)
  abort("GherkinWriter::background: not yet implemented")
}

///|
/// Close the current background scope.
pub fn GherkinWriter::end_background(self : GherkinWriter) -> Unit {
  ignore(self)
  abort("GherkinWriter::end_background: not yet implemented")
}

///|
/// Emit a rule header. Call `end_rule()` when done.
pub fn GherkinWriter::rule(
  self : GherkinWriter,
  keyword : String,
  name : String,
  description~ : String = "",
) -> Unit {
  ignore(self)
  ignore(keyword)
  ignore(name)
  ignore(description)
  abort("GherkinWriter::rule: not yet implemented")
}

///|
/// Close the current rule scope.
pub fn GherkinWriter::end_rule(self : GherkinWriter) -> Unit {
  ignore(self)
  abort("GherkinWriter::end_rule: not yet implemented")
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
  ignore(self)
  ignore(keyword)
  ignore(text)
  abort("GherkinWriter::step: not yet implemented")
}

///|
/// Emit a doc string block after a step.
pub fn GherkinWriter::doc_string(
  self : GherkinWriter,
  content : String,
  delimiter~ : String = "\"\"\"",
  media_type~ : String? = None,
) -> Unit {
  ignore(self)
  ignore(content)
  ignore(delimiter)
  ignore(media_type)
  abort("GherkinWriter::doc_string: not yet implemented")
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
  ignore(self)
  ignore(rows)
  abort("GherkinWriter::data_table: not yet implemented")
}

///|
/// Emit an examples section with a pretty-printed table.
///
/// `header` is the column names, `body` is the data rows.
/// Both are arrays of cell value strings.
pub fn GherkinWriter::examples(
  self : GherkinWriter,
  keyword : String,
  name~ : String = "",
  description~ : String = "",
  header~ : Array[String] = [],
  body~ : Array[Array[String]] = [],
) -> Unit {
  ignore(self)
  ignore(keyword)
  ignore(name)
  ignore(description)
  ignore(header)
  ignore(body)
  abort("GherkinWriter::examples: not yet implemented")
}

///|
/// Emit tags on one line, space-separated.
///
/// Call before the structural element the tags decorate.
/// Tags are emitted at the current indent level.
pub fn GherkinWriter::tags(
  self : GherkinWriter,
  names : Array[String],
) -> Unit {
  ignore(self)
  ignore(names)
  abort("GherkinWriter::tags: not yet implemented")
}

///|
/// Emit a comment line.
pub fn GherkinWriter::comment(
  self : GherkinWriter,
  text : String,
) -> Unit {
  ignore(self)
  ignore(text)
  abort("GherkinWriter::comment: not yet implemented")
}

// ---------------------------------------------------------------------------
// GherkinHandler implementation (enables parse_with_handler → writer piping)
// ---------------------------------------------------------------------------
// Uses trait default no-ops until implemented. Handler bridge tests will
// produce empty output, failing with wrong-value rather than compile errors.

pub impl GherkinHandler for GherkinWriter
