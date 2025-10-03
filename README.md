# caddie-csv-tools

A standalone CSV/TSV analytics module for [caddie.sh](https://github.com/parnotfar/caddie.sh). It packages the `csv` commands (querying, plotting, previews) so they can evolve independently of the core caddie distribution.

## Features

- DuckDB-powered SQL querying with optional data visualisation
- Session defaults via `csv:set:*` helpers (file, axes, filters, plot metadata)
- Scatter, line, and bar chart support with matplotlib overlays
- Head/tail previews, configurable pagers, and saved output targets

## Installation

```bash
git clone https://github.com/parnotfar/caddie-csv-tools.git
cd caddie-csv-tools
make install
caddie reload
```

The `install` target copies `modules/dot_caddie_csv.sh` into `~/.caddie_modules/.caddie_csv` and places `bin/csvql.py` in `~/.caddie_modules/bin/`. After reloading caddie the `csv:*` commands are available as before.

To remove the module:

```bash
make uninstall
caddie reload
```

## Development

Run the caddie linter against the module:

```bash
make lint
```

See [`docs/usage.md`](docs/usage.md) for comprehensive documentation and command examples.

## Versioning

The module is versioned independently from caddie. The current release is **1.0.0**.
