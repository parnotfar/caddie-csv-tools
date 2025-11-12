#!/usr/bin/env bash

# Caddie CSV Tools - Settings Management Module
# Handles set/get/unset commands for all configuration options

function caddie_csv_set_alias_internal() {
    local alias="$1"
    local usage="$2"
    shift 2
    local value="$*"

    if [ -z "$value" ]; then
        caddie cli:red "Error: value required"
        caddie cli:usage "$usage"
        return 1
    fi

    local env
    env=$(caddie_csv_env_name "$alias") || return 1
    export "$env=$value"
    caddie cli:check "Set ${alias//_/ } to $value"
    return 0
}

function caddie_csv_show_alias_internal() {
    local alias="$1"
    local unformatted=$2
    local env
    env=$(caddie_csv_env_name "$alias") || return 1
    local value="${!env:-}"

    if [ -n "$value" ]; then
        if [ -n "$unformatted" ]; then
            printf '%s\n' "$value"
            return 0
        fi

        caddie cli:package "${alias//_/ } = $value"
    else
        caddie cli:warning "${alias//_/ } not set"
    fi
    return 0
}

function caddie_csv_unset_alias_internal() {
    local alias="$1"
    local env
    env=$(caddie_csv_env_name "$alias") || return 1
    if [ -n "${!env-}" ]; then
        unset "$env"
        caddie cli:check "Cleared ${alias//_/ }"
    else
        caddie cli:warning "${alias//_/ } already unset"
    fi
    return 0
}

function caddie_csv_unset_all() {
    local alias
    for alias in "${CADDIE_CSV_KEY_ORDER[@]}"; do
        caddie_csv_unset_alias_internal "$alias" >/dev/null
    done
    caddie cli:check "Cleared all CSV session defaults"
    return 0
}

function caddie_csv_list() {
    caddie cli:title "CSV session defaults"
    local alias
    local env
    local value
    for alias in "${CADDIE_CSV_KEY_ORDER[@]}"; do
        env=$(caddie_csv_env_name "$alias") || continue
        value="${!env:-}"
        if [ -n "$value" ]; then
            printf '  %-17s %s\n' "$alias" "$value"
        else
            printf '  %-17s (unset)\n' "$alias"
        fi
    done
    return 0
}

# File operations
function caddie_csv_set_file()          { caddie_csv_set_alias_internal file "caddie csv:set:file <path>" "$@"; return $?; }
function caddie_csv_get_file()          { caddie_csv_show_alias_internal file unformatted; return $?; }
function caddie_csv_unset_file()        { caddie_csv_unset_alias_internal file; return $?; }

# Axis operations
function caddie_csv_set_x()             { caddie_csv_set_alias_internal x "caddie csv:set:x <column>" "$@"; return $?; }
function caddie_csv_get_x()             { caddie_csv_show_alias_internal x; return $?; }
function caddie_csv_unset_x()           { caddie_csv_unset_alias_internal x; return $?; }

function caddie_csv_set_y()             { caddie_csv_set_alias_internal y "caddie csv:set:y <column>" "$@"; return $?; }
function caddie_csv_get_y()             { caddie_csv_show_alias_internal y; return $?; }
function caddie_csv_unset_y()           { caddie_csv_unset_alias_internal y; return $?; }

