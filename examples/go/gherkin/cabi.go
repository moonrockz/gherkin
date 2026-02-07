package gherkin

import (
	"context"
	"encoding/binary"
	"fmt"
	"unicode/utf16"

	"github.com/tetratelabs/wazero/api"
)

// WASM export names (canonical ABI conventions from the component model).
const (
	exportParse        = "moonrockz:gherkin/parser@0.2.0#parse"
	exportParsePost    = "cabi_post_moonrockz:gherkin/parser@0.2.0#parse"
	exportTokenize     = "moonrockz:gherkin/tokenizer@0.2.0#tokenize"
	exportTokenizePost = "cabi_post_moonrockz:gherkin/tokenizer@0.2.0#tokenize"
	exportWrite        = "moonrockz:gherkin/writer@0.2.0#write"
	exportWritePost    = "cabi_post_moonrockz:gherkin/writer@0.2.0#write"
	exportRealloc      = "cabi_realloc"
)

// instance wraps a wazero module instance with cached function references.
type instance struct {
	mod   api.Module
	mem   api.Memory
	alloc api.Function
}

// guestAlloc allocates memory in the guest via cabi_realloc.
func (inst *instance) guestAlloc(ctx context.Context, align, size uint32) (uint32, error) {
	results, err := inst.alloc.Call(ctx,
		api.EncodeU32(0), // originalPtr = 0 (fresh allocation)
		api.EncodeU32(0), // originalSize = 0
		api.EncodeU32(align),
		api.EncodeU32(size),
	)
	if err != nil {
		return 0, fmt.Errorf("cabi_realloc failed: %w", err)
	}
	return api.DecodeU32(results[0]), nil
}

// writeString writes a Go string into guest linear memory as UTF-16-LE.
// The MoonBit core module is built with --encoding utf16, so all strings
// in linear memory are UTF-16-LE encoded.
// Returns the (pointer, byte_length) pair for the canonical ABI string representation.
func (inst *instance) writeString(ctx context.Context, s string) (ptr, length uint32, err error) {
	if len(s) == 0 {
		return 0, 0, nil
	}
	// Encode Go string (UTF-8) to UTF-16 code units, then to little-endian bytes.
	runes := []rune(s)
	units := utf16.Encode(runes)
	byteLen := uint32(len(units) * 2)
	data := make([]byte, byteLen)
	for i, u := range units {
		binary.LittleEndian.PutUint16(data[i*2:], u)
	}
	length = uint32(len(units)) // canonical ABI length = code unit count, not bytes
	ptr, err = inst.guestAlloc(ctx, 2, byteLen) // UTF-16 strings have alignment=2
	if err != nil {
		return 0, 0, err
	}
	if !inst.mem.Write(ptr, data) {
		return 0, 0, fmt.Errorf("write string out of bounds at %d (len=%d)", ptr, length)
	}
	return ptr, length, nil
}

// readString reads a canonical ABI UTF-16-LE string (ptr, code_unit_count) from guest memory.
// With utf16 encoding, the length field is the number of 2-byte code units, not bytes.
func (inst *instance) readString(strPtr, strLen uint32) string {
	if strLen == 0 {
		return ""
	}
	byteLen := strLen * 2
	raw, ok := inst.mem.Read(strPtr, byteLen)
	if !ok {
		return ""
	}
	units := make([]uint16, strLen)
	for i := range units {
		units[i] = binary.LittleEndian.Uint16(raw[i*2:])
	}
	return string(utf16.Decode(units))
}

// readStringAt reads a string descriptor (ptr i32, len i32) at the given memory offset.
func (inst *instance) readStringAt(base uint32) string {
	strPtr, _ := inst.mem.ReadUint32Le(base)
	strLen, _ := inst.mem.ReadUint32Le(base + 4)
	return inst.readString(strPtr, strLen)
}

// readOptString reads an option<string> at the given memory offset.
// Layout: +0 disc(u8), +4 ptr(i32), +8 len(i32). Returns nil for None.
func (inst *instance) readOptString(base uint32) *string {
	disc, _ := inst.mem.ReadByte(base)
	if disc == 0 {
		return nil
	}
	s := inst.readStringAt(base + 4)
	return &s
}

// readLocation reads a Location (line i32, column option<i32>) at the given offset.
// Layout: +0 line(i32), +4 col_disc(u8), +8 col_val(i32).
func (inst *instance) readLocation(base uint32) Location {
	line, _ := inst.mem.ReadUint32Le(base)
	colDisc, _ := inst.mem.ReadByte(base + 4)
	loc := Location{Line: int32(line)}
	if colDisc == 1 {
		colVal, _ := inst.mem.ReadUint32Le(base + 8)
		col := int32(colVal)
		loc.Column = &col
	}
	return loc
}

// readU8 reads a single byte at offset.
func (inst *instance) readU8(offset uint32) uint8 {
	v, _ := inst.mem.ReadByte(offset)
	return v
}

// readU32 reads a uint32 (little-endian) at offset.
func (inst *instance) readU32(offset uint32) uint32 {
	v, _ := inst.mem.ReadUint32Le(offset)
	return v
}

// readI32 reads an int32 (little-endian) at offset.
func (inst *instance) readI32(offset uint32) int32 {
	v, _ := inst.mem.ReadUint32Le(offset)
	return int32(v)
}

// callWithSource calls a WASM function that accepts a source record as flat params.
// Source record layout (5 flat i32 params):
//
//	p0: uri disc (0=None, 1=Some)
//	p1: uri ptr
//	p2: uri len
//	p3: data ptr
//	p4: data len
//
// Returns the return-area pointer (retptr).
func (inst *instance) callWithSource(ctx context.Context, funcName, source string) (uint32, error) {
	fn := inst.mod.ExportedFunction(funcName)
	if fn == nil {
		return 0, fmt.Errorf("export %q not found", funcName)
	}

	dataPtr, dataLen, err := inst.writeString(ctx, source)
	if err != nil {
		return 0, fmt.Errorf("write source data: %w", err)
	}

	// uri = None: disc=0, ptr=0, len=0
	results, err := fn.Call(ctx,
		api.EncodeU32(0),       // uri disc = None
		api.EncodeU32(0),       // uri ptr (unused)
		api.EncodeU32(0),       // uri len (unused)
		api.EncodeU32(dataPtr), // data ptr
		api.EncodeU32(dataLen), // data len
	)
	if err != nil {
		return 0, fmt.Errorf("call %s: %w", funcName, err)
	}

	return api.DecodeU32(results[0]), nil
}

// callPostReturn calls a cabi_post_* cleanup function.
func (inst *instance) callPostReturn(ctx context.Context, funcName string, retptr uint32) {
	fn := inst.mod.ExportedFunction(funcName)
	if fn == nil {
		return
	}
	fn.Call(ctx, api.EncodeU32(retptr)) //nolint:errcheck
}
