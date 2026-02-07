"""Behave environment for WASM component tests."""

import os
import subprocess
from types import SimpleNamespace
from wasmtime import Engine, Store, Module
from wasmtime.component import Component, Linker
from wasmtime.component._types import VariantLikeType, VariantType


# Workaround for wasmtime-py bug: VariantType inherits from both ValType and
# VariantLikeType. Python's MRO resolves add_classes to ValType's abstract
# no-op, shadowing VariantLikeType's concrete implementation. This causes
# option<variant> lowering to fail because the isinstance check set is empty.
# Fix: explicitly set VariantType.add_classes to the concrete implementation.
VariantType.add_classes = VariantLikeType.add_classes


PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
COMPONENT_PATH = os.path.join(PROJECT_ROOT, "_build", "gherkin.component.wasm")
CORE_PATH = os.path.join(
    PROJECT_ROOT, "_build", "wasm", "release", "build", "component", "component.wasm"
)

PARSER_IFACE = "moonrockz:gherkin/parser@0.2.0"
TOKENIZER_IFACE = "moonrockz:gherkin/tokenizer@0.2.0"
WRITER_IFACE = "moonrockz:gherkin/writer@0.2.0"


def before_all(context):
    """Build the WASM component and create the engine."""
    # Build the component (also builds core WASM as a dependency)
    result = subprocess.run(
        ["mise", "run", "build:component"],
        capture_output=True,
        text=True,
        cwd=PROJECT_ROOT,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Failed to build component:\n{result.stderr}")

    context.engine = Engine()
    context.component = Component.from_file(context.engine, COMPONENT_PATH)

    # Load the core WASM module for export validation tests
    context.core_module = Module.from_file(context.engine, CORE_PATH)
    context.core_exports = {exp.name: exp for exp in context.core_module.exports}


def _make_instance(context):
    """Create a fresh store + instance (component model doesn't support re-entrance)."""
    linker = Linker(context.engine)
    store = Store(context.engine)
    instance = linker.instantiate(store, context.component)
    return store, instance


def _get_func(instance, store, interface, name):
    """Get a component function by interface and name."""
    iface_idx = instance.get_export_index(store, interface)
    func_idx = instance.get_export_index(store, name, iface_idx)
    return instance.get_func(store, func_idx)


def _make_source(data, uri=None):
    """Create a WIT source record for typed interface calls."""
    return SimpleNamespace(uri=uri, data=data)


def before_scenario(context, scenario):
    """Expose helper functions on context for each scenario."""
    context.make_instance = lambda: _make_instance(context)
    context.get_func = _get_func
    context.make_source = _make_source
    context.PARSER_IFACE = PARSER_IFACE
    context.TOKENIZER_IFACE = TOKENIZER_IFACE
    context.WRITER_IFACE = WRITER_IFACE
