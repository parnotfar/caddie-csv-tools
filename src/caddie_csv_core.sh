#!/usr/bin/env bash

# Caddie CSV Tools - Core Module
# Handles initialization, globals, and environment management

function caddie_csv_init_globals() {
    declare -gA CADDIE_CSV_ENV_MAP=(
        [file]=CADDIE_CSV_FILE
        [x]=CADDIE_CSV_X
        [y]=CADDIE_CSV_Y
        [sep]=CADDIE_CSV_SEP
        [plot]=CADDIE_CSV_PLOT
        [title]=CADDIE_CSV_TITLE
        [limit]=CADDIE_CSV_LIMIT
        [save]=CADDIE_CSV_SAVE
        [success_filter]=CADDIE_CSV_SUCCESS_FILTER
        [scatter_filter]=CADDIE_CSV_SCATTER_FILTER
        [x_scale]=CADDIE_CSV_X_SCALE
        [y_scale]=CADDIE_CSV_Y_SCALE
        [x_range]=CADDIE_CSV_X_RANGE
        [y_range]=CADDIE_CSV_Y_RANGE
        [segment_column]=CADDIE_CSV_SEGMENT_COLUMN
        [segment_colors]=CADDIE_CSV_SEGMENT_COLORS
        [sql]=CADDIE_CSV_SQL
        [pager]=CADDIE_CSV_PAGER
        [circle]=CADDIE_CSV_CIRCLE
        [rings]=CADDIE_CSV_RINGS
        [circle_x]=CADDIE_CSV_CIRCLE_X
        [circle_y]=CADDIE_CSV_CIRCLE_Y
        [circle_r]=CADDIE_CSV_CIRCLE_R
        [circle_radii]=CADDIE_CSV_CIRCLE_RADII
    )

    declare -ga CADDIE_CSV_KEY_ORDER=(
        file x y sep plot title limit save pager success_filter scatter_filter x_scale y_scale x_range y_range segment_column segment_colors sql circle rings circle_x circle_y circle_r circle_radii
    )

    return 0
}

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
    local env_name="${CADDIE_CSV_ENV_MAP[$alias]}"
    if [ -z "$env_name" ]; then
        caddie cli:red "Internal error: unknown csv key '$alias'"
        return 1
    fi
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

# Initialize globals when this module is sourced
caddie_csv_init_globals
