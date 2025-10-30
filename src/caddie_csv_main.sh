#!/usr/bin/env bash

# Caddie CSV Tools - Main Module
# Entry point and command registration

function caddie_csv_help() {
    caddie cli:title "CSV / TSV Analytics"
    caddie cli:indent "csv:version              Show current version"
    caddie cli:indent "csv:init                 Bootstrap csvql virtual environment"
    caddie cli:indent "csv:query [file] ...     Run csvql with optional SQL/flags"
    caddie cli:indent "csv:query:summary        Run csvql and show summarized output"
    caddie cli:indent "csv:sql                  Open an interactive multi-line SQL prompt"
    caddie cli:indent "csv:plot [file] ...      Render plot using active plot type"
    caddie cli:indent "csv:scatter [file] ...   Render scatter plot regardless of defaults"
    caddie cli:indent "csv:line [file] ...      Render line plot when plot type is line"
    caddie cli:indent "csv:bar [file] ...       Render bar plot when plot type is bar"
    caddie cli:indent "csv:head [file] ...      Preview the first rows of a CSV file"
    caddie cli:indent "csv:tail [file] ...      Preview the last rows of a CSV file"
    caddie cli:indent "csv:unset:all            Clear all session defaults"
    caddie cli:blank
    caddie cli:title "Session Management"
    caddie cli:indent "csv:session:save [label]  Save current defaults as a reusable session"
    caddie cli:indent "csv:session:list         List saved sessions"
    caddie cli:indent "csv:session:view <id>    View session details"
    caddie cli:indent "csv:session:restore <id> Restore defaults from a saved session"
    caddie cli:indent "csv:session:delete <id>  Delete a saved session"
    caddie cli:indent "csv:session:delete:all   Remove every saved session"
    caddie cli:blank
    caddie cli:title "Session Defaults"
    caddie cli:indent "csv:list                 Show all current defaults"
    caddie cli:blank
    caddie cli:title "Set Commands"
    caddie cli:indent "csv:set:<key> <value>    Keys: file, x, y, line_series, sep, plot (scatter|line|bar), title, limit, save, pager, success_filter, scatter_filter, x_scale, y_scale, x_range, y_range, segment_column, segment_colors, sql, circle, rings, circle_x, circle_y, circle_r, ring_radii"
    caddie cli:title "Get Commands"
    caddie cli:indent "csv:get:<key>            Show current value"
    caddie cli:title "Unset Commands"
    caddie cli:indent "csv:unset:<key>          Clear value in this shell"
    caddie cli:blank
    caddie cli:thought "Defaults live only in the current shell session"
    return 0
}

function caddie_csv_sh_description() {
    caddie_csv_description "$@"
    return $?
}

function caddie_csv_sh_help() {
    caddie_csv_help "$@"
    return $?
}

function caddie_csv_commands() {
    printf '%s' "csv:version csv:init csv:query csv:query:summary csv:sql csv:plot csv:scatter csv:line csv:bar csv:head csv:tail csv:list csv:unset:all \
csv:set:file csv:get:file csv:unset:file csv:prompt \
csv:set:x csv:get:x csv:unset:x \
csv:set:y csv:get:y csv:unset:y \
csv:set:line_series csv:get:line_series csv:unset:line_series \
csv:set:sep csv:get:sep csv:unset:sep \
csv:set:plot csv:get:plot csv:unset:plot \
csv:set:title csv:get:title csv:unset:title \
csv:set:limit csv:get:limit csv:unset:limit \
csv:set:save csv:get:save csv:unset:save \
csv:set:pager csv:get:pager csv:unset:pager \
csv:set:success_filter csv:get:success_filter csv:unset:success_filter \
csv:set:scatter_filter csv:get:scatter_filter csv:unset:scatter_filter \
csv:set:x_scale csv:get:x_scale csv:unset:x_scale \
csv:set:y_scale csv:get:y_scale csv:unset:y_scale \
csv:set:x_range csv:get:x_range csv:unset:x_range \
csv:set:y_range csv:get:y_range csv:unset:y_range \
csv:set:segment_column csv:get:segment_column csv:unset:segment_column \
csv:set:segment_colors csv:get:segment_colors csv:unset:segment_colors \
csv:set:sql csv:get:sql csv:unset:sql \
csv:set:circle csv:get:circle csv:unset:circle \
csv:set:rings csv:get:rings csv:unset:rings \
csv:set:circle_x csv:get:circle_x csv:unset:circle_x \
csv:set:circle_y csv:get:circle_y csv:unset:circle_y \
csv:set:circle_r csv:get:circle_r csv:unset:circle_r \
csv:set:circle_radii csv:get:circle_radii csv:unset:circle_radii \
csv:session:save csv:session:list csv:session:view csv:session:restore csv:session:delete csv:session:delete:all"
    return 0
}

