package gherkin

import "fmt"

// --- Parse result decoders ---

// decodeParseResult decodes the 96-byte return area from a parse call.
// Layout: +0 disc(u8) — 0=ok(document), 1=err(list<parse-error>).
func (inst *instance) decodeParseResult(retptr uint32) (*Document, error) {
	disc := inst.readU8(retptr)
	if disc == 1 {
		return nil, inst.decodeParseErrors(retptr + 4)
	}
	// Ok: gherkin-document starting at retptr+4.
	return inst.decodeDocument(retptr + 4), nil
}

// decodeDocument decodes a gherkin-document record from linear memory.
//
// Layout (92 bytes):
//
//	+0:  source.uri disc(u8), +4: ptr, +8: len
//	+12: source.data ptr, +16: len
//	+20: feature disc(u8, 0=None 1=Some)
//	+24: feature.location.line, +28: col disc, +32: col val
//	+36: feature.tags ptr, +40: tags count
//	+44: feature.language ptr, +48: len
//	+52: feature.keyword ptr, +56: len
//	+60: feature.name ptr, +64: len
//	+68: feature.description ptr, +72: len
//	+76: feature.children ptr, +80: children count
//	+84: comments ptr, +88: comments count
func (inst *instance) decodeDocument(base uint32) *Document {
	doc := &Document{}

	// Feature: option<feature> at +20
	featureDisc := inst.readU8(base + 20)
	if featureDisc == 1 {
		doc.Feature = inst.decodeFeature(base + 24)
	}

	// Comments: list<comment> at +84
	commentsPtr := inst.readU32(base + 84)
	commentsCount := inst.readU32(base + 88)
	doc.Comments = make([]Comment, commentsCount)
	for i := uint32(0); i < commentsCount; i++ {
		doc.Comments[i] = inst.decodeComment(commentsPtr + i*16)
	}

	return doc
}

// decodeFeature decodes a Feature record starting at the given base.
//
// Layout (relative to feature start, after option disc):
//
//	+0:  location (line i32, col disc u8, col val i32) = 12 bytes
//	+12: tags ptr, +16: count
//	+20: language ptr, +24: len
//	+28: keyword ptr, +32: len
//	+36: name ptr, +40: len
//	+44: description ptr, +48: len
//	+52: children ptr, +56: count
func (inst *instance) decodeFeature(base uint32) *Feature {
	feat := &Feature{
		Location:    inst.readLocation(base),
		Language:    inst.readStringAt(base + 20),
		Keyword:     inst.readStringAt(base + 28),
		Name:        inst.readStringAt(base + 36),
		Description: inst.readStringAt(base + 44),
	}

	// Tags
	tagsPtr := inst.readU32(base + 12)
	tagsCount := inst.readU32(base + 16)
	feat.Tags = make([]Tag, tagsCount)
	for i := uint32(0); i < tagsCount; i++ {
		feat.Tags[i] = inst.decodeTag(tagsPtr + i*28)
	}

	// Children
	childrenPtr := inst.readU32(base + 52)
	childrenCount := inst.readU32(base + 56)
	feat.Children = make([]FeatureChild, childrenCount)
	for i := uint32(0); i < childrenCount; i++ {
		feat.Children[i] = inst.decodeFeatureChild(childrenPtr + i*76)
	}

	return feat
}

// decodeTag decodes a Tag record (28 bytes).
//
// Layout:
//
//	+0: location.line, +4: col disc, +8: col val
//	+12: name ptr, +16: name len
//	+20: id ptr, +24: id len
func (inst *instance) decodeTag(base uint32) Tag {
	return Tag{
		Location: inst.readLocation(base),
		Name:     inst.readStringAt(base + 12),
		ID:       inst.readStringAt(base + 20),
	}
}

// decodeComment decodes a Comment record (16 bytes).
//
// Layout:
//
//	+0: location.line, +4: col disc, +8: col val
//	+12: text ptr, ... wait — need to check actual layout.
//
// Actually: comment = { location, text }
//
//	+0: location (12 bytes)
//	+12: text ptr, +16: text len → but that's 20 bytes total...
//
// The comment record from WIT: record comment { location: location, text: string }
// location = 12 bytes (line i32 + option<i32> = 4+1+pad+4 = but canonical ABI...)
// Actually location = { line: s32, column: option<s32> }
//   - line: 4 bytes, align 4
//   - column: option<s32> = disc(1 byte) + pad(3 bytes) + val(4 bytes) = 8 bytes, align 4
//   - total: 12 bytes, align 4
// text: string = 8 bytes (ptr + len), align 4
// Total comment: 20 bytes, align 4
func (inst *instance) decodeComment(base uint32) Comment {
	return Comment{
		Location: inst.readLocation(base),
		Text:     inst.readStringAt(base + 12),
	}
}

