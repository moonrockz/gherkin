///|
/// Convert a typed document AST back to formatted Gherkin text.
pub fn write(document : @types.GherkinDocument) -> Result[String, String] {
  let doc = convert_wit_document(document)
  Ok(@lib.write(doc))
}

///|
/// Convert a list of events back to formatted Gherkin text.
pub fn write_events(events : Array[@types.GherkinEvent]) -> Result[String, String] {
  let writer = @lib.GherkinWriter::new()
  for event in events {
    dispatch_event(writer, event)
  }
  Ok(writer.to_string())
}

// ── Event dispatch: @types.GherkinEvent → GherkinWriter calls ──

fn dispatch_event(w : @lib.GherkinWriter, event : @types.GherkinEvent) -> Unit {
  match event {
    @types.GherkinEvent::DocumentStart => ()
    @types.GherkinEvent::DocumentEnd => ()
    @types.GherkinEvent::FeatureStart(e) =>
      w.on_feature(convert_wit_feature_event(e))
    @types.GherkinEvent::FeatureEnd => w.on_end_feature()
    @types.GherkinEvent::RuleStart(e) =>
      w.on_rule(convert_wit_rule_event(e))
    @types.GherkinEvent::RuleEnd => w.on_end_rule()
    @types.GherkinEvent::BackgroundStart(e) =>
      w.on_background(convert_wit_background_event(e))
    @types.GherkinEvent::BackgroundEnd => w.on_end_background()
    @types.GherkinEvent::ScenarioStart(e) =>
      w.on_scenario(convert_wit_scenario_event(e))
    @types.GherkinEvent::ScenarioEnd => w.on_end_scenario()
    @types.GherkinEvent::Step(e) =>
      w.on_step(convert_wit_step_event(e))
    @types.GherkinEvent::DocString(e) =>
      w.on_doc_string(convert_wit_doc_string_event(e))
    @types.GherkinEvent::DataTable(e) =>
      w.on_data_table(convert_wit_data_table_event(e))
    @types.GherkinEvent::Examples(e) =>
      w.on_examples(convert_wit_examples_event(e))
    @types.GherkinEvent::Tag(e) =>
      w.on_tag(convert_wit_tag_event(e))
    @types.GherkinEvent::Comment(e) =>
      w.on_comment(convert_wit_comment_event(e))
  }
}

// ── Reverse conversion: @types (WIT-generated) → @lib types ──

fn convert_wit_location(loc : @types.Location) -> @lib.Location {
  { line: loc.line, column: loc.column }
}

fn convert_wit_tag(t : @types.Tag) -> @lib.Tag {
  { location: convert_wit_location(t.location), name: t.name, id: t.id }
}

fn convert_wit_comment(c : @types.Comment) -> @lib.Comment {
  { location: convert_wit_location(c.location), text: c.text }
}

fn convert_wit_table_cell(c : @types.TableCell) -> @lib.TableCell {
  { location: convert_wit_location(c.location), value: c.value }
}

fn convert_wit_table_row(r : @types.TableRow) -> @lib.TableRow {
  {
    location: convert_wit_location(r.location),
    id: r.id,
    cells: r.cells.map(convert_wit_table_cell),
  }
}

fn convert_wit_doc_string(ds : @types.DocString) -> @lib.DocString {
  {
    location: convert_wit_location(ds.location),
    media_type: ds.media_type,
    content: ds.content,
    delimiter: ds.delimiter,
  }
}

fn convert_wit_data_table(dt : @types.DataTable) -> @lib.DataTable {
  {
    location: convert_wit_location(dt.location),
    rows: dt.rows.map(convert_wit_table_row),
  }
}

fn convert_wit_step_argument(arg : @types.StepArgument) -> @lib.StepArgument {
  match arg {
    @types.StepArgument::DocString(ds) =>
      @lib.StepArgument::DocString(convert_wit_doc_string(ds))
    @types.StepArgument::DataTable(dt) =>
      @lib.StepArgument::DataTable(convert_wit_data_table(dt))
  }
}

fn convert_wit_keyword_type(kt : @types.KeywordType) -> @lib.KeywordType {
  match kt {
    @types.CONTEXT => @lib.Context
    @types.ACTION => @lib.Action
    @types.OUTCOME => @lib.Outcome
    @types.CONJUNCTION => @lib.Conjunction
    @types.UNKNOWN => @lib.Unknown
  }
}

fn convert_wit_scenario_kind(k : @types.ScenarioKind) -> @lib.ScenarioKind {
  match k {
    @types.SCENARIO => @lib.Scenario
    @types.SCENARIO_OUTLINE => @lib.ScenarioOutline
  }
}

fn convert_wit_step(s : @types.Step) -> @lib.Step {
  {
    location: convert_wit_location(s.location),
    keyword: s.keyword,
    keyword_type: convert_wit_keyword_type(s.keyword_type),
    text: s.text,
    id: s.id,
    argument: s.argument.map(convert_wit_step_argument),
  }
}

fn convert_wit_examples(e : @types.Examples) -> @lib.Examples {
  {
    location: convert_wit_location(e.location),
    tags: e.tags.map(convert_wit_tag),
    keyword: e.keyword,
    name: e.name,
    description: e.description,
    id: e.id,
    table_header: e.table_header.map(convert_wit_table_row),
    table_body: e.table_body.map(convert_wit_table_row),
  }
}

