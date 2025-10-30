#!/usr/bin/env bash

# Caddie CSV Tools - Query Module
# Handles query execution, plotting, and preview operations

function caddie_csv_script_path_internal() {
    local script_path="$HOME/.caddie_modules/bin/csvql.py"
    
    if [ -f "$script_path" ]; then
        printf '%s\n' "$script_path"
        return 0
    fi

    caddie cli:red "csvql.py not found at $script_path"
    caddie cli:thought "Run 'make install' to install csvql.py"
    return 1
}

function caddie_csv_require_axes_internal() {
    local plot_type="${1:-}"
    shift
    local has_cli_line_series=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --line-series|--line-series=*)
                has_cli_line_series=1
                break
                ;;
        esac
        shift
    done
    local x_value="${CADDIE_CSV_X:-}"
    local y_value="${CADDIE_CSV_Y:-}"
    local line_series_value="${CADDIE_CSV_LINE_SERIES:-}"

    if [ -z "$x_value" ]; then
        caddie cli:red "Set csv axes before plotting"
        caddie cli:thought "Example: caddie csv:set:x aim_offset_x"
        return 1
    fi

    if [ "$plot_type" = "line" ]; then
        if [ -z "$y_value" ] && [ -z "$line_series_value" ] && [ $has_cli_line_series -eq 0 ]; then
            caddie cli:red "Set a y column or configure line series before plotting line charts"
            caddie cli:thought "Example: caddie csv:set:y make_percentage"
            caddie cli:thought "         caddie csv:set:line_series makes=made_putts,misses=missed_putts"
            return 1
        fi
    else
        if [ -z "$y_value" ]; then
            caddie cli:red "Set csv axes before plotting"
            caddie cli:thought "Example: caddie csv:set:y aim_offset_y"
            return 1
        fi
    fi
    return 0
}

function caddie_csv_resolve_file_argument_internal() {
    local provided="$1"
    if [ -n "$provided" ]; then
        printf '%s' "$provided"
        return 0
    fi
    printf '%s' "${CADDIE_CSV_FILE:-}"
    return 0
}

function caddie_csv_resolve_pager_internal() {
    local configured="${CADDIE_CSV_PAGER:-}"
    if [ -n "$configured" ]; then
        if command -v "$configured" >/dev/null 2>&1; then
            printf '%s' "$configured"
            return 0
        fi
        caddie cli:warning "Configured pager '$configured' not found; falling back"
    fi

    if command -v less >/dev/null 2>&1; then
        printf '%s' "less"
        return 0
    fi

    if command -v more >/dev/null 2>&1; then
        printf '%s' "more"
        return 0
    fi

    printf '%s' "cat"
    return 0
}

function caddie_csv_validate_plot_type_internal() {
    local plot_type="$1"
    case "$plot_type" in
        scatter|line|bar)
            return 0
            ;;
    esac
    caddie cli:red "Invalid plot type: ${plot_type:-<unset>}"
    caddie cli:thought "Valid options: scatter, line, bar"
    return 1
}