// decodeFeatureChild decodes a FeatureChild variant (76 bytes).
// Disc at +0: 0=Background, 1=Scenario, 2=Rule.
func (inst *instance) decodeFeatureChild(base uint32) FeatureChild {
	disc := inst.readU8(base)
	switch disc {
	case 0:
		bg := inst.decodeBackground(base)
		return FeatureChild{Background: bg}
	case 1:
		sc := inst.decodeScenario(base)
		return FeatureChild{Scenario: sc}
	case 2:
		r := inst.decodeRule(base)
		return FeatureChild{Rule: r}
	default:
		return FeatureChild{}
	}
}

// decodeBackground decodes a Background from a 76-byte FeatureChild slot.
//
// Layout:
//
//	+0:  disc (0)
//	+4:  location (12 bytes)
//	+16: keyword ptr, +20: len
//	+24: name ptr, +28: len
//	+32: description ptr, +36: len
//	+40: id ptr, +44: len
//	+48: steps ptr, +52: steps count
func (inst *instance) decodeBackground(base uint32) *Background {
	bg := &Background{
		Location:    inst.readLocation(base + 4),
		Keyword:     inst.readStringAt(base + 16),
		Name:        inst.readStringAt(base + 24),
		Description: inst.readStringAt(base + 32),
		ID:          inst.readStringAt(base + 40),
	}

	stepsPtr := inst.readU32(base + 48)
	stepsCount := inst.readU32(base + 52)
	bg.Steps = inst.decodeSteps(stepsPtr, stepsCount)

	return bg
}

// decodeScenario decodes a Scenario from a 76-byte FeatureChild slot.
//
// Layout:
//
//	+0:  disc (1)
//	+4:  location (12 bytes)
//	+16: tags ptr, +20: tags count
//	+24: kind (u8 ordinal: 0=scenario, 1=scenario-outline)
//	+28: keyword ptr, +32: len
//	+36: name ptr, +40: len
//	+44: description ptr, +48: len
//	+52: id ptr, +56: len
//	+60: steps ptr, +64: steps count
//	+68: examples ptr, +72: examples count
func (inst *instance) decodeScenario(base uint32) *Scenario {
	kindOrd := inst.readU8(base + 24)
	kind := ScenarioKindScenario
	if kindOrd == 1 {
		kind = ScenarioKindScenarioOutline
	}

	sc := &Scenario{
		Location:    inst.readLocation(base + 4),
		Kind:        kind,
		Keyword:     inst.readStringAt(base + 28),
		Name:        inst.readStringAt(base + 36),
		Description: inst.readStringAt(base + 44),
		ID:          inst.readStringAt(base + 52),
	}

	// Tags
	tagsPtr := inst.readU32(base + 16)
	tagsCount := inst.readU32(base + 20)
	sc.Tags = make([]Tag, tagsCount)
	for i := uint32(0); i < tagsCount; i++ {
		sc.Tags[i] = inst.decodeTag(tagsPtr + i*28)
	}

	// Steps
	stepsPtr := inst.readU32(base + 60)
	stepsCount := inst.readU32(base + 64)
	sc.Steps = inst.decodeSteps(stepsPtr, stepsCount)

	// Examples
	exPtr := inst.readU32(base + 68)
	exCount := inst.readU32(base + 72)
	sc.Examples = make([]Examples, exCount)
	for i := uint32(0); i < exCount; i++ {
		sc.Examples[i] = inst.decodeExamples(exPtr + i*92)
	}

	return sc
}

