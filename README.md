# caddie-csv-tools

A standalone CSV/TSV analytics module for [caddie.sh](https://github.com/parnotfar/caddie.sh). It packages the `csv`
commands (querying, plotting, previews) so they can evolve independently of the core caddie distribution.

## Version

3.7

## Features

- DuckDB-powered SQL querying with optional data visualisation
- Interactive, multi-line SQL prompt for composing queries
- Session defaults via `csv:set:*` helpers (file, axes, filters, plot metadata)
- Scatter, line, and bar chart support with matplotlib overlays, custom axis scales/ranges, and binary segmentation
- Head/tail previews, configurable pagers, and saved output targets
- Automatic integration with caddie’s prompt and completion registries

## Installation

```bash
caddie github:set:account parnotfar
caddie git:clone caddie-csv-tools (optional: git clone https://github.com/parnotfar/caddie-csv-tools.git)
cd caddie-csv-tools
make install
caddie reload
```

The `install` target copies the appropriate module file into the caddie module directory structure and places the python
application in the appropriate bin directory.

To remove the module:

```bash
make uninstall
caddie reload
```

Tab completion and the `[csv:…]` prompt indicator are registered automatically when the module is sourced.

## Development

Run the caddie linter against the module:

```bash
cd caddie-csv-tools
caddie core:lint
```

See [`docs/usage.md`](docs/usage.md) for comprehensive documentation and command examples.

## Versioning

The module is versioned independently from caddie.sh

## Compatabilty

This module is compatible with caddie.sh version 2.2 and above