function caddie_csv_plot_internal() {
    local plot_type="$1"
    local usage="$2"
    shift 2

    if [ -z "$plot_type" ]; then
        caddie cli:red "Error: plot type not set"
        caddie cli:usage "$usage"
        caddie cli:thought "Set a plot type with caddie csv:set:plot <scatter|line|bar>"
        return 1
    fi

    caddie_csv_validate_plot_type_internal "$plot_type" || return 1

    local script_path
    script_path=$(caddie_csv_script_path_internal) || return 1

    caddie_csv_require_axes_internal "$plot_type" "$@" || return 1

    local csv_file
    if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
        csv_file="$1"
        shift
    else
        csv_file=$(caddie_csv_resolve_file_argument_internal "")
    fi

    if [ -z "$csv_file" ]; then
        caddie cli:red "Error: CSV file required"
        caddie cli:usage "$usage"
        caddie cli:thought "Provide a file or set a default with caddie csv:set:file <path>"
        return 1
    fi

    local output_path=""
    if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
        output_path="$1"
        shift
    fi

    local plot_args=()
    plot_args+=("$csv_file" "--plot" "$plot_type")

    if [ "$plot_type" = "scatter" ]; then
        local scatter_filter="${CADDIE_CSV_SCATTER_FILTER:-}"
        if [ -n "$scatter_filter" ]; then
            plot_args+=("--success-filter" "$scatter_filter")
        fi
        local segment_column="${CADDIE_CSV_SEGMENT_COLUMN:-}"
        if [ -n "$segment_column" ]; then
            plot_args+=("--segment-column" "$segment_column")
        fi
        local segment_colors="${CADDIE_CSV_SEGMENT_COLORS:-}"
        if [ -n "$segment_colors" ]; then
            plot_args+=("--segment-colors" "$segment_colors")
        fi
    fi

    local x_scale="${CADDIE_CSV_X_SCALE:-}"
    if [ -n "$x_scale" ]; then
        plot_args+=("--x-scale" "$x_scale")
    fi

    local y_scale="${CADDIE_CSV_Y_SCALE:-}"
    if [ -n "$y_scale" ]; then
        plot_args+=("--y-scale" "$y_scale")
    fi

    local x_range="${CADDIE_CSV_X_RANGE:-}"
    if [ -n "$x_range" ]; then
        plot_args+=("--x-range" "$x_range")
    fi

    local y_range="${CADDIE_CSV_Y_RANGE:-}"
    if [ -n "$y_range" ]; then
        plot_args+=("--y-range" "$y_range")
    fi

    if [ -n "$output_path" ]; then
        plot_args+=("--save" "$output_path")
    fi

    if [ $# -gt 0 ]; then
        plot_args+=("$@")
    fi

    caddie cli:title "Rendering $plot_type plot for $csv_file"
    env CADDIE_CSV_SUPPRESS_OUTPUT=1 "$script_path" "${plot_args[@]}"
    local status=$?
    if [ $status -ne 0 ]; then
        caddie cli:red "$plot_type plot failed"
        return $status
    fi

    return 0
}

function caddie_csv_preview_internal() {
    local preview_cmd="$1"
    local action_label="$2"
    local usage="$3"
    shift 3

    if [ $# -gt 0 ]; then
        case "$1" in
            --help|-h)
                caddie cli:title "$action_label"
                caddie cli:usage "$usage"
                caddie cli:thought "Set a default file with caddie csv:set:file <path>"
                return 0
                ;;
        esac
    fi

    local file_candidate=""
    if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
        file_candidate="$1"
        shift
    fi

    local csv_file
    csv_file=$(caddie_csv_resolve_file_argument_internal "$file_candidate")

    if [ -z "$csv_file" ]; then
        caddie cli:red "Error: CSV file required"
        caddie cli:usage "$usage"
        caddie cli:thought "Provide a file or set a default with caddie csv:set:file <path>"
        return 1
    fi

    if [ ! -f "$csv_file" ]; then
        caddie cli:red "File not found: $csv_file"
        return 1
    fi

    caddie cli:title "$action_label for $csv_file"

    if [ $# -gt 0 ]; then
        command "$preview_cmd" "$@" "$csv_file"
    else
        command "$preview_cmd" "$csv_file"
    fi

    local status=$?
    if [ $status -ne 0 ]; then
        caddie cli:red "$preview_cmd command failed"
        return $status
    fi

    return 0
}

function caddie_csv_init() {
    local script_path
    script_path=$(caddie_csv_script_path_internal) || return 1

    caddie cli:title "Setting up csvql environment"

    "$script_path" --init

    local status=$?

    if [ $status -ne 0 ]; then
        caddie cli:red "csvql init failed"
        return $status
    fi

    caddie cli:check "csvql environment ready"

    return 0
}

function caddie_csv_query() {
    local script_path
    script_path=$(caddie_csv_script_path_internal) || return 1

    local csv_file
    if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
        csv_file="$1"
        shift
    else
        csv_file=$(caddie_csv_resolve_file_argument_internal "")
    fi

    if [ -z "$csv_file" ]; then
        caddie cli:red "Error: CSV file required"
        caddie cli:usage "caddie csv:set:file <path>"
        caddie cli:thought "Or pass the file explicitly: caddie csv:query data.csv"
        return 1
    fi

    caddie cli:title "Running csvql on $csv_file"
    local query_args=("$csv_file")
    if [ $# -gt 0 ]; then
        query_args+=("$@")
    fi

    local pager
    pager=$(caddie_csv_resolve_pager_internal)

    local status=0
    if [ "$pager" = "cat" ]; then
        env -u CADDIE_CSV_PLOT CADDIE_CSV_OUTPUT_MODE=full CADDIE_CSV_SUPPRESS_OUTPUT=0 "$script_path" "${query_args[@]}"
        status=$?
    else
        if [ "$pager" = "less" ] && [ -z "${LESS:-}" ]; then
            env -u CADDIE_CSV_PLOT CADDIE_CSV_OUTPUT_MODE=full CADDIE_CSV_SUPPRESS_OUTPUT=0 "$script_path" "${query_args[@]}" | LESS='-R -F -X' "$pager"
        else
            env -u CADDIE_CSV_PLOT CADDIE_CSV_OUTPUT_MODE=full CADDIE_CSV_SUPPRESS_OUTPUT=0 "$script_path" "${query_args[@]}" | "$pager"
        fi
        status=${PIPESTATUS[0]}
    fi

    if [ $status -ne 0 ]; then
        caddie cli:red "csvql execution failed"
        return $status
    fi
    return 0
}

function caddie_csv_query_summary() {
    local script_path
    script_path=$(caddie_csv_script_path_internal) || return 1

    local csv_file
    if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
        csv_file="$1"
        shift
    else
        csv_file=$(caddie_csv_resolve_file_argument_internal "")
    fi

    if [ -z "$csv_file" ]; then
        caddie cli:red "Error: CSV file required"
        caddie cli:usage "caddie csv:set:file <path>"
        caddie cli:thought "Or pass the file explicitly: caddie csv:query:summary data.csv"
        return 1
    fi

    caddie cli:title "Running csvql summary on $csv_file"
    local query_args=("$csv_file")
    if [ $# -gt 0 ]; then
        query_args+=("$@")
    fi

    env -u CADDIE_CSV_PLOT CADDIE_CSV_OUTPUT_MODE=summary CADDIE_CSV_SUPPRESS_OUTPUT=0 "$script_path" "${query_args[@]}"
    local status=$?
    if [ $status -ne 0 ]; then
        caddie cli:red "csvql execution failed"
        return $status
    fi
    return 0
}

function caddie_csv_plot() {
    local plot_type="${CADDIE_CSV_PLOT:-}"
    if [ -z "$plot_type" ]; then
        caddie cli:red "Plot type not set"
        caddie cli:usage "caddie csv:set:plot <scatter|line|bar>"
        return 1
    fi

    caddie_csv_plot_internal "$plot_type" "caddie csv:plot [file] [output] [-- options]" "$@"
    return $?
}

function caddie_csv_scatter() {
    caddie_csv_plot_internal "scatter" "caddie csv:scatter [file] [output] [-- options]" "$@"
    return $?
}

function caddie_csv_line() {
    if [ "${CADDIE_CSV_PLOT:-}" != "line" ]; then
        caddie cli:red "Plot type not set to line"
        caddie cli:usage "caddie csv:set:plot line"
        return 1
    fi

    caddie_csv_plot_internal "line" "caddie csv:line [file] [output] [-- options]" "$@"
    return $?
}

function caddie_csv_bar() {
    if [ "${CADDIE_CSV_PLOT:-}" != "bar" ]; then
        caddie cli:red "Plot type not set to bar"
        caddie cli:usage "caddie csv:set:plot bar"
        return 1
    fi

    caddie_csv_plot_internal "bar" "caddie csv:bar [file] [output] [-- options]" "$@"
    return $?
}

function caddie_csv_head() {
    caddie_csv_preview_internal head "Previewing first rows" "caddie csv:head [file] [head options]" "$@"
    return $?
}

function caddie_csv_tail() {
    caddie_csv_preview_internal tail "Previewing last rows" "caddie csv:tail [file] [tail options]" "$@"
    return $?
}
