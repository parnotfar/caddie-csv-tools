# caddie-csv-tools

A standalone CSV/TSV analytics module for [caddie.sh](https://github.com/parnotfar/caddie.sh). It packages the `csv`
commands (querying, plotting, previews) so they can evolve independently of the core caddie distribution.

## Version

1.6

## Features

- DuckDB-powered SQL querying with optional data visualisation
- Interactive, multi-line SQL prompt for composing queries
- **NEW in v1.5**: Enhanced SQL prompt with command history navigation
- **NEW in v1.5**: Clean multiline paste support via `\paste` command
- **NEW in v1.5**: SQL-specific command history (separate from shell history)
- Session defaults via `csv:set:*` helpers (file, axes, filters, plot metadata)
- Scatter, line, and bar chart support with matplotlib overlays, custom axis scales/ranges, and categorical segmentation
- Head/tail previews, configurable pagers, and saved output targets
- **NEW in v1.5**: Graceful handling of pager exit (no more broken pipe errors)
- **NEW in v1.6**: Complete broken pipe protection including empty result sets
- Automatic integration with caddie's prompt and completion registries

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

## Changelog

### v1.6 (Current)
- **Complete Broken Pipe Protection**: Fixed remaining broken pipe error in empty result sets
- **Robust Error Handling**: All print statements now protected from pager exit scenarios

### v1.5
- **Enhanced SQL Prompt**: Added command history navigation with `\up`/`\down` and `\history N` commands
- **Clean Multiline Paste**: Added `\paste` command for seamless multiline query input
- **SQL-Specific History**: Commands are now stored in dedicated history separate from shell history
- **Improved Pager Experience**: Fixed broken pipe errors when exiting pagers (pressing 'q' in less)
- **Better User Experience**: Clean, professional interface with no ugly error messages

### v1.4
- Initial release with basic SQL querying and plotting capabilities

## Versioning

The module is versioned independently from caddie.sh

## Compatabilty

This module is compatible with caddie.sh version 2.2 and above
