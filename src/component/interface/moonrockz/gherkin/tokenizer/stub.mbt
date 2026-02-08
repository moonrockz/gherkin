///|
/// Tokenize Gherkin source into a list of typed tokens.
pub fn tokenize(
  source : @types.Source,
) -> Result[Array[@types.Token], Array[@types.ParseError]] {
  let src = @lib.Source::from_string(source.data, uri?=source.uri)
  let tokens = @lib.tokenize(src)
  Ok(tokens.map(convert_token))
}

// ── Forward conversion: @lib.Token → @types.Token ──

///|
fn convert_location(loc : @lib.Location) -> @types.Location {
  { line: loc.line, column: loc.column }
}

///|
fn convert_keyword_type(kt : @lib.KeywordType) -> @types.KeywordType {
  match kt {
    @lib.Context => @types.CONTEXT
    @lib.Action => @types.ACTION
    @lib.Outcome => @types.OUTCOME
    @lib.Conjunction => @types.CONJUNCTION
    @lib.Unknown => @types.UNKNOWN
  }
}

///|
fn convert_scenario_kind(k : @lib.ScenarioKind) -> @types.ScenarioKind {
  match k {
    @lib.Scenario => @types.SCENARIO
    @lib.ScenarioOutline => @types.SCENARIO_OUTLINE
  }
}

///|
fn convert_token(tok : @lib.Token) -> @types.Token {
  match tok {
    @lib.Token::FeatureLine(loc, keyword, name) =>
      @types.Token::FeatureLine({
        location: convert_location(loc),
        keyword,
        name,
      })
    @lib.Token::RuleLine(loc, keyword, name) =>
      @types.Token::RuleLine({ location: convert_location(loc), keyword, name })
    @lib.Token::BackgroundLine(loc, keyword, name) =>
      @types.Token::BackgroundLine({
        location: convert_location(loc),
        keyword,
        name,
      })
    @lib.Token::ScenarioLine(loc, keyword, name, kind) =>
      @types.Token::ScenarioLine({
        location: convert_location(loc),
        keyword,
        name,
        kind: convert_scenario_kind(kind),
      })
    @lib.Token::ExamplesLine(loc, keyword, name) =>
      @types.Token::ExamplesLine({
        location: convert_location(loc),
        keyword,
        name,
      })
    @lib.Token::StepLine(loc, keyword, keyword_type, text) =>
      @types.Token::StepLine({
        location: convert_location(loc),
        keyword,
        keyword_type: convert_keyword_type(keyword_type),
        text,
      })
    @lib.Token::DocStringSeparator(loc, delimiter, media_type) =>
      @types.Token::DocStringSeparator({
        location: convert_location(loc),
        delimiter,
        media_type,
      })
    @lib.Token::TableRow(loc, cells) =>
      @types.Token::TokenTableRow({ location: convert_location(loc), cells })
    @lib.Token::TagLine(loc, tags) =>
      @types.Token::TagLine({ location: convert_location(loc), tags })
    @lib.Token::Comment(loc, text) =>
      @types.Token::CommentLine({ location: convert_location(loc), text })
    @lib.Token::Language(loc, language) =>
      @types.Token::Language({ location: convert_location(loc), language })
    @lib.Token::Empty(loc) => @types.Token::Empty(convert_location(loc))
    @lib.Token::Other(loc, text) =>
      @types.Token::Other({ location: convert_location(loc), text })
    @lib.Token::Eof(loc) => @types.Token::Eof(convert_location(loc))
  }
}
