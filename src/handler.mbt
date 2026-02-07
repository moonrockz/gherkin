///|
/// A handler for push-based (SAX-style) parsing events.
///
/// All methods have default no-op implementations.
/// Override only the methods for events you want to handle.
///
/// The parser drives the process, calling handler methods
/// as it encounters structural elements.
pub(open) trait GherkinHandler {
  on_document(Self) -> Unit = _
  on_end_document(Self) -> Unit = _
  on_feature(Self, FeatureEvent) -> Unit = _
  on_end_feature(Self) -> Unit = _
  on_rule(Self, RuleEvent) -> Unit = _
  on_end_rule(Self) -> Unit = _
  on_background(Self, BackgroundEvent) -> Unit = _
  on_end_background(Self) -> Unit = _
  on_scenario(Self, ScenarioEvent) -> Unit = _
  on_end_scenario(Self) -> Unit = _
  on_step(Self, StepEvent) -> Unit = _
  on_examples(Self, ExamplesEvent) -> Unit = _
  on_tag(Self, TagEvent) -> Unit = _
  on_comment(Self, CommentEvent) -> Unit = _
  on_doc_string(Self, DocStringEvent) -> Unit = _
  on_data_table(Self, DataTableEvent) -> Unit = _
}

///|
impl GherkinHandler with on_document(_self) {
  ()
}

///|
impl GherkinHandler with on_end_document(_self) {
  ()
}

///|
impl GherkinHandler with on_feature(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_end_feature(_self) {
  ()
}

///|
impl GherkinHandler with on_rule(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_end_rule(_self) {
  ()
}

///|
impl GherkinHandler with on_background(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_end_background(_self) {
  ()
}

///|
impl GherkinHandler with on_scenario(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_end_scenario(_self) {
  ()
}

///|
impl GherkinHandler with on_step(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_examples(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_tag(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_comment(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_doc_string(_self, _e) {
  ()
}

///|
impl GherkinHandler with on_data_table(_self, _e) {
  ()
}

///|
/// Parse a `Source`, pushing events to a handler.
pub fn parse_with_handler(
  source : Source,
  handler : &GherkinHandler,
) -> Unit raise ParseError {
  let doc = parse(source)
  handler.on_document()
  for c in doc.comments {
    handler.on_comment({ location: c.location, text: c.text })
  }
  match doc.feature {
    Some(f) => dispatch_feature(f, handler)
    None => ()
  }
  handler.on_end_document()
}

///|
fn dispatch_feature(f : Feature, handler : &GherkinHandler) -> Unit {
  handler.on_feature({
    location: f.location,
    tags: f.tags,
    language: f.language,
    keyword: f.keyword,
    name: f.name,
    description: f.description,
  })
  for t in f.tags {
    handler.on_tag({ location: t.location, name: t.name })
  }
  for child in f.children {
    match child {
      FeatureChild::Background(bg) => dispatch_background(bg, handler)
      FeatureChild::Scenario(s) => dispatch_scenario(s, handler)
      FeatureChild::Rule(r) => dispatch_rule(r, handler)
    }
  }
  handler.on_end_feature()
}

///|
fn dispatch_rule(r : Rule, handler : &GherkinHandler) -> Unit {
  handler.on_rule({
    location: r.location,
    tags: r.tags,
    keyword: r.keyword,
    name: r.name,
    description: r.description,
  })
  for t in r.tags {
    handler.on_tag({ location: t.location, name: t.name })
  }
  for child in r.children {
    match child {
      RuleChild::Background(bg) => dispatch_background(bg, handler)
      RuleChild::Scenario(s) => dispatch_scenario(s, handler)
    }
  }
  handler.on_end_rule()
}

///|
fn dispatch_background(bg : Background, handler : &GherkinHandler) -> Unit {
  handler.on_background({
    location: bg.location,
    keyword: bg.keyword,
    name: bg.name,
    description: bg.description,
  })
  for s in bg.steps {
    dispatch_step(s, handler)
  }
  handler.on_end_background()
}

///|
fn dispatch_scenario(s : Scenario, handler : &GherkinHandler) -> Unit {
  handler.on_scenario({
    location: s.location,
    tags: s.tags,
    kind: s.kind,
    keyword: s.keyword,
    name: s.name,
    description: s.description,
  })
  for t in s.tags {
    handler.on_tag({ location: t.location, name: t.name })
  }
  for step in s.steps {
    dispatch_step(step, handler)
  }
  for e in s.examples {
    handler.on_examples({
      location: e.location,
      tags: e.tags,
      keyword: e.keyword,
      name: e.name,
      description: e.description,
      table_header: e.table_header,
      table_body: e.table_body,
    })
  }
  handler.on_end_scenario()
}

///|
fn dispatch_step(s : Step, handler : &GherkinHandler) -> Unit {
  handler.on_step({
    location: s.location,
    keyword: s.keyword,
    keyword_type: s.keyword_type,
    text: s.text,
  })
  match s.argument {
    Some(StepArgument::DocString(ds)) =>
      handler.on_doc_string({
        location: ds.location,
        media_type: ds.media_type,
        content: ds.content,
        delimiter: ds.delimiter,
      })
    Some(StepArgument::DataTable(dt)) =>
      handler.on_data_table({ location: dt.location, rows: dt.rows })
    None => ()
  }
}