// decodeRule decodes a Rule from a 76-byte FeatureChild slot.
//
// Layout:
//
//	+0:  disc (2)
//	+4:  location (12 bytes)
//	+16: tags ptr, +20: tags count
//	+24: keyword ptr, +28: len
//	+32: name ptr, +36: len
//	+40: description ptr, +44: len
//	+48: id ptr, +52: len
//	+56: children ptr, +60: children count
func (inst *instance) decodeRule(base uint32) *Rule {
	r := &Rule{
		Location:    inst.readLocation(base + 4),
		Keyword:     inst.readStringAt(base + 24),
		Name:        inst.readStringAt(base + 32),
		Description: inst.readStringAt(base + 40),
		ID:          inst.readStringAt(base + 48),
	}

	// Tags
	tagsPtr := inst.readU32(base + 16)
	tagsCount := inst.readU32(base + 20)
	r.Tags = make([]Tag, tagsCount)
	for i := uint32(0); i < tagsCount; i++ {
		r.Tags[i] = inst.decodeTag(tagsPtr + i*28)
	}

	// Children (RuleChild — same 76-byte layout as FeatureChild, but only background/scenario)
	childrenPtr := inst.readU32(base + 56)
	childrenCount := inst.readU32(base + 60)
	r.Children = make([]RuleChild, childrenCount)
	for i := uint32(0); i < childrenCount; i++ {
		childBase := childrenPtr + i*76
		disc := inst.readU8(childBase)
		switch disc {
		case 0:
			r.Children[i] = RuleChild{Background: inst.decodeBackground(childBase)}
		case 1:
			r.Children[i] = RuleChild{Scenario: inst.decodeScenario(childBase)}
		}
	}

	return r
}

// decodeSteps decodes a list of Step records (88 bytes each).
func (inst *instance) decodeSteps(ptr, count uint32) []Step {
	steps := make([]Step, count)
	for i := uint32(0); i < count; i++ {
		steps[i] = inst.decodeStep(ptr + i*88)
	}
	return steps
}

// decodeStep decodes a Step record (88 bytes).
//
// Layout:
//
//	+0:  location.line, +4: col disc, +8: col val
//	+12: keyword ptr, +16: keyword len
//	+20: keyword_type (u8 ordinal)
//	+24: text ptr, +28: text len
//	+32: id ptr, +36: id len
//	+40: argument disc (u8, 0=None, 1=Some)
//	+44: argument variant disc (u8, 0=DocString, 1=DataTable)
//	+48..87: argument payload
func (inst *instance) decodeStep(base uint32) Step {
	kwTypeOrd := inst.readU8(base + 20)
	kwTypes := [...]KeywordType{
		KeywordTypeContext, KeywordTypeAction, KeywordTypeOutcome,
		KeywordTypeConjunction, KeywordTypeUnknown,
	}
	kwType := KeywordTypeUnknown
	if int(kwTypeOrd) < len(kwTypes) {
		kwType = kwTypes[kwTypeOrd]
	}

	step := Step{
		Location:    inst.readLocation(base),
		Keyword:     inst.readStringAt(base + 12),
		KeywordType: kwType,
		Text:        inst.readStringAt(base + 24),
		ID:          inst.readStringAt(base + 32),
	}

	// Argument: option<step-argument>
	argDisc := inst.readU8(base + 40)
	if argDisc == 1 {
		step.Argument = inst.decodeStepArgument(base + 44)
	}

	return step
}

// decodeStepArgument decodes a step-argument variant.
// Disc at +0: 0=DocString, 1=DataTable.
func (inst *instance) decodeStepArgument(base uint32) *StepArgument {
	disc := inst.readU8(base)
	switch disc {
	case 0: // DocString
		return &StepArgument{DocString: inst.decodeDocString(base + 4)}
	case 1: // DataTable
		return &StepArgument{DataTable: inst.decodeDataTable(base + 4)}
	default:
		return nil
	}
}

// decodeDocString decodes a DocString from step argument payload.
//
// Layout (relative to argument payload start):
//
//	+0:  location.line, +4: col disc, +8: col val
//	+12: media_type disc(u8), +16: ptr, +20: len
//	+24: content ptr, +28: content len
//	+32: delimiter ptr, +36: delimiter len
func (inst *instance) decodeDocString(base uint32) *DocString {
	ds := &DocString{
		Location:  inst.readLocation(base),
		Content:   inst.readStringAt(base + 24),
		Delimiter: inst.readStringAt(base + 32),
	}
	mediaDisc := inst.readU8(base + 12)
	if mediaDisc == 1 {
		ds.MediaType = inst.readStringAt(base + 16)
	}
	return ds
}

// decodeDataTable decodes a DataTable from step argument payload.
//
// Layout:
//
//	+0:  location.line, +4: col disc, +8: col val
//	+12: rows ptr, +16: rows count
func (inst *instance) decodeDataTable(base uint32) *DataTable {
	dt := &DataTable{
		Location: inst.readLocation(base),
	}
	rowsPtr := inst.readU32(base + 12)
	rowsCount := inst.readU32(base + 16)
	dt.Rows = inst.decodeTableRows(rowsPtr, rowsCount)
	return dt
}

// decodeTableRows decodes a list of TableRow records (28 bytes each).
func (inst *instance) decodeTableRows(ptr, count uint32) []TableRow {
	rows := make([]TableRow, count)
	for i := uint32(0); i < count; i++ {
		rows[i] = inst.decodeTableRow(ptr + i*28)
	}
	return rows
}

