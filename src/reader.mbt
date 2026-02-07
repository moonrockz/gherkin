///|
/// A pull-based event reader for Gherkin documents.
///
/// Produces a stream of `GherkinEvent` values that the consumer
/// pulls one at a time. Supports `peek()`, `next()`, and `iter()`.
///
/// Two construction paths:
/// - `GherkinReader::new(source)` — parses from raw source text
/// - `GherkinReader::from_document(doc)` — walks an existing AST
///
/// Events can be piped to a `GherkinHandler` via `pipe()`.
pub struct GherkinReader {
  priv events : Array[GherkinEvent]
  priv mut pos : Int
}

///|
/// Create a `GherkinReader` that parses the given source into events.
pub fn GherkinReader::new(source : Source) -> GherkinReader raise ParseError {
  let doc = parse(source)
  GherkinReader::from_document(doc)
}

///|
/// Create a `GherkinReader` from an already-parsed document.
pub fn GherkinReader::from_document(doc : GherkinDocument) -> GherkinReader {
  let events : Array[GherkinEvent] = []
  events.push(DocumentStart)
  for c in doc.comments {
    events.push(Comment({ location: c.location, text: c.text }))
  }
  match doc.feature {
    Some(f) => emit_feature(events, f)
    None => ()
  }
  events.push(DocumentEnd)
  { events, pos: 0 }
}

///|
/// Return the next event, advancing the reader position.
/// Returns `None` when all events have been consumed.
pub fn GherkinReader::next(self : GherkinReader) -> GherkinEvent? {
  if self.pos < self.events.length() {
    let e = self.events[self.pos]
    self.pos = self.pos + 1
    Some(e)
  } else {
    None
  }
}

///|
/// Return the next event without advancing the reader position.
/// Returns `None` when all events have been consumed.
pub fn GherkinReader::peek(self : GherkinReader) -> GherkinEvent? {
  if self.pos < self.events.length() {
    Some(self.events[self.pos])
  } else {
    None
  }
}

///|
/// Return an `Iter[GherkinEvent]` that lazily pulls events.
pub fn GherkinReader::iter(self : GherkinReader) -> Iter[GherkinEvent] {
  Iter::new(fn() { self.next() })
}

///|
/// Pipe all remaining events to a `GherkinHandler`.
///
/// This is the pull-to-push adapter: pulls events from the reader
/// and dispatches them to the handler's callback methods.
pub fn GherkinReader::pipe(
  self : GherkinReader,
  handler : &GherkinHandler,
) -> Unit {
  for e in self.iter() {
    match e {
      DocumentStart => handler.on_document()
      DocumentEnd => handler.on_end_document()
      FeatureStart(fe) => handler.on_feature(fe)
      FeatureEnd => handler.on_end_feature()
      RuleStart(re) => handler.on_rule(re)
      RuleEnd => handler.on_end_rule()
      BackgroundStart(be) => handler.on_background(be)
      BackgroundEnd => handler.on_end_background()
      ScenarioStart(se) => handler.on_scenario(se)
      ScenarioEnd => handler.on_end_scenario()
      Step(se) => handler.on_step(se)
      DocString(de) => handler.on_doc_string(de)
      DataTable(dte) => handler.on_data_table(dte)
      Examples(ee) => handler.on_examples(ee)
      Tag(te) => handler.on_tag(te)
      Comment(ce) => handler.on_comment(ce)
    }
  }
}

// ---------------------------------------------------------------------------
// Private: AST walk to build event buffer
// ---------------------------------------------------------------------------

///|
fn emit_feature(events : Array[GherkinEvent], f : Feature) -> Unit {
  events.push(
    FeatureStart({
      location: f.location,
      tags: f.tags,
      language: f.language,
      keyword: f.keyword,
      name: f.name,
      description: f.description,
    }),
  )
  for t in f.tags {
    events.push(Tag({ location: t.location, name: t.name }))
  }
  for child in f.children {
    match child {
      FeatureChild::Background(bg) => emit_background(events, bg)
      FeatureChild::Scenario(s) => emit_scenario(events, s)
      FeatureChild::Rule(r) => emit_rule(events, r)
    }
  }
  events.push(FeatureEnd)
}

///|
fn emit_rule(events : Array[GherkinEvent], r : Rule) -> Unit {
  events.push(
    RuleStart({
      location: r.location,
      tags: r.tags,
      keyword: r.keyword,
      name: r.name,
      description: r.description,
    }),
  )
  for t in r.tags {
    events.push(Tag({ location: t.location, name: t.name }))
  }
  for child in r.children {
    match child {
      RuleChild::Background(bg) => emit_background(events, bg)
      RuleChild::Scenario(s) => emit_scenario(events, s)
    }
  }
  events.push(RuleEnd)
}

///|
fn emit_background(events : Array[GherkinEvent], bg : Background) -> Unit {
  events.push(
    BackgroundStart({
      location: bg.location,
      keyword: bg.keyword,
      name: bg.name,
      description: bg.description,
    }),
  )
  for s in bg.steps {
    emit_step(events, s)
  }
  events.push(BackgroundEnd)
}

///|
fn emit_scenario(events : Array[GherkinEvent], s : Scenario) -> Unit {
  events.push(
    ScenarioStart({
      location: s.location,
      tags: s.tags,
      kind: s.kind,
      keyword: s.keyword,
      name: s.name,
      description: s.description,
    }),
  )
  for t in s.tags {
    events.push(Tag({ location: t.location, name: t.name }))
  }
  for step in s.steps {
    emit_step(events, step)
  }
  for e in s.examples {
    events.push(
      Examples({
        location: e.location,
        tags: e.tags,
        keyword: e.keyword,
        name: e.name,
        description: e.description,
        table_header: e.table_header,
        table_body: e.table_body,
      }),
    )
  }
  events.push(ScenarioEnd)
}

///|
fn emit_step(events : Array[GherkinEvent], s : Step) -> Unit {
  events.push(
    Step({
      location: s.location,
      keyword: s.keyword,
      keyword_type: s.keyword_type,
      text: s.text,
    }),
  )
  match s.argument {
    Some(StepArgument::DocString(ds)) =>
      events.push(
        DocString({
          location: ds.location,
          media_type: ds.media_type,
          content: ds.content,
          delimiter: ds.delimiter,
        }),
      )
    Some(StepArgument::DataTable(dt)) =>
      events.push(DataTable({ location: dt.location, rows: dt.rows }))
    None => ()
  }
}
