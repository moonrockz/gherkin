///|
/// A source of Gherkin text, bundling content with metadata.
///
/// The internal representation is opaque — callers use factory functions
/// to create and accessor methods to read. This allows the internal
/// representation to evolve without breaking consumers.
pub struct Source {
  priv lines : Array[String]
  priv uri : String?
} derive(Show, Eq)

///|
/// Create a `Source` from a string, splitting into lines.
///
/// Handles both Unix (`\n`) and Windows (`\r\n`) line endings.
/// The optional `uri` identifies where the content came from
/// (file path, URL, etc.).
pub fn Source::from_string(content : String, uri? : String) -> Source {
  let lines : Array[String] = []
  let mut current : Array[Char] = []
  for c in content.iter() {
    if c == '\n' {
      lines.push(String::from_array(current))
      current = []
    } else if c != '\r' {
      current.push(c)
    }
  }
  lines.push(String::from_array(current))
  { lines, uri }
}

///|
/// Create a `Source` from UTF-8 encoded bytes.
///
/// Decodes the bytes to a string, then splits into lines.
#declaration_only
pub fn Source::from_bytes(bytes : Bytes, uri? : String) -> Source {
  ...
}

///|
/// Returns the URI identifying this source, if any.
pub fn Source::uri(self : Source) -> String? {
  self.uri
}

///|
/// Returns the full content as a single string, with lines joined by `\n`.
///
/// This allocates a new string. For line-by-line access, prefer `line()`.
pub fn Source::content(self : Source) -> String {
  self.lines.join("\n")
}

///|
/// Returns the line at the given 1-based line number, matching `Location.line`.
///
/// Returns `None` if the line number is out of range.
pub fn Source::line(self : Source, n : Int) -> String? {
  if n >= 1 && n <= self.lines.length() {
    Some(self.lines[n - 1])
  } else {
    None
  }
}

///|
/// Returns the number of lines in this source.
pub fn Source::line_count(self : Source) -> Int {
  self.lines.length()
}

///|
/// Serialize a Source to JSON with `uri` and `data` fields.
pub impl ToJson for Source with to_json(self) {
  { "uri": self.uri.to_json(), "data": self.content().to_json() }
}