// decodeTableRow decodes a TableRow (28 bytes).
//
// Layout:
//
//	+0: location (12 bytes)
//	+12: id ptr, +16: id len
//	+20: cells ptr, +24: cells count
func (inst *instance) decodeTableRow(base uint32) TableRow {
	row := TableRow{
		Location: inst.readLocation(base),
		ID:       inst.readStringAt(base + 12),
	}
	cellsPtr := inst.readU32(base + 20)
	cellsCount := inst.readU32(base + 24)
	row.Cells = make([]TableCell, cellsCount)
	for i := uint32(0); i < cellsCount; i++ {
		row.Cells[i] = inst.decodeTableCell(cellsPtr + i*20)
	}
	return row
}

// decodeTableCell decodes a TableCell (20 bytes).
//
// Layout:
//
//	+0: location (12 bytes)
//	+12: value ptr, +16: value len
func (inst *instance) decodeTableCell(base uint32) TableCell {
	return TableCell{
		Location: inst.readLocation(base),
		Value:    inst.readStringAt(base + 12),
	}
}

// decodeExamples decodes an Examples record (92 bytes).
//
// Layout:
//
//	+0:  location (12 bytes)
//	+12: tags ptr, +16: tags count
//	+20: keyword ptr, +24: keyword len
//	+28: name ptr, +32: name len
//	+36: description ptr, +40: description len
//	+44: id ptr, +48: id len
//	+52: table_header disc(u8), +56..: header payload
//	+84: table_body ptr, +88: table_body count
func (inst *instance) decodeExamples(base uint32) Examples {
	ex := Examples{
		Location:    inst.readLocation(base),
		Keyword:     inst.readStringAt(base + 20),
		Name:        inst.readStringAt(base + 28),
		Description: inst.readStringAt(base + 36),
		ID:          inst.readStringAt(base + 44),
	}

	// Tags
	tagsPtr := inst.readU32(base + 12)
	tagsCount := inst.readU32(base + 16)
	ex.Tags = make([]Tag, tagsCount)
	for i := uint32(0); i < tagsCount; i++ {
		ex.Tags[i] = inst.decodeTag(tagsPtr + i*28)
	}

	// Table header: option<table-row>
	headerDisc := inst.readU8(base + 52)
	if headerDisc == 1 {
		header := inst.decodeExamplesTableRow(base + 56)
		ex.TableHeader = &header
	}

	// Table body
	bodyPtr := inst.readU32(base + 84)
	bodyCount := inst.readU32(base + 88)
	ex.TableBody = inst.decodeTableRows(bodyPtr, bodyCount)

	return ex
}

// decodeExamplesTableRow decodes a TableRow inline within an Examples header.
// This is NOT a list element — it's embedded directly in the Examples record.
//
// Layout (within Examples, starting at the header payload offset):
//
//	+0: location.line, +4: col disc, +8: col val
//	+12: id ptr, +16: id len
//	+20: cells ptr, +24: cells count
func (inst *instance) decodeExamplesTableRow(base uint32) TableRow {
	row := TableRow{
		Location: inst.readLocation(base),
		ID:       inst.readStringAt(base + 12),
	}
	cellsPtr := inst.readU32(base + 20)
	cellsCount := inst.readU32(base + 24)
	row.Cells = make([]TableCell, cellsCount)
	for i := uint32(0); i < cellsCount; i++ {
		row.Cells[i] = inst.decodeTableCell(cellsPtr + i*20)
	}
	return row
}

// --- Tokenize result decoders ---

// decodeTokenizeResult decodes the return area from a tokenize call.
// Layout: +0 disc(u8) — 0=ok(list<token>), 1=err(list<parse-error>).
func (inst *instance) decodeTokenizeResult(retptr uint32) ([]Token, error) {
	disc := inst.readU8(retptr)
	if disc == 1 {
		return nil, inst.decodeParseErrors(retptr + 4)
	}
	// Ok: list<token> at retptr+4 (ptr, count)
	tokensPtr := inst.readU32(retptr + 4)
	tokensCount := inst.readU32(retptr + 8)
	tokens := make([]Token, tokensCount)
	for i := uint32(0); i < tokensCount; i++ {
		tokens[i] = inst.decodeToken(tokensPtr + i*36)
	}
	return tokens, nil
}

