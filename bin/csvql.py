#!/usr/bin/env python3
"""Lightweight CSV/TSV SQL and plotting helper for caddie.sh."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import textwrap
from pathlib import Path
import venv

SCRIPT_PATH = Path(__file__).resolve()
SCRIPT_DIR = SCRIPT_PATH.parent
VENV_DIR = SCRIPT_DIR / ".caddie_venv"
REQUIREMENTS_PATH = SCRIPT_DIR / "requirements.txt"
DEPENDENCIES = ["duckdb", "pandas", "matplotlib"]
DEFAULT_SEGMENT_PALETTE = ["#1b9e77", "#d95f02", "#7570b3"]
MISSING_SEGMENT_COLOR = "#9e9e9e"


def env_bool(name: str, default: bool = False) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def env_float(name: str, default: float) -> float:
    value = os.environ.get(name)
    if value is None or value.strip() == "":
        return default
    try:
        return float(value)
    except ValueError as exc:  # pragma: no cover - defensive guard
        raise SystemExit(f"Invalid float for {name}: {value}") from exc


def env_int(name: str, default: int | None) -> int | None:
    value = os.environ.get(name)
    if value is None or value.strip() == "":
        return default
    try:
        return int(value)
    except ValueError as exc:  # pragma: no cover - defensive guard
        raise SystemExit(f"Invalid integer for {name}: {value}") from exc


def get_venv_python() -> Path:
    if os.name == "nt":  # pragma: no cover - windows guard
        return VENV_DIR / "Scripts" / "python.exe"
    return VENV_DIR / "bin" / "python"


def in_project_venv() -> bool:
    try:
        return Path(sys.prefix).resolve() == VENV_DIR.resolve()
    except FileNotFoundError:
        return False


def ensure_initialized(show_next_steps: bool = True) -> bool:
    created = False
    def emit(message: str) -> None:
        stream = sys.stdout if show_next_steps else sys.stderr
        print(message, file=stream)

    if not VENV_DIR.exists():
        VENV_DIR.mkdir(parents=True, exist_ok=True)
        venv.EnvBuilder(with_pip=True).create(VENV_DIR)
        created = True
        emit(f"Created virtual environment at {VENV_DIR}")
    else:
        emit(f"Using existing virtual environment at {VENV_DIR}")
    python = get_venv_python()
    if not python.exists():
        raise SystemExit("Virtual environment bootstrap failed; python not found")
    subprocess.run([str(python), "-m", "pip", "install", "--upgrade", "pip"], check=True)
    subprocess.run([str(python), "-m", "pip", "install", "--upgrade", *DEPENDENCIES], check=True)
    freeze = subprocess.run([str(python), "-m", "pip", "freeze"], check=True, capture_output=True, text=True)
    REQUIREMENTS_PATH.write_text(freeze.stdout, encoding="utf-8")
    if show_next_steps:
        emit("Dependencies installed. Next steps:")
        emit("  • Run csvql.py <file.csv> --plot scatter --x X --y Y")
        emit("  • Use --help for full usage details")
    return created


def reexec_inside_venv(argv: list[str]) -> None:
    python = get_venv_python()
    if not python.exists():
        raise SystemExit("Virtual environment is not ready; run with --init")
    os.execv(str(python), [str(python), str(SCRIPT_PATH), *argv])


def apply_success_filter(query: str, condition: str | None) -> str:
    if not condition:
        return query
    query_body = query.strip().rstrip(";")
    split_at = len(query_body)
    keyword_pattern = re.compile(r"\b(order\s+by|group\s+by|limit|having|qualify)\b", re.IGNORECASE)
    match = keyword_pattern.search(query_body)
    if match:
        split_at = match.start()
    head = query_body[:split_at]
    tail = query_body[split_at:]
    head_stripped = head.rstrip()
    trailing_ws = head[len(head_stripped):]
    head_searchable = re.sub(r"--.*?$", "", head_stripped, flags=re.MULTILINE)
    head_searchable = re.sub(r"/\*.*?\*/", "", head_searchable, flags=re.DOTALL)
    if re.search(r"\bwhere\b", head_searchable, re.IGNORECASE):
        head_stripped = f"{head_stripped} AND ({condition})"
    else:
        head_stripped = f"{head_stripped} WHERE {condition}"
    if tail and not tail[0].isspace():
        tail = f" {tail}"
    return f"{head_stripped}{trailing_ws}{tail}".strip()


def parse_ring_radii(raw: str | None) -> list[float]:
    if not raw:
        return []
    radii = []
    for chunk in raw.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        try:
            radii.append(float(chunk))
        except ValueError as exc:
            raise SystemExit(f"Invalid ring radius: {chunk}") from exc
    return radii


def parse_axis_range(raw: str | None) -> tuple[float | None, float | None, list[float]]:
    if not raw:
        return None, None, []
    spec = raw.strip()
    if not spec:
        return None, None, []
    if spec[0] in {"[", "("} and spec[-1] in {"]", ")"} and len(spec) >= 2:
        spec = spec[1:-1]
    parts = [part.strip() for part in spec.split(",")]
    if not parts:
        return None, None, []

    def convert(token: str) -> float | None:
        if not token:
            return None
        lowered = token.lower()
        if lowered in {"none", "null", "auto"}:
            return None
        if lowered in {"+inf", "inf"}:
            return float("inf")
        if lowered == "-inf":
            return float("-inf")
        try:
            return float(token)
        except ValueError as exc:
            raise SystemExit(f"Invalid axis range value: {token}") from exc

    lower = convert(parts[0])
    upper = convert(parts[-1]) if len(parts) > 1 else None
    ticks: list[float] = []
    if len(parts) > 2:
        seen: set[float] = set()
        for token in parts[1:-1]:
            value = convert(token)
            if value is None:
                continue
            if value not in seen:
                ticks.append(value)
                seen.add(value)
    return lower, upper, ticks


def resolve_segment_colors(raw: str | None, count: int) -> list[str]:
    if count <= 0:
        return []
    if raw:
        colors = [chunk.strip() for chunk in raw.split(",") if chunk.strip()]
        if len(colors) < count:
            raise SystemExit(f"--segment-colors requires at least {count} colors")
        return colors[:count]
    if count <= len(DEFAULT_SEGMENT_PALETTE):
        return DEFAULT_SEGMENT_PALETTE[:count]
    try:
        import matplotlib

        if count <= 10:
            cmap = matplotlib.cm.get_cmap('tab10', count)
        elif count <= 20:
            cmap = matplotlib.cm.get_cmap('tab20', count)
        else:
            cmap = matplotlib.cm.get_cmap('hsv', count)
        return [matplotlib.colors.to_hex(cmap(index)) for index in range(count)]
    except Exception:  # pragma: no cover - defensive fallback
        return DEFAULT_SEGMENT_PALETTE + [DEFAULT_SEGMENT_PALETTE[-1]] * (count - len(DEFAULT_SEGMENT_PALETTE))


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Query CSV/TSV files with DuckDB SQL and optional plotting.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("csvfile", nargs="?", help="Path to the CSV/TSV file")
    parser.add_argument(
        "sql_query",
        nargs="?",
        default=os.environ.get("CADDIE_CSV_SQL"),
        help="Override SQL query; defaults to CADDIE_CSV_SQL or SELECT * FROM df",
    )
    parser.add_argument("--init", action="store_true", help="Bootstrap or update local virtualenv and dependencies")
    parser.add_argument("--plot", choices=["scatter", "line", "bar"], default=os.environ.get("CADDIE_CSV_PLOT"))
    parser.add_argument("--x", dest="x", default=os.environ.get("CADDIE_CSV_X"), help="X-axis column for plotting")
    parser.add_argument("--y", dest="y", default=os.environ.get("CADDIE_CSV_Y"), help="Y-axis column for plotting")
    parser.add_argument("--sep", default=os.environ.get("CADDIE_CSV_SEP", ","), help="Field separator for the input file")
    parser.add_argument("--limit", type=int, default=env_int("CADDIE_CSV_LIMIT", None), help="Row limit applied to plots; terminal preview shows the first and last 10 rows")
    parser.add_argument("--save", default=os.environ.get("CADDIE_CSV_SAVE"), help="Path to save plot image instead of showing it")
    parser.add_argument("--title", default=os.environ.get("CADDIE_CSV_TITLE"), help="Plot title override")
    parser.add_argument("--success-filter", default=os.environ.get("CADDIE_CSV_SUCCESS_FILTER"), help="SQL predicate to filter successful rows")
    circle_default = env_bool("CADDIE_CSV_CIRCLE", False)
    parser.add_argument("--circle", dest="circle", action="store_true", default=circle_default, help="Overlay a circle outline on plots")
    parser.add_argument("--no-circle", dest="circle", action="store_false", help="Disable circle overlay even if enabled via environment")
    rings_default = env_bool("CADDIE_CSV_RINGS", False)
    parser.add_argument("--rings", dest="rings", action="store_true", default=rings_default, help="Overlay bullseye rings on plots")
    parser.add_argument("--no-rings", dest="rings", action="store_false", help="Disable ring overlay even if enabled via environment")
    parser.add_argument("--circle-x", type=float, default=env_float("CADDIE_CSV_CIRCLE_X", 0.0), help="X position for circle center")
    parser.add_argument("--circle-y", type=float, default=env_float("CADDIE_CSV_CIRCLE_Y", 0.0), help="Y position for circle center")
    parser.add_argument("--circle-r", type=float, default=env_float("CADDIE_CSV_CIRCLE_R", 1.0), help="Circle radius")
    parser.add_argument("--circle-radii", dest="circle_radii", default=os.environ.get("CADDIE_CSV_CIRCLE_RADII"), help="Comma-separated radii for additional circles")
    parser.add_argument("--x-scale", dest="x_scale", default=os.environ.get("CADDIE_CSV_X_SCALE"), help="Set matplotlib scale for the x-axis (e.g. linear, log)")
    parser.add_argument("--y-scale", dest="y_scale", default=os.environ.get("CADDIE_CSV_Y_SCALE"), help="Set matplotlib scale for the y-axis (e.g. linear, log)")
    parser.add_argument("--x-range", dest="x_range", default=os.environ.get("CADDIE_CSV_X_RANGE"), help="Override the displayed x-axis range; supports bracket, parenthesis, or comma-delimited forms")
    parser.add_argument("--y-range", dest="y_range", default=os.environ.get("CADDIE_CSV_Y_RANGE"), help="Override the displayed y-axis range; same format as --x-range")
    parser.add_argument("--segment-column", dest="segment_column", default=os.environ.get("CADDIE_CSV_SEGMENT_COLUMN"), help="Categorical column used to color scatter plots")
    parser.add_argument("--segment-colors", dest="segment_colors", default=os.environ.get("CADDIE_CSV_SEGMENT_COLORS"), help="Comma-separated colors matched to the segment values (falls back to tab10 palette)")
    return parser.parse_args(argv)


def require_columns(columns: list[str], df_columns: list[str]) -> None:
    missing = [col for col in columns if col and col not in df_columns]
    if missing:
        raise SystemExit(f"Missing columns in result set: {', '.join(missing)}")


def maybe_plot(df, args: argparse.Namespace) -> None:
    if not args.plot:
        return
    import pandas as pd  # noqa: F401 - ensures pandas is available before plotting
    import matplotlib

    if args.save:
        matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    x_col = args.x
    y_col = args.y
    if args.plot in {"scatter", "line", "bar"}:
        if not x_col or not y_col:
            raise SystemExit("Plotting requires both --x and --y (or CADDIE_CSV_X/CADDIE_CSV_Y)")
        require_columns([x_col, y_col], list(df.columns))
    segment_column = getattr(args, "segment_column", None)
    if segment_column:
        if args.plot != "scatter":
            raise SystemExit("--segment-column is only supported with scatter plots")
        require_columns([segment_column], list(df.columns))
    plot_df = df
    if args.limit is not None:
        if args.limit <= 0:
            raise SystemExit("--limit must be a positive integer")
        plot_df = df.head(args.limit)
    fig, ax = plt.subplots(figsize=(8, 6))
    if args.plot == "scatter":
        if segment_column:
            segment_series = plot_df[segment_column]
            non_null_mask = segment_series.notna()
            unique_values = list(pd.unique(segment_series[non_null_mask]))
            if unique_values:
                colors = resolve_segment_colors(args.segment_colors, len(unique_values))
                for value, color in zip(unique_values, colors):
                    mask = segment_series == value
                    ax.scatter(
                        plot_df.loc[mask, x_col],
                        plot_df.loc[mask, y_col],
                        alpha=0.8,
                        edgecolor="black",
                        linewidth=0.5,
                        label=f"{segment_column} = {value}",
                        color=color,
                    )
                if (~non_null_mask).any():
                    ax.scatter(
                        plot_df.loc[~non_null_mask, x_col],
                        plot_df.loc[~non_null_mask, y_col],
                        alpha=0.5,
                        edgecolor="black",
                        linewidth=0.4,
                        label=f"{segment_column} = <missing>",
                        color=MISSING_SEGMENT_COLOR,
                    )
                ax.legend(title=segment_column)
            else:
                ax.scatter(plot_df[x_col], plot_df[y_col], alpha=0.8, edgecolor="black", linewidth=0.5)
        else:
            ax.scatter(plot_df[x_col], plot_df[y_col], alpha=0.8, edgecolor="black", linewidth=0.5)
    elif args.plot == "line":
        ax.plot(plot_df[x_col], plot_df[y_col], marker="o")
    elif args.plot == "bar":
        ax.bar(plot_df[x_col], plot_df[y_col])
    if args.title:
        ax.set_title(args.title)
    ax.set_xlabel(x_col if x_col else "")
    ax.set_ylabel(y_col if y_col else "")
    if args.x_scale:
        try:
            ax.set_xscale(args.x_scale)
        except ValueError as exc:
            raise SystemExit(f"Invalid x-axis scale '{args.x_scale}': {exc}") from exc
    if args.y_scale:
        try:
            ax.set_yscale(args.y_scale)
        except ValueError as exc:
            raise SystemExit(f"Invalid y-axis scale '{args.y_scale}': {exc}") from exc
    x_lower, x_upper, x_ticks = parse_axis_range(getattr(args, "x_range", None))
    if x_lower is not None or x_upper is not None:
        ax.set_xlim(left=x_lower, right=x_upper)
    if x_ticks:
        ax.set_xticks(x_ticks)
    y_lower, y_upper, y_ticks = parse_axis_range(getattr(args, "y_range", None))
    if y_lower is not None or y_upper is not None:
        ax.set_ylim(bottom=y_lower, top=y_upper)
    if y_ticks:
        ax.set_yticks(y_ticks)
    if args.circle:
        circle = plt.Circle((args.circle_x, args.circle_y), args.circle_r, fill=False, color="darkgreen", linewidth=1.5)
        ax.add_patch(circle)
        ax.set_aspect("equal", adjustable="datalim")
    if args.rings:
        for idx, radius in enumerate(parse_ring_radii(args.circle_radii), start=1):
            ring = plt.Circle((args.circle_x, args.circle_y), radius, fill=False, linestyle="--", linewidth=1.0, color="orange")
            ax.add_patch(ring)
            ax.text(args.circle_x, args.circle_y + radius, f"Ring {idx}", color="orange", fontsize=8, ha="center")
        ax.set_aspect("equal", adjustable="datalim")
    ax.grid(True, linestyle="--", alpha=0.3)
    fig.tight_layout()
    if args.save:
        fig.savefig(args.save, dpi=150)
        print(f"Saved plot to {args.save}")
    else:
        plt.show()
    plt.close(fig)


def print_dataframe(df, mode: str) -> None:
    import pandas as pd

    row_count = len(df)
    mode = mode.lower()
    if mode != "full":
        mode = "summary"

    try:
        if row_count == 0:
            print("(no rows)")
            return

        if mode == "summary":
            preview = 10
            with pd.option_context("display.max_rows", None, "display.max_columns", None, "display.width", 0):
                if row_count <= preview * 2:
                    print(df.to_string(index=False))
                else:
                    print(f"Showing first {preview} of {row_count} rows:")
                    print(df.head(preview).to_string(index=False))
                    print("…")
                    print(f"Showing last {preview} of {row_count} rows:")
                    print(df.tail(preview).to_string(index=False))
        else:
            with pd.option_context("display.max_rows", None, "display.max_columns", None, "display.width", 0):
                print(df.to_string(index=False))
    except BrokenPipeError:
        # Handle broken pipe gracefully when pager exits (e.g., pressing 'q' in less)
        sys.stderr.close()
        sys.exit(0)


def run_query(args: argparse.Namespace) -> None:
    import duckdb

    csv_path = Path(args.csvfile).expanduser().resolve()
    if not csv_path.exists():
        raise SystemExit(f"Input file not found: {csv_path}")
    conn = duckdb.connect(database=":memory:")
    try:
        conn.execute(
            "CREATE OR REPLACE TABLE df AS SELECT * FROM read_csv_auto(?, HEADER=TRUE, SEP=?)",
            [str(csv_path), args.sep],
        )
        base_query = args.sql_query or "SELECT * FROM df"
        final_query = apply_success_filter(base_query, args.success_filter)
        df = conn.execute(final_query).df()
    finally:
        conn.close()
    suppress_output = env_bool("CADDIE_CSV_SUPPRESS_OUTPUT", False)
    output_mode_raw = os.environ.get("CADDIE_CSV_OUTPUT_MODE", "summary")
    output_mode = output_mode_raw.strip().lower() if output_mode_raw else "summary"
    if output_mode not in {"full", "summary"}:
        output_mode = "full"
    if not suppress_output:
        print_dataframe(df, output_mode)
    maybe_plot(df, args)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.init and not args.csvfile:
        ensure_initialized(show_next_steps=True)
        return 0
    if args.init:
        ensure_initialized(show_next_steps=True)
        # fall through to run the query against the provided file after init
    if not args.csvfile:
        print("error: CSV file required", file=sys.stderr)
        print("Hint: run with --init to bootstrap dependencies", file=sys.stderr)
        return 1
    if not in_project_venv():
        created = False
        if not VENV_DIR.exists():
            print("Bootstrapping csvql environment...", file=sys.stderr)
            ensure_initialized(show_next_steps=False)
            created = True
        if not created:
            # dependencies may have drifted; ensure venv has them installed once
            if not get_venv_python().exists():
                ensure_initialized(show_next_steps=False)
        reexec_inside_venv(argv)
    run_query(args)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