function caddie_csv_set_line_series() {
    local usage="caddie csv:set:line_series <label=column[,label=column]...>"
    if [ $# -eq 0 ]; then
        caddie cli:red "Error: line series specification required"
        caddie cli:usage "$usage"
        caddie cli:thought "Example: caddie csv:set:line_series makes=made_putts,misses=missed_putts"
        return 1
    fi
    local spec="$*"
    caddie_csv_set_alias_internal line_series "$usage" "$spec"
    return $?
}
function caddie_csv_get_line_series()  { caddie_csv_show_alias_internal line_series; return $?; }
function caddie_csv_unset_line_series(){ caddie_csv_unset_alias_internal line_series; return $?; }

# Separator operations
function caddie_csv_set_sep()           { caddie_csv_set_alias_internal sep "caddie csv:set:sep <separator>" "$@"; return $?; }
function caddie_csv_get_sep()           { caddie_csv_show_alias_internal sep; return $?; }
function caddie_csv_unset_sep()         { caddie_csv_unset_alias_internal sep; return $?; }

# Plot operations
function caddie_csv_set_plot() {
    local usage="caddie csv:set:plot <scatter|line|bar>"
    if [ $# -eq 0 ]; then
        caddie cli:red "Error: plot type required"
        caddie cli:usage "$usage"
        return 1
    fi
    if [ $# -gt 1 ]; then
        caddie cli:red "Error: plot type must be a single value"
        caddie cli:usage "$usage"
        return 1
    fi
    local plot_type="$1"
    case "$plot_type" in
        scatter|line|bar)
            ;;
        *)
            caddie cli:red "Invalid plot type: $plot_type"
            caddie cli:usage "$usage"
            caddie cli:thought "Valid options: scatter, line, bar"
            return 1
            ;;
    esac
    caddie_csv_set_alias_internal plot "$usage" "$plot_type"
    return $?
}
function caddie_csv_get_plot()          { caddie_csv_show_alias_internal plot; return $?; }
function caddie_csv_unset_plot()        { caddie_csv_unset_alias_internal plot; return $?; }

# Title operations
function caddie_csv_set_title()         { caddie_csv_set_alias_internal title "caddie csv:set:title <text>" "$@"; return $?; }
function caddie_csv_get_title()         { caddie_csv_show_alias_internal title; return $?; }
function caddie_csv_unset_title()       { caddie_csv_unset_alias_internal title; return $?; }

# Limit operations
function caddie_csv_set_limit()         { caddie_csv_set_alias_internal limit "caddie csv:set:limit <rows>" "$@"; return $?; }
function caddie_csv_get_limit()         { caddie_csv_show_alias_internal limit; return $?; }
function caddie_csv_unset_limit()       { caddie_csv_unset_alias_internal limit; return $?; }

# Save operations
function caddie_csv_set_save()          { caddie_csv_set_alias_internal save "caddie csv:set:save <path>" "$@"; return $?; }
function caddie_csv_get_save()          { caddie_csv_show_alias_internal save; return $?; }
function caddie_csv_unset_save()        { caddie_csv_unset_alias_internal save; return $?; }

# Pager operations
function caddie_csv_set_pager() {
    local usage="caddie csv:set:pager <command>"
    if [ $# -eq 0 ]; then
        caddie cli:red "Error: pager command required"
        caddie cli:usage "$usage"
        caddie cli:thought "Examples: less, more, cat"
        return 1
    fi

    if [ $# -gt 1 ]; then
        caddie cli:red "Error: pager must be a single command"
        caddie cli:usage "$usage"
        return 1
    fi

    local pager="$1"
    if ! command -v "$pager" >/dev/null 2>&1; then
        caddie cli:red "Pager not found: $pager"
        caddie cli:thought "Install it or choose a different pager"
        return 1
    fi

    caddie_csv_set_alias_internal pager "$usage" "$pager"
    return $?
}
function caddie_csv_get_pager()          { caddie_csv_show_alias_internal pager; return $?; }
function caddie_csv_unset_pager()        { caddie_csv_unset_alias_internal pager; return $?; }

# Filter operations
function caddie_csv_set_success_filter(){ caddie_csv_set_alias_internal success_filter "caddie csv:set:success_filter <predicate>" "$@"; return $?; }
function caddie_csv_get_success_filter(){ caddie_csv_show_alias_internal success_filter; return $?; }
function caddie_csv_unset_success_filter(){ caddie_csv_unset_alias_internal success_filter; return $?; }

function caddie_csv_set_scatter_filter(){ caddie_csv_set_alias_internal scatter_filter "caddie csv:set:scatter_filter <predicate>" "$@"; return $?; }
function caddie_csv_get_scatter_filter(){ caddie_csv_show_alias_internal scatter_filter; return $?; }
function caddie_csv_unset_scatter_filter(){ caddie_csv_unset_alias_internal scatter_filter; return $?; }

# Scale operations
function caddie_csv_set_x_scale(){ caddie_csv_set_alias_internal x_scale "caddie csv:set:x_scale <scale>" "$@"; return $?; }
function caddie_csv_get_x_scale(){ caddie_csv_show_alias_internal x_scale; return $?; }
function caddie_csv_unset_x_scale(){ caddie_csv_unset_alias_internal x_scale; return $?; }

function caddie_csv_set_y_scale(){ caddie_csv_set_alias_internal y_scale "caddie csv:set:y_scale <scale>" "$@"; return $?; }
function caddie_csv_get_y_scale(){ caddie_csv_show_alias_internal y_scale; return $?; }
function caddie_csv_unset_y_scale(){ caddie_csv_unset_alias_internal y_scale; return $?; }

# Range operations
function caddie_csv_set_x_range(){ caddie_csv_set_alias_internal x_range "caddie csv:set:x_range <start,end[,ticks...]>" "$@"; return $?; }
function caddie_csv_get_x_range(){ caddie_csv_show_alias_internal x_range; return $?; }
function caddie_csv_unset_x_range(){ caddie_csv_unset_alias_internal x_range; return $?; }

function caddie_csv_set_y_range(){ caddie_csv_set_alias_internal y_range "caddie csv:set:y_range <start,end[,ticks...]>" "$@"; return $?; }
function caddie_csv_get_y_range(){ caddie_csv_show_alias_internal y_range; return $?; }
function caddie_csv_unset_y_range(){ caddie_csv_unset_alias_internal y_range; return $?; }

# Segment operations
function caddie_csv_set_segment_column(){ caddie_csv_set_alias_internal segment_column "caddie csv:set:segment_column <column>" "$@"; return $?; }
function caddie_csv_get_segment_column(){ caddie_csv_show_alias_internal segment_column; return $?; }
function caddie_csv_unset_segment_column(){ caddie_csv_unset_alias_internal segment_column; return $?; }

function caddie_csv_set_segment_colors(){ caddie_csv_set_alias_internal segment_colors "caddie csv:set:segment_colors <color1,color2>" "$@"; return $?; }
function caddie_csv_get_segment_colors(){ caddie_csv_show_alias_internal segment_colors; return $?; }
function caddie_csv_unset_segment_colors(){ caddie_csv_unset_alias_internal segment_colors; return $?; }

# SQL operations
function caddie_csv_set_sql()           { caddie_csv_set_alias_internal sql "caddie csv:set:sql <query>" "$@"; return $?; }
function caddie_csv_get_sql()           { caddie_csv_show_alias_internal sql; return $?; }
function caddie_csv_unset_sql()         { caddie_csv_unset_alias_internal sql; return $?; }

# Circle operations
function caddie_csv_set_circle()        { caddie_csv_set_alias_internal circle "caddie csv:set:circle <on|off>" "$@"; return $?; }
function caddie_csv_get_circle()        { caddie_csv_show_alias_internal circle; return $?; }
function caddie_csv_unset_circle()      { caddie_csv_unset_alias_internal circle; return $?; }

function caddie_csv_set_rings()         { caddie_csv_set_alias_internal rings "caddie csv:set:rings <on|off>" "$@"; return $?; }
function caddie_csv_get_rings()         { caddie_csv_show_alias_internal rings; return $?; }
function caddie_csv_unset_rings()       { caddie_csv_unset_alias_internal rings; return $?; }

function caddie_csv_set_circle_x()      { caddie_csv_set_alias_internal circle_x "caddie csv:set:circle_x <value>" "$@"; return $?; }
function caddie_csv_get_circle_x()      { caddie_csv_show_alias_internal circle_x; return $?; }
function caddie_csv_unset_circle_x()    { caddie_csv_unset_alias_internal circle_x; return $?; }

function caddie_csv_set_circle_y()      { caddie_csv_set_alias_internal circle_y "caddie csv:set:circle_y <value>" "$@"; return $?; }
function caddie_csv_get_circle_y()      { caddie_csv_show_alias_internal circle_y; return $?; }
function caddie_csv_unset_circle_y()    { caddie_csv_unset_alias_internal circle_y; return $?; }

function caddie_csv_set_circle_r()      { caddie_csv_set_alias_internal circle_r "caddie csv:set:circle_r <value>" "$@"; return $?; }
function caddie_csv_get_circle_r()      { caddie_csv_show_alias_internal circle_r; return $?; }
function caddie_csv_unset_circle_r()    { caddie_csv_unset_alias_internal circle_r; return $?; }

function caddie_csv_set_circle_radii()  { caddie_csv_set_alias_internal circle_radii "caddie csv:set:circle_radii <r1,r2,...>" "$@"; return $?; }
function caddie_csv_get_circle_radii()  { caddie_csv_show_alias_internal circle_radii; return $?; }
function caddie_csv_unset_circle_radii(){ caddie_csv_unset_alias_internal circle_radii; return $?; }