// decodeToken decodes a Token variant (36 bytes).
//
// Common prefix:
//
//	+0:  disc (u8) — token type
//	+4:  location.line (i32)
//	+8:  location.col disc (u8)
//	+12: location.col val (i32)
//
// Payload varies by disc (see tokenizer export for details).
func (inst *instance) decodeToken(base uint32) Token {
	disc := TokenType(inst.readU8(base))
	tok := Token{
		Type: disc,
		Line: inst.readI32(base + 4),
	}
	colDisc := inst.readU8(base + 8)
	if colDisc == 1 {
		col := inst.readI32(base + 12)
		tok.Column = &col
	}

	switch disc {
	case TokenFeatureLine, TokenRuleLine, TokenBackgroundLine, TokenExamplesLine:
		// +16: keyword(ptr,len), +24: name(ptr,len)
		tok.Keyword = inst.readStringAt(base + 16)
		tok.Name = inst.readStringAt(base + 24)

	case TokenScenarioLine:
		// +16: keyword(ptr,len), +24: name(ptr,len), +32: kind(u8)
		tok.Keyword = inst.readStringAt(base + 16)
		tok.Name = inst.readStringAt(base + 24)
		if inst.readU8(base+32) == 1 {
			tok.Kind = ScenarioKindScenarioOutline
		} else {
			tok.Kind = ScenarioKindScenario
		}

	case TokenStepLine:
		// +16: keyword(ptr,len), +24: keyword_type(u8), +28: text(ptr,len)
		tok.Keyword = inst.readStringAt(base + 16)
		kwOrd := inst.readU8(base + 24)
		kwTypes := [...]KeywordType{
			KeywordTypeContext, KeywordTypeAction, KeywordTypeOutcome,
			KeywordTypeConjunction, KeywordTypeUnknown,
		}
		if int(kwOrd) < len(kwTypes) {
			tok.KeywordType = kwTypes[kwOrd]
		} else {
			tok.KeywordType = KeywordTypeUnknown
		}
		tok.Text = inst.readStringAt(base + 28)

	case TokenDocStringSeparator:
		// +16: delimiter(ptr,len), +24: media_type disc(u8), +28: ptr, +32: len
		tok.Delimiter = inst.readStringAt(base + 16)
		if inst.readU8(base+24) == 1 {
			tok.MediaType = inst.readStringAt(base + 28)
		}

	case TokenTableRow:
		// +16: cells ptr, +20: cells count
		tok.Cells = inst.decodeStringList(base + 16)

	case TokenTagLine:
		// +16: tags ptr, +20: tags count
		tok.Tags = inst.decodeStringList(base + 16)

	case TokenCommentLine, TokenOther:
		// +16: text(ptr,len)
		tok.Text = inst.readStringAt(base + 16)

	case TokenLanguage:
		// +16: language(ptr,len)
		tok.Language = inst.readStringAt(base + 16)

	case TokenEmpty, TokenEOF:
		// location only — no extra fields
	}

	return tok
}

// decodeStringList decodes a list<string> at (ptr, count).
func (inst *instance) decodeStringList(base uint32) []string {
	listPtr := inst.readU32(base)
	listCount := inst.readU32(base + 4)
	result := make([]string, listCount)
	for i := uint32(0); i < listCount; i++ {
		result[i] = inst.readStringAt(listPtr + i*8)
	}
	return result
}

// --- Write result decoder ---

// decodeStringResult decodes a result<string, string> from a write call.
// Layout: +0 disc(u8) — 0=ok, 1=err. +4: string ptr, +8: string len.
func (inst *instance) decodeStringResult(retptr uint32) (string, error) {
	disc := inst.readU8(retptr)
	s := inst.readStringAt(retptr + 4)
	if disc == 1 {
		return "", fmt.Errorf("write error: %s", s)
	}
	return s, nil
}

// --- Error decoders ---

// decodeParseErrors decodes a list<parse-error> at (ptr, count).
// Each parse-error is 20 bytes:
//
//	+0: message ptr, +4: message len
//	+8: line (i32)
//	+12: column disc (u8), +16: column val (i32)
func (inst *instance) decodeParseErrors(base uint32) ParseErrors {
	errPtr := inst.readU32(base)
	errCount := inst.readU32(base + 4)
	errors := make(ParseErrors, errCount)
	for i := uint32(0); i < errCount; i++ {
		eBase := errPtr + i*20
		pe := ParseError{
			Message: inst.readStringAt(eBase),
			Line:    inst.readI32(eBase + 8),
		}
		if inst.readU8(eBase+12) == 1 {
			col := inst.readI32(eBase + 16)
			pe.Column = &col
		}
		errors[i] = pe
	}
	return errors
}