fn convert_wit_background(bg : @types.Background) -> @lib.Background {
  {
    location: convert_wit_location(bg.location),
    keyword: bg.keyword,
    name: bg.name,
    description: bg.description,
    id: bg.id,
    steps: bg.steps.map(convert_wit_step),
  }
}

fn convert_wit_scenario(s : @types.Scenario) -> @lib.Scenario {
  {
    location: convert_wit_location(s.location),
    tags: s.tags.map(convert_wit_tag),
    kind: convert_wit_scenario_kind(s.kind),
    keyword: s.keyword,
    name: s.name,
    description: s.description,
    id: s.id,
    steps: s.steps.map(convert_wit_step),
    examples: s.examples.map(convert_wit_examples),
  }
}

fn convert_wit_rule_child(child : @types.RuleChild) -> @lib.RuleChild {
  match child {
    @types.RuleChild::Background(bg) =>
      @lib.RuleChild::Background(convert_wit_background(bg))
    @types.RuleChild::Scenario(s) =>
      @lib.RuleChild::Scenario(convert_wit_scenario(s))
  }
}

fn convert_wit_rule(r : @types.Rule) -> @lib.Rule {
  {
    location: convert_wit_location(r.location),
    tags: r.tags.map(convert_wit_tag),
    keyword: r.keyword,
    name: r.name,
    description: r.description,
    id: r.id,
    children: r.children.map(convert_wit_rule_child),
  }
}

fn convert_wit_feature_child(child : @types.FeatureChild) -> @lib.FeatureChild {
  match child {
    @types.FeatureChild::Background(bg) =>
      @lib.FeatureChild::Background(convert_wit_background(bg))
    @types.FeatureChild::Scenario(s) =>
      @lib.FeatureChild::Scenario(convert_wit_scenario(s))
    @types.FeatureChild::Rule(r) =>
      @lib.FeatureChild::Rule(convert_wit_rule(r))
  }
}

fn convert_wit_feature(f : @types.Feature) -> @lib.Feature {
  {
    location: convert_wit_location(f.location),
    tags: f.tags.map(convert_wit_tag),
    language: f.language,
    keyword: f.keyword,
    name: f.name,
    description: f.description,
    children: f.children.map(convert_wit_feature_child),
  }
}

fn convert_wit_document(doc : @types.GherkinDocument) -> @lib.GherkinDocument {
  {
    source: @lib.Source::from_string(doc.source.data, uri?=doc.source.uri),
    feature: doc.feature.map(convert_wit_feature),
    comments: doc.comments.map(convert_wit_comment),
  }
}

// ── Event conversion: @types event → @lib event ──

fn convert_wit_feature_event(e : @types.FeatureEvent) -> @lib.FeatureEvent {
  {
    location: convert_wit_location(e.location),
    tags: e.tags.map(convert_wit_tag),
    language: e.language,
    keyword: e.keyword,
    name: e.name,
    description: e.description,
  }
}

fn convert_wit_rule_event(e : @types.RuleEvent) -> @lib.RuleEvent {
  {
    location: convert_wit_location(e.location),
    tags: e.tags.map(convert_wit_tag),
    keyword: e.keyword,
    name: e.name,
    description: e.description,
  }
}

fn convert_wit_background_event(e : @types.BackgroundEvent) -> @lib.BackgroundEvent {
  {
    location: convert_wit_location(e.location),
    keyword: e.keyword,
    name: e.name,
    description: e.description,
  }
}

fn convert_wit_scenario_event(e : @types.ScenarioEvent) -> @lib.ScenarioEvent {
  {
    location: convert_wit_location(e.location),
    tags: e.tags.map(convert_wit_tag),
    kind: convert_wit_scenario_kind(e.kind),
    keyword: e.keyword,
    name: e.name,
    description: e.description,
  }
}

fn convert_wit_step_event(e : @types.StepEvent) -> @lib.StepEvent {
  {
    location: convert_wit_location(e.location),
    keyword: e.keyword,
    keyword_type: convert_wit_keyword_type(e.keyword_type),
    text: e.text,
  }
}

fn convert_wit_doc_string_event(e : @types.DocStringEvent) -> @lib.DocStringEvent {
  {
    location: convert_wit_location(e.location),
    media_type: e.media_type,
    content: e.content,
    delimiter: e.delimiter,
  }
}

fn convert_wit_data_table_event(e : @types.DataTableEvent) -> @lib.DataTableEvent {
  {
    location: convert_wit_location(e.location),
    rows: e.rows.map(convert_wit_table_row),
  }
}

fn convert_wit_examples_event(e : @types.ExamplesEvent) -> @lib.ExamplesEvent {
  {
    location: convert_wit_location(e.location),
    tags: e.tags.map(convert_wit_tag),
    keyword: e.keyword,
    name: e.name,
    description: e.description,
    table_header: e.table_header.map(convert_wit_table_row),
    table_body: e.table_body.map(convert_wit_table_row),
  }
}

fn convert_wit_tag_event(e : @types.TagEvent) -> @lib.TagEvent {
  { location: convert_wit_location(e.location), name: e.name }
}

fn convert_wit_comment_event(e : @types.CommentEvent) -> @lib.CommentEvent {
  { location: convert_wit_location(e.location), text: e.text }
}
