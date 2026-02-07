package gherkin

import (
	"context"
	"fmt"
	"os"
	"sync/atomic"

	"github.com/tetratelabs/wazero"
	"github.com/tetratelabs/wazero/api"
)

// Engine manages a compiled WASM module and provides the Gherkin parsing API.
//
// Create an Engine once with [NewEngine], then call [Engine.Parse],
// [Engine.Tokenize], or [Engine.Format] as many times as needed.
// Each call creates a fresh WASM instance internally (the component model
// does not support re-entrance).
type Engine struct {
	runtime  wazero.Runtime
	compiled wazero.CompiledModule
	counter  atomic.Uint64
}

// NewEngine loads and compiles the core WASM module at wasmPath.
//
// The module is compiled once (with AOT compilation on amd64/arm64)
// and reused across all subsequent calls.
func NewEngine(ctx context.Context, wasmPath string) (*Engine, error) {
	wasmBytes, err := os.ReadFile(wasmPath)
	if err != nil {
		return nil, fmt.Errorf("read wasm module: %w", err)
	}

	r := wazero.NewRuntime(ctx)

	compiled, err := r.CompileModule(ctx, wasmBytes)
	if err != nil {
		r.Close(ctx)
		return nil, fmt.Errorf("compile wasm module: %w", err)
	}

	return &Engine{runtime: r, compiled: compiled}, nil
}

// Close releases all WASM resources.
func (e *Engine) Close(ctx context.Context) error {
	return e.runtime.Close(ctx)
}

// Parse parses Gherkin source text into a structured [Document].
func (e *Engine) Parse(ctx context.Context, source string) (*Document, error) {
	inst, err := e.newInstance(ctx)
	if err != nil {
		return nil, err
	}
	defer inst.close(ctx)

	retptr, err := inst.callWithSource(ctx, exportParse, source)
	if err != nil {
		return nil, err
	}

	doc, err := inst.decodeParseResult(retptr)
	if err != nil {
		// For errors, still call post-return to free the error list memory.
		inst.callPostReturn(ctx, exportParsePost, retptr)
		return nil, err
	}

	inst.callPostReturn(ctx, exportParsePost, retptr)
	return doc, nil
}

// Tokenize tokenizes Gherkin source text into a stream of [Token] values.
func (e *Engine) Tokenize(ctx context.Context, source string) ([]Token, error) {
	inst, err := e.newInstance(ctx)
	if err != nil {
		return nil, err
	}
	defer inst.close(ctx)

	retptr, err := inst.callWithSource(ctx, exportTokenize, source)
	if err != nil {
		return nil, err
	}

	tokens, err := inst.decodeTokenizeResult(retptr)
	inst.callPostReturn(ctx, exportTokenizePost, retptr)
	return tokens, err
}

// Format parses Gherkin source and re-formats it via the writer (round-trip).
//
// Under the hood this calls parse, then immediately passes the raw document
// memory to the write export — avoiding the need to encode a full Document
// back into canonical ABI format.
func (e *Engine) Format(ctx context.Context, source string) (string, error) {
	inst, err := e.newInstance(ctx)
	if err != nil {
		return "", err
	}
	defer inst.close(ctx)

	// Step 1: Parse the source.
	parseRetptr, err := inst.callWithSource(ctx, exportParse, source)
	if err != nil {
		return "", fmt.Errorf("format/parse: %w", err)
	}

	// Check parse succeeded.
	if inst.readU8(parseRetptr) != 0 {
		parseErr := inst.decodeParseErrors(parseRetptr + 4)
		inst.callPostReturn(ctx, exportParsePost, parseRetptr)
		return "", fmt.Errorf("format/parse: %w", parseErr)
	}

	// Step 2: Pass the document (at parseRetptr+4) directly to write.
	// The write export takes a single pointer to a gherkin-document in memory.
	writeFn := inst.mod.ExportedFunction(exportWrite)
	if writeFn == nil {
		return "", fmt.Errorf("export %q not found", exportWrite)
	}

	docPtr := parseRetptr + 4
	writeResults, err := writeFn.Call(ctx, api.EncodeU32(docPtr))
	if err != nil {
		return "", fmt.Errorf("format/write: %w", err)
	}
	writeRetptr := api.DecodeU32(writeResults[0])

	// Step 3: Decode the write result.
	result, writeErr := inst.decodeStringResult(writeRetptr)

	// Step 4: Clean up. The write function already freed parse's dynamic
	// allocations as it read them, so we only call write's post-return.
	inst.callPostReturn(ctx, exportWritePost, writeRetptr)

	// Do NOT call ParsePostReturn — write already freed those allocations.
	// The instance close will release all remaining linear memory.

	return result, writeErr
}

// newInstance creates a fresh WASM module instance with cached function refs.
func (e *Engine) newInstance(ctx context.Context) (*instance, error) {
	id := e.counter.Add(1)
	name := fmt.Sprintf("gherkin-%d", id)

	mod, err := e.runtime.InstantiateModule(ctx, e.compiled,
		wazero.NewModuleConfig().WithName(name))
	if err != nil {
		return nil, fmt.Errorf("instantiate wasm module: %w", err)
	}

	alloc := mod.ExportedFunction(exportRealloc)
	if alloc == nil {
		mod.Close(ctx)
		return nil, fmt.Errorf("export %q not found", exportRealloc)
	}

	mem := mod.Memory()
	if mem == nil {
		mod.Close(ctx)
		return nil, fmt.Errorf("module does not export memory")
	}

	return &instance{mod: mod, mem: mem, alloc: alloc}, nil
}

// close releases the module instance.
func (inst *instance) close(ctx context.Context) error {
	return inst.mod.Close(ctx)
}
