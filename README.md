# caddie-csv-tools

A standalone CSV/TSV analytics module for [caddie.sh](https://github.com/parnotfar/caddie.sh). It packages the `csv`
commands (querying, plotting, previews) so they can evolve independently of the core caddie distribution.

## Version

2.5

## Features

- DuckDB-powered SQL querying with optional data visualisation
- Interactive, multi-line SQL prompt for composing queries
- **NEW in v1.5**: Enhanced SQL prompt with command history navigation
- **NEW in v1.5**: Clean multiline paste support via `\paste` command
- **NEW in v1.5**: SQL-specific command history (separate from shell history)
- Session defaults via `csv:set:*` helpers (file, axes, filters, plot metadata)
- Scatter, line, and bar chart support with matplotlib overlays, custom axis scales/ranges, and categorical segmentation
- **NEW in v2.1**: Configure multi-series line plots via `csv:set:line_series` or `--line-series`
- **NEW in v2.3**: Query directories / globs (`csv:query:dir`, `csv:query:dir:pattern`) for multi-file analysis
- Head/tail previews, configurable pagers, and saved output targets
- **NEW in v2.4**: `csv:header` / `csv:columns` to list column names and types (`\headers` in the SQL prompt)
- **NEW in v2.4**: No mass `export -f` (aligned with caddie 10.0 — source-based loading only)
- **NEW in v2.5**: Universal command and namespace help through the caddie.sh 11.5 core harness
- **NEW in v1.5**: Graceful handling of pager exit (no more broken pipe errors)
- **NEW in v1.6**: Complete broken pipe protection including empty result sets
- **NEW in v2.0**: External editor integration for complex SQL composition
- Automatic integration with caddie's prompt and completion registries

## Installation

```bash
caddie github:set:account parnotfar
caddie git:clone caddie-csv-tools (optional: git clone https://github.com/parnotfar/caddie-csv-tools.git)
cd caddie-csv-tools
make install
caddie reload
```

The `install` target copies the modular structure into the caddie module directory. The main entry point (`dot_caddie_csv.sh`) now sources all the modular components automatically.

To remove the module:

```bash
make uninstall
caddie reload
```

## Project Structure

The module is organized into logical components:

```
src/
├── caddie_csv_core.sh      # Core initialization, globals, and environment management
├── caddie_csv_session.sh   # Session management (save, restore, delete, list)
├── caddie_csv_settings.sh  # Settings management (set/get/unset commands)
├── caddie_csv_sql.sh       # SQL prompt, history, editing, and related functionality
├── caddie_csv_query.sh     # Query execution, plotting, and preview operations
├── caddie_csv_prompt.sh    # Natural language prompt processing
└── caddie_csv_main.sh      # Main entry point and command registration

modules/
└── dot_caddie_csv.sh       # Main entry point (sources all modules)

bin/
└── csvql.py                # Python script for SQL execution and plotting
```

**Installation Structure:**
```
~/.caddie_modules/
├── .caddie_csv             # Main entry point
├── .caddie_csv_version     # Version information
├── caddie-csv-src/         # Module source files (properly namespaced)
│   ├── caddie_csv_core.sh
│   ├── caddie_csv_session.sh
│   ├── caddie_csv_settings.sh
│   ├── caddie_csv_sql.sh
│   ├── caddie_csv_query.sh
│   ├── caddie_csv_prompt.sh
│   └── caddie_csv_main.sh
└── bin/
    └── csvql.py
```

### Modular Architecture Benefits

- **Maintainability**: Each module has a single responsibility
- **Readability**: Easier to understand and navigate the codebase
- **Testability**: Individual modules can be tested in isolation
- **Extensibility**: New features can be added to specific modules
- **Debugging**: Issues can be traced to specific functional areas

Tab completion and the `[csv:…]` prompt indicator are registered automatically when the module is sourced.

## Development

Run the caddie linter against the module:

```bash
cd caddie-csv-tools
caddie core:lint
```

See [`docs/usage.md`](docs/usage.md) for comprehensive documentation and command examples.

## Changelog

### v2.5 (Current) - Core Command Help
- **Command Help**: Every registered command supports both `caddie csv:<command> --help` and `caddie csv:<command>:help`
- **Namespace Help**: Command families such as `csv:session` support the same symmetric help forms
- **Core Contract**: Requires caddie.sh 11.5.0 or later; live command metadata remains authoritative

### v2.4 - Headers & caddie 10.0 Alignment
- **Column Inspection**: `csv:header` / `csv:columns` list column names and inferred DuckDB types (`csvql.py --headers`)
- **SQL Prompt**: `\headers` / `\columns` run the same listing for the active CSV file
- **No Mass `export -f`**: Module functions are sourced only (aligned with caddie.sh 10.0; avoids `BASH_FUNC_*` pollution in child shells)

### v2.3 - Multi-File Querying
- **Directory Querying**: Query all CSV files in a directory with `csv:query:dir`
- **Pattern Querying**: Query directory matches with `csv:query:dir:pattern`
- **SQL File Runner**: Execute saved queries with `csv:query:sql:file`

### v2.1 - Multi-Line Plot Enhancements
- **Multiple Series Per Plot**: Define `label=column` pairs once with `csv:set:line_series`
- **On-Demand Overrides**: Use `--line-series` with `caddie csv:line` for ad-hoc comparisons
- **Prompt Integration**: Natural language prompts understand `line series` syntax

### v2.0 - Major Feature Release
- **External Editor Integration**: Added `\edit` command to open SQL buffer in user's editor
- **Enhanced SQL Composition**: Use `\e` (short alias) to edit complex queries in vim/emacs/etc.
- **Seamless Workflow**: Editor integration with automatic buffer updates and execution
- **Professional Development Experience**: Full-featured SQL editing with syntax highlighting

### v1.6
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

## Compatibility

Version 2.5 requires caddie.sh 11.5.0 or later for generated command and namespace help. Use `caddie` / `caddie agent:exec` (or source the module) in child shells.
