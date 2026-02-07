///|
/// Parse Gherkin source into a typed document AST.
pub fn parse(source : @types.Source) -> Result[@types.GherkinDocument, Array[@types.ParseError]] {
  let src = @lib.Source::from_string(source.data, uri?=source.uri)
  try {
    let doc = @lib.parse(src)
    Ok(convert_document(doc, source))
  } catch {
    @lib.UnexpectedToken(message~, location~) =>
      Err([convert_parse_error(message, location)])
    @lib.UnexpectedEof(message~, location~) =>
      Err([convert_parse_error(message, location)])
    @lib.InconsistentTableCells(message~, location~) =>
      Err([convert_parse_error(message, location)])
    @lib.CompositeError(errors~) => {
      let errs : Array[@types.ParseError] = []
      for e in errors {
        match e {
          @lib.UnexpectedToken(message~, location~) =>
            errs.push(convert_parse_error(message, location))
          @lib.UnexpectedEof(message~, location~) =>
            errs.push(convert_parse_error(message, location))
          @lib.InconsistentTableCells(message~, location~) =>
            errs.push(convert_parse_error(message, location))
          _ =>
            errs.push(
              { message: "unknown error", line: 0, column: None },
            )
        }
      }
      Err(errs)
    }
  }
}

// ── Forward conversion: @lib types → @types (WIT-generated) ──

fn convert_parse_error(
  message : String,
  loc : @lib.Location,
) -> @types.ParseError {
  { message, line: loc.line, column: loc.column }
}

fn convert_location(loc : @lib.Location) -> @types.Location {
  { line: loc.line, column: loc.column }
}

fn convert_tag(t : @lib.Tag) -> @types.Tag {
  { location: convert_location(t.location), name: t.name, id: t.id }
}

fn convert_comment(c : @lib.Comment) -> @types.Comment {
  { location: convert_location(c.location), text: c.text }
}

fn convert_table_cell(c : @lib.TableCell) -> @types.TableCell {
  { location: convert_location(c.location), value: c.value }
}

fn convert_table_row(r : @lib.TableRow) -> @types.TableRow {
  {
    location: convert_location(r.location),
    id: r.id,
    cells: r.cells.map(convert_table_cell),
  }
}

fn convert_doc_string(ds : @lib.DocString) -> @types.DocString {
  {
    location: convert_location(ds.location),
    media_type: ds.media_type,
    content: ds.content,
    delimiter: ds.delimiter,
  }
}

fn convert_data_table(dt : @lib.DataTable) -> @types.DataTable {
  {
    location: convert_location(dt.location),
    rows: dt.rows.map(convert_table_row),
  }
}

fn convert_step_argument(
  arg : @lib.StepArgument,
) -> @types.StepArgument {
  match arg {
    @lib.StepArgument::DocString(ds) =>
      @types.StepArgument::DocString(convert_doc_string(ds))
    @lib.StepArgument::DataTable(dt) =>
      @types.StepArgument::DataTable(convert_data_table(dt))
  }
}

fn convert_keyword_type(kt : @lib.KeywordType) -> @types.KeywordType {
  match kt {
    @lib.Context => @types.CONTEXT
    @lib.Action => @types.ACTION
    @lib.Outcome => @types.OUTCOME
    @lib.Conjunction => @types.CONJUNCTION
    @lib.Unknown => @types.UNKNOWN
  }
}

fn convert_scenario_kind(
  k : @lib.ScenarioKind,
) -> @types.ScenarioKind {
  match k {
    @lib.Scenario => @types.SCENARIO
    @lib.ScenarioOutline => @types.SCENARIO_OUTLINE
  }
}

fn convert_step(s : @lib.Step) -> @types.Step {
  {
    location: convert_location(s.location),
    keyword: s.keyword,
    keyword_type: convert_keyword_type(s.keyword_type),
    text: s.text,
    id: s.id,
    argument: s.argument.map(convert_step_argument),
  }
}

fn convert_examples(e : @lib.Examples) -> @types.Examples {
  {
    location: convert_location(e.location),
    tags: e.tags.map(convert_tag),
    keyword: e.keyword,
    name: e.name,
    description: e.description,
    id: e.id,
    table_header: e.table_header.map(convert_table_row),
    table_body: e.table_body.map(convert_table_row),
  }
}

fn convert_background(bg : @lib.Background) -> @types.Background {
  {
    location: convert_location(bg.location),
    keyword: bg.keyword,
    name: bg.name,
    description: bg.description,
    id: bg.id,
    steps: bg.steps.map(convert_step),
  }
}

fn convert_scenario(s : @lib.Scenario) -> @types.Scenario {
  {
    location: convert_location(s.location),
    tags: s.tags.map(convert_tag),
    kind: convert_scenario_kind(s.kind),
    keyword: s.keyword,
    name: s.name,
    description: s.description,
    id: s.id,
    steps: s.steps.map(convert_step),
    examples: s.examples.map(convert_examples),
  }
}

fn convert_rule_child(
  child : @lib.RuleChild,
) -> @types.RuleChild {
  match child {
    @lib.RuleChild::Background(bg) =>
      @types.RuleChild::Background(convert_background(bg))
    @lib.RuleChild::Scenario(s) =>
      @types.RuleChild::Scenario(convert_scenario(s))
  }
}

fn convert_rule(r : @lib.Rule) -> @types.Rule {
  {
    location: convert_location(r.location),
    tags: r.tags.map(convert_tag),
    keyword: r.keyword,
    name: r.name,
    description: r.description,
    id: r.id,
    children: r.children.map(convert_rule_child),
  }
}

fn convert_feature_child(
  child : @lib.FeatureChild,
) -> @types.FeatureChild {
  match child {
    @lib.FeatureChild::Background(bg) =>
      @types.FeatureChild::Background(convert_background(bg))
    @lib.FeatureChild::Scenario(s) =>
      @types.FeatureChild::Scenario(convert_scenario(s))
    @lib.FeatureChild::Rule(r) =>
      @types.FeatureChild::Rule(convert_rule(r))
  }
}

fn convert_feature(f : @lib.Feature) -> @types.Feature {
  {
    location: convert_location(f.location),
    tags: f.tags.map(convert_tag),
    language: f.language,
    keyword: f.keyword,
    name: f.name,
    description: f.description,
    children: f.children.map(convert_feature_child),
  }
}

fn convert_document(
  doc : @lib.GherkinDocument,
  source : @types.Source,
) -> @types.GherkinDocument {
  {
    source,
    feature: doc.feature.map(convert_feature),
    comments: doc.comments.map(convert_comment),
  }
}