# Register with caddie if available
if declare -F caddie_prompt_register_segment >/dev/null 2>&1; then
    caddie_prompt_register_segment caddie_csv_prompt_segment
fi

if declare -F caddie_completion_register >/dev/null 2>&1; then
    caddie_completion_register "csv" "$(caddie_csv_commands)"
fi

# Export all functions for external use
export -f caddie_csv_description
export -f caddie_csv_help
export -f caddie_csv_sh_description
export -f caddie_csv_sh_help
export -f caddie_csv_list
export -f caddie_csv_unset_all
export -f caddie_csv_session_save
export -f caddie_csv_session_list
export -f caddie_csv_session_view
export -f caddie_csv_session_restore
export -f caddie_csv_session_delete
export -f caddie_csv_session_delete_all
export -f caddie_csv_init
export -f caddie_csv_query
export -f caddie_csv_query_summary
export -f caddie_csv_sql
export -f caddie_csv_plot
export -f caddie_csv_scatter
export -f caddie_csv_line
export -f caddie_csv_bar
export -f caddie_csv_head
export -f caddie_csv_tail
export -f caddie_csv_set_file
export -f caddie_csv_get_file
export -f caddie_csv_unset_file
export -f caddie_csv_set_x
export -f caddie_csv_get_x
export -f caddie_csv_unset_x
export -f caddie_csv_set_y
export -f caddie_csv_get_y
export -f caddie_csv_unset_y
export -f caddie_csv_set_line_series
export -f caddie_csv_get_line_series
export -f caddie_csv_unset_line_series
export -f caddie_csv_set_sep
export -f caddie_csv_get_sep
export -f caddie_csv_unset_sep
export -f caddie_csv_set_plot
export -f caddie_csv_get_plot
export -f caddie_csv_unset_plot
export -f caddie_csv_set_title
export -f caddie_csv_get_title
export -f caddie_csv_unset_title
export -f caddie_csv_set_limit
export -f caddie_csv_get_limit
export -f caddie_csv_unset_limit
export -f caddie_csv_set_save
export -f caddie_csv_get_save
export -f caddie_csv_unset_save
export -f caddie_csv_set_pager
export -f caddie_csv_get_pager
export -f caddie_csv_unset_pager
export -f caddie_csv_set_success_filter
export -f caddie_csv_get_success_filter
export -f caddie_csv_unset_success_filter
export -f caddie_csv_set_scatter_filter
export -f caddie_csv_get_scatter_filter
export -f caddie_csv_unset_scatter_filter
export -f caddie_csv_set_x_scale
export -f caddie_csv_get_x_scale
export -f caddie_csv_unset_x_scale
export -f caddie_csv_set_y_scale
export -f caddie_csv_get_y_scale
export -f caddie_csv_unset_y_scale
export -f caddie_csv_set_x_range
export -f caddie_csv_get_x_range
export -f caddie_csv_unset_x_range
export -f caddie_csv_set_y_range
export -f caddie_csv_get_y_range
export -f caddie_csv_unset_y_range
export -f caddie_csv_set_segment_column
export -f caddie_csv_get_segment_column
export -f caddie_csv_unset_segment_column
export -f caddie_csv_set_segment_colors
export -f caddie_csv_get_segment_colors
export -f caddie_csv_unset_segment_colors
export -f caddie_csv_set_sql
export -f caddie_csv_get_sql
export -f caddie_csv_unset_sql
export -f caddie_csv_set_circle
export -f caddie_csv_get_circle
export -f caddie_csv_unset_circle
export -f caddie_csv_set_rings
export -f caddie_csv_get_rings
export -f caddie_csv_unset_rings
export -f caddie_csv_set_circle_x
export -f caddie_csv_get_circle_x
export -f caddie_csv_unset_circle_x
export -f caddie_csv_set_circle_y
export -f caddie_csv_get_circle_y
export -f caddie_csv_unset_circle_y
export -f caddie_csv_set_circle_r
export -f caddie_csv_get_circle_r
export -f caddie_csv_unset_circle_r
export -f caddie_csv_set_circle_radii
export -f caddie_csv_get_circle_radii
export -f caddie_csv_unset_circle_radii
export -f caddie_csv_prompt
export -f caddie_csv_version
