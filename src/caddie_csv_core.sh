#!/usr/bin/env bash

# Caddie CSV Tools - Core Module
# Handles initialization, globals, and environment management

# Ordered list of csv:* setting aliases that drive set/list/session helpers.
CADDIE_CSV_KEY_ORDER=(
    file x y line_series sep plot title limit save pager success_filter scatter_filter x_scale y_scale x_range y_range segment_column segment_colors sql circle rings circle_x circle_y circle_r circle_radii
)

function caddie_csv_prompt_segment() {
    local csv_file="${CADDIE_CSV_FILE:-}"
    if [ -z "$csv_file" ]; then
        return 0
    fi

    local display="$csv_file"
    if [ -n "$HOME" ] && [[ "$display" == "$HOME"* ]]; then
        display="~${display#$HOME}"
    fi

    local prefix="${PS_CYAN:-}"
    local suffix="${PS_RESET:-}"

    printf '[%scsv:%s%s]' "$prefix" "$display" "$suffix"
    return 0
}

function caddie_csv_env_name() {
    local alias="$1"
    local env_name=""
    case "$alias" in
        file)            env_name="CADDIE_CSV_FILE" ;;
        x)               env_name="CADDIE_CSV_X" ;;
        y)               env_name="CADDIE_CSV_Y" ;;
        line_series)     env_name="CADDIE_CSV_LINE_SERIES" ;;
        sep)             env_name="CADDIE_CSV_SEP" ;;
        plot)            env_name="CADDIE_CSV_PLOT" ;;
        title)           env_name="CADDIE_CSV_TITLE" ;;
        limit)           env_name="CADDIE_CSV_LIMIT" ;;
        save)            env_name="CADDIE_CSV_SAVE" ;;
        pager)           env_name="CADDIE_CSV_PAGER" ;;
        success_filter)  env_name="CADDIE_CSV_SUCCESS_FILTER" ;;
        scatter_filter)  env_name="CADDIE_CSV_SCATTER_FILTER" ;;
        x_scale)         env_name="CADDIE_CSV_X_SCALE" ;;
        y_scale)         env_name="CADDIE_CSV_Y_SCALE" ;;
        x_range)         env_name="CADDIE_CSV_X_RANGE" ;;
        y_range)         env_name="CADDIE_CSV_Y_RANGE" ;;
        segment_column)  env_name="CADDIE_CSV_SEGMENT_COLUMN" ;;
        segment_colors)  env_name="CADDIE_CSV_SEGMENT_COLORS" ;;
        sql)             env_name="CADDIE_CSV_SQL" ;;
        circle)          env_name="CADDIE_CSV_CIRCLE" ;;
        rings)           env_name="CADDIE_CSV_RINGS" ;;
        circle_x)        env_name="CADDIE_CSV_CIRCLE_X" ;;
        circle_y)        env_name="CADDIE_CSV_CIRCLE_Y" ;;
        circle_r)        env_name="CADDIE_CSV_CIRCLE_R" ;;
        circle_radii)    env_name="CADDIE_CSV_CIRCLE_RADII" ;;
        *)
            caddie cli:red "Internal error: unknown csv key '$alias'"
            return 1
            ;;
    esac

    printf '%s' "$env_name"
    return 0
}

function caddie_csv_version() { 
    caddie_csv_tools_version_show
    return $?
}

function caddie_csv_description() {
    echo 'CSV SQL + plotting helpers using session defaults'
    return 0
}

# Legacy no-op retained for backwards compatibility with older installers
caddie_csv_init_globals() { return 0; }
