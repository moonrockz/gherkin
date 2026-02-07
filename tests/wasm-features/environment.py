"""Behave environment for WASM component tests."""

import os
import subprocess
from wasmtime import Engine, Store, Module
from wasmtime.component import Component, Linker


PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
COMPONENT_PATH = os.path.join(PROJECT_ROOT, "_build", "gherkin.component.wasm")
CORE_PATH = os.path.join(
    PROJECT_ROOT, "_build", "wasm", "release", "build", "component", "component.wasm"
)


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


def before_scenario(context, scenario):
    """Expose helper functions on context for each scenario."""
    context.make_instance = lambda: _make_instance(context)
    context.get_func = _get_func
