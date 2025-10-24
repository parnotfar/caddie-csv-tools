#!/usr/bin/env bash

# Caddie.sh - CSV/TSV analytics helpers
# Provides wrappers around csvql.py for querying and plotting data

source "$HOME/.caddie_modules/.caddie_cli"
source "$HOME/.caddie_modules/.caddie_csv_version"

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

caddie_csv_init_globals

function caddie_csv_session_dir_internal() {
    local dir="${CADDIE_CSV_SESSION_DIR:-$HOME/.caddie_csv/sessions}"
    printf '%s' "$dir"
    return 0
}

function caddie_csv_session_ensure_dir_internal() {
    local dir
    dir=$(caddie_csv_session_dir_internal)
    mkdir -p "$dir"
    return 0
}

function caddie_csv_session_resolve_file_internal() {
    local id="$1"
    if [ -z "$id" ]; then
        caddie cli:red "Session id required"
        return 1
    fi

    if [[ "$id" =~ ^[0-9]+$ ]]; then
        printf -v id '%03d' "$id"
    fi

    local dir
    dir=$(caddie_csv_session_dir_internal)
    if [ ! -d "$dir" ]; then
        caddie cli:red "No saved sessions"
        return 1
    fi

    local path
    path=$(find "$dir" -maxdepth 1 -type f -name "${id}_*.session" -print | sort | head -n 1)
    if [ -z "$path" ]; then
        caddie cli:red "Session not found: $id"
        return 1
    fi
    printf '%s' "$path"
    return 0
}

function caddie_csv_session_next_id_internal() {
    local dir
    dir=$(caddie_csv_session_dir_internal)
    local last
    last=$(find "$dir" -maxdepth 1 -type f -name '[0-9][0-9][0-9]_*.session' -print | sed 's#.*/##' | cut -d '_' -f 1 | sort -n | tail -n 1)
    local next=1
    if [ -n "$last" ]; then
        next=$((10#$last + 1))
    fi
    printf '%03d' "$next"
    return 0
}

function caddie_csv_session_dump_internal() {
    local file="$1"
    local alias env value
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            \#*)
                continue
                ;;
            *=*)
                alias="${line%%=*}"
                value="${line#*=}"
                if ! env=$(caddie_csv_env_name "$alias" 2>/dev/null); then
                    continue
                fi
                if [ -n "$value" ]; then
                    export "$env=$value"
                else
                    unset "$env"
                fi
                ;;
        esac
    done <"$file"
    return 0
}

function caddie_csv_session_print_values_internal() {
    local file="$1"
    local alias env value
    caddie cli:title "Session values"
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            \#*)
                continue
                ;;
            *=*)
                alias="${line%%=*}"
                value="${line#*=}"
                printf '  %-17s %s\n' "$alias" "${value:-}" 
                ;;
        esac
    done <"$file"
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

function caddie_csv_session_save() {
    local label="$*"
    caddie_csv_session_ensure_dir_internal
    local dir
    dir=$(caddie_csv_session_dir_internal)
    local id
    id=$(caddie_csv_session_next_id_internal)
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local filename="${id}_${timestamp}.session"
    local tmp_file="${dir}/${filename}.tmp"
    {
        printf '# label: %s\n' "$label"
        printf '# saved: %s\n' "$timestamp"
        local alias env value
        for alias in "${CADDIE_CSV_KEY_ORDER[@]}"; do
            env="${CADDIE_CSV_ENV_MAP[$alias]}"
            value="${!env-}"
            printf '%s=%s\n' "$alias" "$value"
        done
    } >"$tmp_file"
    mv "$tmp_file" "${dir}/${filename}"
    caddie cli:check "Saved session $id"
    if [ -n "$label" ]; then
        caddie cli:thought "Label: $label"
    fi
    return 0
}

function caddie_csv_session_list() {
    local dir
    dir=$(caddie_csv_session_dir_internal)
    if [ ! -d "$dir" ]; then
        caddie cli:warning "No saved sessions"
        return 0
    fi

    local printed=0
    while IFS= read -r file; do
        if [ $printed -eq 0 ]; then
            caddie cli:title "Saved CSV sessions"
            printf '  %-5s %-20s %s\n' "ID" "Label" "Saved"
            printed=1
        fi
        local base="${file##*/}"
        local id="${base%%_*}"
        local label
        label=$(grep -m1 '^# label:' "$file" | sed 's/^# label: //')
        local saved
        saved=$(grep -m1 '^# saved:' "$file" | sed 's/^# saved: //')
        printf '  %-5s %-20s %s\n' "$id" "${label:-}" "${saved:-}"
    done < <(find "$dir" -maxdepth 1 -type f -name '[0-9][0-9][0-9]_*.session' -print | sort)

    if [ $printed -eq 0 ]; then
        caddie cli:warning "No saved sessions"
    fi
    return 0
}

function caddie_csv_session_view() {
    local id="$1"
    if [ -z "$id" ]; then
        caddie cli:red "Usage: caddie csv:session:view <id>"
        return 1
    fi

    local file
    file=$(caddie_csv_session_resolve_file_internal "$id") || return 1
    local base="${file##*/}"
    local session_id="${base%%_*}"
    local label
    label=$(grep -m1 '^# label:' "$file" | sed 's/^# label: //')
    local saved
    saved=$(grep -m1 '^# saved:' "$file" | sed 's/^# saved: //')
    caddie cli:title "Session $session_id"
    caddie cli:indent "Label: ${label:-}"
    caddie cli:indent "Saved: ${saved:-}"
    caddie_csv_session_print_values_internal "$file"
    return 0
}

function caddie_csv_session_restore() {
    local id="$1"
    if [ -z "$id" ]; then
        caddie cli:red "Usage: caddie csv:session:restore <id>"
        return 1
    fi

    local file
    file=$(caddie_csv_session_resolve_file_internal "$id") || return 1
    caddie_csv_unset_all >/dev/null 2>&1
    caddie_csv_session_dump_internal "$file"
    caddie cli:check "Restored session ${id}"
    return 0
}

function caddie_csv_session_delete() {
    local id="$1"
    if [ -z "$id" ]; then
        caddie cli:red "Usage: caddie csv:session:delete <id>"
        return 1
    fi

    local file
    file=$(caddie_csv_session_resolve_file_internal "$id") || return 1
    rm "$file"
    caddie cli:check "Deleted session ${id}"
    return 0
}

function caddie_csv_session_delete_all() {
    local dir
    dir=$(caddie_csv_session_dir_internal)
    if [ ! -d "$dir" ]; then
        caddie cli:warning "No saved sessions"
        return 0
    fi
    rm -rf "$dir"
    caddie cli:check "Removed all saved sessions"
    return 0
}

function caddie_csv_list() {
    caddie cli:title "CSV session defaults"
    local alias
    local env
    local value
    for alias in "${CADDIE_CSV_KEY_ORDER[@]}"; do
        env="${CADDIE_CSV_ENV_MAP[$alias]}"
        value="${!env:-}"
        if [ -n "$value" ]; then
            printf '  %-17s %s\n' "$alias" "$value"
        else
            printf '  %-17s (unset)\n' "$alias"
        fi
    done
    return 0
}

function caddie_csv_version() { caddie_csv_tools_version_show; return $?; }

function caddie_csv_set_file()          { caddie_csv_set_alias_internal file "caddie csv:set:file <path>" "$@"; return $?; }
function caddie_csv_get_file()          { caddie_csv_show_alias_internal file unformatted; return $?; }
function caddie_csv_unset_file()        { caddie_csv_unset_alias_internal file; return $?; }

function caddie_csv_set_x()             { caddie_csv_set_alias_internal x "caddie csv:set:x <column>" "$@"; return $?; }
function caddie_csv_get_x()             { caddie_csv_show_alias_internal x; return $?; }
function caddie_csv_unset_x()           { caddie_csv_unset_alias_internal x; return $?; }

function caddie_csv_set_y()             { caddie_csv_set_alias_internal y "caddie csv:set:y <column>" "$@"; return $?; }
function caddie_csv_get_y()             { caddie_csv_show_alias_internal y; return $?; }
function caddie_csv_unset_y()           { caddie_csv_unset_alias_internal y; return $?; }

function caddie_csv_set_sep()           { caddie_csv_set_alias_internal sep "caddie csv:set:sep <separator>" "$@"; return $?; }
function caddie_csv_get_sep()           { caddie_csv_show_alias_internal sep; return $?; }
function caddie_csv_unset_sep()         { caddie_csv_unset_alias_internal sep; return $?; }

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

function caddie_csv_set_title()         { caddie_csv_set_alias_internal title "caddie csv:set:title <text>" "$@"; return $?; }
function caddie_csv_get_title()         { caddie_csv_show_alias_internal title; return $?; }
function caddie_csv_unset_title()       { caddie_csv_unset_alias_internal title; return $?; }

function caddie_csv_set_limit()         { caddie_csv_set_alias_internal limit "caddie csv:set:limit <rows>" "$@"; return $?; }
function caddie_csv_get_limit()         { caddie_csv_show_alias_internal limit; return $?; }
function caddie_csv_unset_limit()       { caddie_csv_unset_alias_internal limit; return $?; }

function caddie_csv_set_save()          { caddie_csv_set_alias_internal save "caddie csv:set:save <path>" "$@"; return $?; }
function caddie_csv_get_save()          { caddie_csv_show_alias_internal save; return $?; }
function caddie_csv_unset_save()        { caddie_csv_unset_alias_internal save; return $?; }

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

function caddie_csv_set_success_filter(){ caddie_csv_set_alias_internal success_filter "caddie csv:set:success_filter <predicate>" "$@"; return $?; }
function caddie_csv_get_success_filter(){ caddie_csv_show_alias_internal success_filter; return $?; }
function caddie_csv_unset_success_filter(){ caddie_csv_unset_alias_internal success_filter; return $?; }

function caddie_csv_set_scatter_filter(){ caddie_csv_set_alias_internal scatter_filter "caddie csv:set:scatter_filter <predicate>" "$@"; return $?; }
function caddie_csv_get_scatter_filter(){ caddie_csv_show_alias_internal scatter_filter; return $?; }
function caddie_csv_unset_scatter_filter(){ caddie_csv_unset_alias_internal scatter_filter; return $?; }

function caddie_csv_set_x_scale(){ caddie_csv_set_alias_internal x_scale "caddie csv:set:x_scale <scale>" "$@"; return $?; }
function caddie_csv_get_x_scale(){ caddie_csv_show_alias_internal x_scale; return $?; }
function caddie_csv_unset_x_scale(){ caddie_csv_unset_alias_internal x_scale; return $?; }

function caddie_csv_set_y_scale(){ caddie_csv_set_alias_internal y_scale "caddie csv:set:y_scale <scale>" "$@"; return $?; }
function caddie_csv_get_y_scale(){ caddie_csv_show_alias_internal y_scale; return $?; }
function caddie_csv_unset_y_scale(){ caddie_csv_unset_alias_internal y_scale; return $?; }

function caddie_csv_set_x_range(){ caddie_csv_set_alias_internal x_range "caddie csv:set:x_range <start,end[,ticks...]>" "$@"; return $?; }
function caddie_csv_get_x_range(){ caddie_csv_show_alias_internal x_range; return $?; }
function caddie_csv_unset_x_range(){ caddie_csv_unset_alias_internal x_range; return $?; }

function caddie_csv_set_y_range(){ caddie_csv_set_alias_internal y_range "caddie csv:set:y_range <start,end[,ticks...]>" "$@"; return $?; }
function caddie_csv_get_y_range(){ caddie_csv_show_alias_internal y_range; return $?; }
function caddie_csv_unset_y_range(){ caddie_csv_unset_alias_internal y_range; return $?; }

function caddie_csv_set_segment_column(){ caddie_csv_set_alias_internal segment_column "caddie csv:set:segment_column <column>" "$@"; return $?; }
function caddie_csv_get_segment_column(){ caddie_csv_show_alias_internal segment_column; return $?; }
function caddie_csv_unset_segment_column(){ caddie_csv_unset_alias_internal segment_column; return $?; }

function caddie_csv_set_segment_colors(){ caddie_csv_set_alias_internal segment_colors "caddie csv:set:segment_colors <color1,color2>" "$@"; return $?; }
function caddie_csv_get_segment_colors(){ caddie_csv_show_alias_internal segment_colors; return $?; }
function caddie_csv_unset_segment_colors(){ caddie_csv_unset_alias_internal segment_colors; return $?; }

function caddie_csv_set_sql()           { caddie_csv_set_alias_internal sql "caddie csv:set:sql <query>" "$@"; return $?; }
function caddie_csv_get_sql()           { caddie_csv_show_alias_internal sql; return $?; }
function caddie_csv_unset_sql()         { caddie_csv_unset_alias_internal sql; return $?; }

function caddie_csv_sql_preview_internal() {
    local sql="$1"
    local preview
    preview=$(printf '%s' "$sql" | tr '\n' ' ' | tr -s ' ')
    if [ ${#preview} -gt 96 ]; then
        preview="${preview:0:93}..."
    fi
    printf '%s' "$preview"
    return 0
}

function caddie_csv_sql_sanitize_line_internal() {
    local input="$1"
    input="${input//$'\e[200~'/}"
    input="${input//$'\e[201~'/}"
    input="${input//$'\r'/}"
    printf '%s' "$input"
    return 0
}

function caddie_csv_sql_handle_multiline_paste() {
    local input="$1"
    local buffer="$2"
    
    # If input contains newlines, treat it as a multiline paste
    if [[ "$input" =~ $'\n' ]]; then
        # Split by newlines and process each line
        local IFS=$'\n'
        local lines=($input)
        local temp_buffer="$buffer"
        
        for line in "${lines[@]}"; do
            line=$(caddie_csv_sql_sanitize_line_internal "$line")
            if [ -n "$line" ]; then
                temp_buffer+="${temp_buffer:+$'\n'}$line"
            fi
        done
        
        printf '%s' "$temp_buffer"
        return 0
    fi
    
    # Not a multiline paste, return original buffer + input
    printf '%s' "${buffer:+$buffer$'\n'}$input"
    return 0
}

function caddie_csv_sql_apply_internal() {
    local sql="$1"
    local mode="${2:-query}"
    local preview
    preview=$(caddie_csv_sql_preview_internal "$sql")

    if [ -z "$preview" ]; then
        caddie cli:warning "SQL statement is empty; nothing to run"
        return 1
    fi

    printf -v CADDIE_CSV_SQL '%s' "$sql"
    export CADDIE_CSV_SQL

    # Add to SQL command history
    caddie_csv_sql_add_to_history "$sql"

    caddie cli:check "SQL ready (${mode}) → $preview"

    if [ "$mode" = "summary" ]; then
        caddie_csv_query_summary
    else
        caddie_csv_query
    fi
    return $?
}

function caddie_csv_sql_help_internal() {
    caddie cli:title "CSV SQL prompt commands"
    caddie cli:indent "\\q        Exit the SQL prompt"
    caddie cli:indent "\\g        Execute the current buffer (query)"
    caddie cli:indent "\\summary  Execute the current buffer as a summary query"
    caddie cli:indent "\\show     Display active CSV defaults"
    caddie cli:indent "\\last     Show the last stored SQL statement"
    caddie cli:indent "\\history  Show command history (\\history) or load specific command (\\history N)"
    caddie cli:indent "\\hist     Alias for \\history"
    caddie cli:indent "\\up       Go to previous command in history"
    caddie cli:indent "\\down     Go to next command in history"
    caddie cli:indent "\\clear    Discard the in-flight SQL buffer"
    caddie cli:indent "\\paste    Enter multiline paste mode"
    caddie cli:indent "\\edit     Open current buffer in editor (\\e for short)"
    caddie cli:indent "\\help     Show this help message"
    caddie cli:blank
    caddie cli:thought "Terminate SQL with ';' to run automatically."
    caddie cli:thought "Use \\paste for multiline queries, or type \\g after pasting."
    caddie cli:thought "Use \\edit to open current buffer in your editor (\$EDITOR)."
    caddie cli:thought "Use \\up/\\down for command history navigation."
    return 0
}

function caddie_csv_sql_edit_mode() {
    local current_buffer="$1"
    
    # Check if EDITOR is set
    if [ -z "${EDITOR:-}" ]; then
        caddie cli:warning "No editor configured. Set \$EDITOR environment variable."
        caddie cli:thought "Example: export EDITOR=vim"
        return 1
    fi
    
    # Create a temporary file for editing
    local temp_file
    temp_file=$(mktemp /tmp/caddie_sql_edit.XXXXXX.sql) || {
        caddie cli:warning "Failed to create temporary file"
        return 1
    }
    
    # Write current buffer to temp file
    printf '%s' "$current_buffer" > "$temp_file"
    
    caddie cli:title "Opening SQL in editor" >&2
    caddie cli:indent "Editor: $EDITOR" >&2
    caddie cli:indent "File: $temp_file" >&2
    caddie cli:blank >&2
    
    # Open editor
    if "$EDITOR" "$temp_file"; then
        # Editor exited successfully, read the content
        if [ -f "$temp_file" ]; then
            CADDIE_CSV_SQL_EDITED_CONTENT=$(cat "$temp_file")
            rm -f "$temp_file"
            return 0
        else
            caddie cli:warning "Temporary file was deleted during editing"
            rm -f "$temp_file"
            return 1
        fi
    else
        caddie cli:warning "Editor exited with error"
        rm -f "$temp_file"
        return 1
    fi
}

# Global variable to hold edited content
CADDIE_CSV_SQL_EDITED_CONTENT=""

function caddie_csv_sql_paste_mode() {
    caddie cli:title "Multiline Paste Mode" >&2
    caddie cli:indent "Paste your multiline SQL query below." >&2
    caddie cli:indent "Press Ctrl+D (EOF) when finished, or type 'END' on a new line." >&2
    caddie cli:blank >&2
    
    local paste_buffer=""
    local line=""
    
    # Read until EOF or END command
    while IFS= read -r line; do
        if [ "$line" = "END" ]; then
            break
        fi
        paste_buffer+="${paste_buffer:+$'\n'}$line"
    done
    
    if [ -n "$paste_buffer" ]; then
        # Return the pasted content to be added to the main buffer
        printf '%s' "$paste_buffer"
    else
        caddie cli:warning "No content pasted" >&2
    fi
    
    return 0
}

# SQL Command History Management
CADDIE_CSV_SQL_HISTORY=()
CADDIE_CSV_SQL_HISTORY_INDEX=-1

function caddie_csv_sql_add_to_history() {
    local query="$1"
    if [ -n "$query" ]; then
        # Add to history array
        CADDIE_CSV_SQL_HISTORY+=("$query")
        # Keep only last 100 entries
        if [ ${#CADDIE_CSV_SQL_HISTORY[@]} -gt 100 ]; then
            CADDIE_CSV_SQL_HISTORY=("${CADDIE_CSV_SQL_HISTORY[@]:1}")
        fi
        # Reset index to end (last valid index)
        CADDIE_CSV_SQL_HISTORY_INDEX=$((${#CADDIE_CSV_SQL_HISTORY[@]} - 1))
    fi
}

# Global variable to hold the current history line
CADDIE_CSV_SQL_CURRENT_HISTORY_LINE=""

function caddie_csv_sql_get_history_up() {
    if [ ${#CADDIE_CSV_SQL_HISTORY[@]} -eq 0 ]; then
        CADDIE_CSV_SQL_CURRENT_HISTORY_LINE=""
        return 1
    fi
    
    if [ $CADDIE_CSV_SQL_HISTORY_INDEX -gt 0 ]; then
        CADDIE_CSV_SQL_HISTORY_INDEX=$((CADDIE_CSV_SQL_HISTORY_INDEX - 1))
        CADDIE_CSV_SQL_CURRENT_HISTORY_LINE="${CADDIE_CSV_SQL_HISTORY[$CADDIE_CSV_SQL_HISTORY_INDEX]}"
        return 0
    fi
    CADDIE_CSV_SQL_CURRENT_HISTORY_LINE=""
    return 1
}

function caddie_csv_sql_get_history_down() {
    if [ ${#CADDIE_CSV_SQL_HISTORY[@]} -eq 0 ]; then
        CADDIE_CSV_SQL_CURRENT_HISTORY_LINE=""
        return 1
    fi
    
    if [ $CADDIE_CSV_SQL_HISTORY_INDEX -lt $((${#CADDIE_CSV_SQL_HISTORY[@]} - 1)) ]; then
        CADDIE_CSV_SQL_HISTORY_INDEX=$((CADDIE_CSV_SQL_HISTORY_INDEX + 1))
        CADDIE_CSV_SQL_CURRENT_HISTORY_LINE="${CADDIE_CSV_SQL_HISTORY[$CADDIE_CSV_SQL_HISTORY_INDEX]}"
        return 0
    fi
    CADDIE_CSV_SQL_CURRENT_HISTORY_LINE=""
    return 1
}

function caddie_csv_sql_reset_history_index() {
    CADDIE_CSV_SQL_HISTORY_INDEX=$((${#CADDIE_CSV_SQL_HISTORY[@]} - 1))
}

function caddie_csv_sql() {
    local version="${CADDIE_CSV_TOOLS_VERSION:-}"
    local prompt_primary="caddie[csv sql]-${version}> "
    local prompt_continuation="...> "
    local buffer=""
    local line=""
    local read_flags="-r"
    local previous_trap
    
    # Disable readline to fix multiline paste issues
    # This is the core fix - readline interferes with multiline paste

    caddie cli:title "Interactive CSV SQL prompt"
    caddie cli:indent "Enter SQL across multiple lines and finish with ';' or \\g."
    caddie cli:indent "Type \\help for available commands."
    caddie cli:indent "For clean multiline paste: use \\paste command."

    # Initialize history index
    caddie_csv_sql_reset_history_index

    previous_trap=$(trap -p INT)
    trap 'buffer=""; printf "\n"; caddie cli:warning "Cancelled SQL buffer"' INT

    while true; do
        if [ -z "$buffer" ]; then
            if ! read $read_flags -p "$prompt_primary" line; then
                printf '\n'
                break
            fi
        else
            if ! read $read_flags -p "$prompt_continuation" line; then
                printf '\n'
                break
            fi
        fi

        line=$(caddie_csv_sql_sanitize_line_internal "$line")

        # Check if this might be a multiline paste (contains newlines)
        if [[ "$line" =~ $'\n' ]]; then
            # This contains newlines, might be a multiline paste
            buffer=$(caddie_csv_sql_handle_multiline_paste "$line" "$buffer")
            
            # Check if the buffer now ends with semicolon
            if [[ "$buffer" =~ \;[[:space:]]*$ ]]; then
                caddie_csv_sql_apply_internal "$buffer" query
                buffer=""
            fi
            continue
        fi

        if [[ "$line" =~ ^\\ ]]; then
            case "$line" in
                \\q|\\quit)
                    buffer=""
                    break
                    ;;
                \\help|\\h)
                    caddie_csv_sql_help_internal
                    continue
                    ;;
                \\clear|\\reset)
                    buffer=""
                    caddie cli:thought "Cleared SQL buffer"
                    continue
                    ;;
                \\paste)
                    local pasted_content
                    pasted_content=$(caddie_csv_sql_paste_mode)
                    if [ -n "$pasted_content" ]; then
                        buffer+="${buffer:+$'\n'}$pasted_content"
                        local preview
                        preview=$(caddie_csv_sql_preview_internal "$buffer")
                        caddie cli:check "Added to buffer: $preview"

                        # Check if it ends with semicolon and execute automatically
                        if [[ "$buffer" =~ \;[[:space:]]*$ ]]; then
                            caddie_csv_sql_apply_internal "$buffer" query
                            buffer=""
                        fi
                    fi
                    continue
                    ;;
                \\edit|\\e)
                    caddie_csv_sql_edit_mode "$buffer"
                    if [ $? -eq 0 ]; then
                        # Editor was successful, update buffer with edited content
                        buffer="$CADDIE_CSV_SQL_EDITED_CONTENT"
                        local preview
                        preview=$(caddie_csv_sql_preview_internal "$buffer")
                        caddie cli:check "Buffer updated from editor: $preview"
                        
                        # Check if it ends with semicolon and execute automatically
                        if [[ "$buffer" =~ \;[[:space:]]*$ ]]; then
                            caddie_csv_sql_apply_internal "$buffer" query
                            buffer=""
                        fi
                    else
                        caddie cli:warning "Editor was cancelled or failed"
                    fi
                    continue
                    ;;
                \\show)
                    caddie_csv_list
                    continue
                    ;;
                \\last)
                    if [ -n "${CADDIE_CSV_SQL:-}" ]; then
                        buffer="${CADDIE_CSV_SQL}"
                        local preview
                        preview=$(caddie_csv_sql_preview_internal "$buffer")
                        caddie cli:check "Loaded last SQL: $preview"
                    else
                        caddie cli:warning "No SQL statement available"
                    fi
                    continue
                    ;;
                \\history*|\\hist)
                    # Check if there's a number argument
                    if [[ "$line" =~ ^\\(history|hist)[[:space:]]+([0-9]+)$ ]]; then
                        local hist_num="${BASH_REMATCH[2]}"
                        local hist_index=$((hist_num - 1))
                        
                        if [ $hist_index -ge 0 ] && [ $hist_index -lt ${#CADDIE_CSV_SQL_HISTORY[@]} ]; then
                            buffer="${CADDIE_CSV_SQL_HISTORY[$hist_index]}"
                            local preview
                            preview=$(caddie_csv_sql_preview_internal "$buffer")
                            caddie cli:check "Loaded history #$hist_num: $preview"
                        else
                            caddie cli:warning "History index $hist_num not found (available: 1-${#CADDIE_CSV_SQL_HISTORY[@]})"
                        fi
                    else
                        # No number argument - show history list
                        if [ ${#CADDIE_CSV_SQL_HISTORY[@]} -eq 0 ]; then
                            caddie cli:warning "No SQL history available"
                        else
                            caddie cli:title "SQL Command History"
                            local i
                            for i in "${!CADDIE_CSV_SQL_HISTORY[@]}"; do
                                local preview
                                preview=$(caddie_csv_sql_preview_internal "${CADDIE_CSV_SQL_HISTORY[$i]}")
                                caddie cli:indent "$((i+1)). $preview"
                            done
                        fi
                    fi
                    continue
                    ;;
                \\up)
                    if caddie_csv_sql_get_history_up; then
                        buffer="$CADDIE_CSV_SQL_CURRENT_HISTORY_LINE"
                        local preview
                        preview=$(caddie_csv_sql_preview_internal "$buffer")
                        caddie cli:check "Loaded from history: $preview"
                    else
                        caddie cli:warning "No previous command in history"
                    fi
                    continue
                    ;;
                \\down)
                    if caddie_csv_sql_get_history_down; then
                        buffer="$CADDIE_CSV_SQL_CURRENT_HISTORY_LINE"
                        local preview
                        preview=$(caddie_csv_sql_preview_internal "$buffer")
                        caddie cli:check "Loaded from history: $preview"
                    else
                        caddie cli:warning "No next command in history"
                    fi
                    continue
                    ;;
                \\g|\\go)
                    if [ -n "$buffer" ]; then
                        caddie_csv_sql_apply_internal "$buffer" query
                        buffer=""
                    else
                        if [ -z "${CADDIE_CSV_SQL:-}" ]; then
                            caddie cli:warning "No SQL buffer or default query to run"
                        else
                            caddie_csv_sql_apply_internal "$CADDIE_CSV_SQL" query
                        fi
                    fi
                    continue
                    ;;
                \\summary)
                    if [ -n "$buffer" ]; then
                        caddie_csv_sql_apply_internal "$buffer" summary
                        buffer=""
                    else
                        if [ -z "${CADDIE_CSV_SQL:-}" ]; then
                            caddie cli:warning "No SQL buffer or default query to summarize"
                        else
                            caddie_csv_sql_apply_internal "$CADDIE_CSV_SQL" summary
                        fi
                    fi
                    continue
                    ;;
                *)
                    caddie cli:warning "Unknown command: $line"
                    caddie cli:thought "Type \\help for available commands"
                    continue
                    ;;
            esac
        fi

        buffer+="${buffer:+$'\n'}$line"

        if [[ "$buffer" =~ \;[[:space:]]*$ ]]; then
            caddie_csv_sql_apply_internal "$buffer" query
            buffer=""
        fi
    done

    if [ -n "$previous_trap" ]; then
        eval "$previous_trap"
    else
        trap - INT
    fi

    caddie cli:thought "Exited CSV SQL prompt"
    return 0
}

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
    local x_value="${CADDIE_CSV_X:-}"
    local y_value="${CADDIE_CSV_Y:-}"

    if [ -z "$x_value" ] || [ -z "$y_value" ]; then
        caddie cli:red "Set csv axes before plotting"
        caddie cli:thought "Example: caddie csv:set:x aim_offset_x"
        caddie cli:thought "         caddie csv:set:y aim_offset_y"
        return 1
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

    caddie_csv_require_axes_internal || return 1

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

function caddie_csv_description() {
    echo 'CSV SQL + plotting helpers using session defaults'
    return 0
}


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
    caddie cli:indent "csv:set:<key> <value>    Keys: file, x, y, sep, plot (scatter|line|bar), title, limit, save, pager, success_filter, scatter_filter, x_scale, y_scale, x_range, y_range, segment_column, segment_colors, sql, circle, rings, circle_x, circle_y, circle_r, ring_radii"
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

function caddie_csv_commands() {
    printf '%s' "csv:version csv:init csv:query csv:query:summary csv:sql csv:plot csv:scatter csv:line csv:bar csv:head csv:tail csv:list csv:unset:all \
csv:set:file csv:get:file csv:unset:file csv:prompt \
csv:set:x csv:get:x csv:unset:x \
csv:set:y csv:get:y csv:unset:y \
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

# csv:prompt — turn a natural-language prompt into caddie csv:* commands
# Usage:
#   caddie csv:prompt "plot target/30ft_positions.csv scatter x=x_position y=y_position where success=false and handicap<=10 title: 30ft Misses save to out/30ft.png save session as 30ft_misses"
#   caddie csv:prompt --dry-run "..."
function caddie_csv_prompt() {
  local DRY=0
  
  if [[ "$1" == "--dry-run" ]]; then DRY=1; shift; fi

  local PROMPT_RAW="$*"

  if [[ -z "$PROMPT_RAW" ]]; then
    caddie cli:red "Usage: caddie csv:prompt [--dry-run] \"<prompt>\""
    return 2
  fi

  # --- Sanitize multi-line + backslash continuations ---
  # 1) turn newlines into spaces
  local PROMPT="${PROMPT_RAW//$'\n'/ }"

  # 2) collapse sequences like "  \  " into a single space
  PROMPT="$(sed -E 's/[[:space:]]*\\[[:space:]]*/ /g; s/[[:space:]]+/ /g' <<<"$PROMPT")"

  shopt -s nocasematch

  _m() { [[ "$PROMPT" =~ $1 ]] && printf '%s' "${BASH_REMATCH[1]}"; }

  local path
  local plot
  local query
  local x
  local y
  local title
  local save
  local where
  local sql
  local rings
  local sess
  local cx
  local cy
  local cr
  local segment_column
  local segment_palette
  local x_scale_value
  local y_scale_value
  local x_range_spec
  local y_range_spec

  # ERE-safe patterns (no (?:...))
  path="$(_m '([[:alnum:]_./-]+\.csv)')"

  # word-boundary alternative: capture group 2
  if [[ "$PROMPT" =~ (^|[[:space:][:punct:]])(scatter|line|bar)($|[[:space:][:punct:]]) ]]; then
    plot="${BASH_REMATCH[2]}"
  fi

  if [[ "$PROMPT" =~ (^|[[:space:][:punct:]])(query|summary)($|[[:space:][:punct:]]) ]]; then
    query="${BASH_REMATCH[2]}"
  fi

  x="$(_m '[xX][[:space:]]*[:=][[:space:]]*([A-Za-z_][A-Za-z0-9_]*)')"
  y="$(_m '[yY][[:space:]]*[:=][[:space:]]*([A-Za-z_][A-Za-z0-9_]*)')"

  # ERE-safe save pattern -> \.(png|jpg|jpeg|svg|html)
  save="$(_m 'save[[:space:]]*to[[:space:]]*([[:alnum:]_./-]+\.(png|jpg|jpeg|svg|html))')"

  # sql: grab to end of line
  sql="$(_m 'sql[[:space:]]*:[[:space:]]*(.*)')"

  rings="$(_m 'rings[[:space:]]*[:=]?[[:space:]]*([0-9.,[:space:]-]+)')"
  sess="$(_m 'save[[:space:]]+session[[:space:]]+as[[:space:]]+([[:alnum:]_.-]+)')"

  if [[ "$PROMPT" =~ segment(_column)?[[:space:]]*[:=]?[[:space:]]*([A-Za-z_][A-Za-z0-9_]*) ]]; then
    segment_column="${BASH_REMATCH[2]}"
  fi

  if [[ "$PROMPT" =~ segment_colors[[:space:]]*[:=]?[[:space:]]*([#:[:alnum:],._[:space:]-]+) ]]; then
    segment_palette="${BASH_REMATCH[1]}"
    segment_palette="$(tr -d ' ' <<<"$segment_palette")"
  fi

  if [[ "$PROMPT" =~ x_scale[[:space:]]*[:=]?[[:space:]]*([[:alnum:]_.-]+) ]]; then
    x_scale_value="${BASH_REMATCH[1]}"
  fi

  if [[ "$PROMPT" =~ y_scale[[:space:]]*[:=]?[[:space:]]*([[:alnum:]_.-]+) ]]; then
    y_scale_value="${BASH_REMATCH[1]}"
  fi

  if [[ "$PROMPT" =~ x_range[[:space:]]*[:=]?[[:space:]]*([0-9.,[:space:]\[\]()+-]+) ]]; then
    x_range_spec="${BASH_REMATCH[1]}"
    x_range_spec="$(sed -E 's/[[:space:]]+//g' <<<"$x_range_spec")"
  fi

  if [[ "$PROMPT" =~ y_range[[:space:]]*[:=]?[[:space:]]*([0-9.,[:space:]\[\]()+-]+) ]]; then
    y_range_spec="${BASH_REMATCH[1]}"
    y_range_spec="$(sed -E 's/[[:space:]]+//g' <<<"$y_range_spec")"
  fi

  # title: cut at next keyword
  if [[ "$PROMPT" =~ title[[:space:]]*:[[:space:]]*(.+) ]]; then
    title="${BASH_REMATCH[1]}"
    title="$(sed -E 's/[[:space:]]*(save[[:space:]]+to|save[[:space:]]+session[[:space:]]+as|x[[:space:]]*[:=]|y[[:space:]]*[:=]|scatter|line|bar|sql:).*//I' <<<"$title" | sed -E 's/[[:space:]]+$//')"
  fi

  # WHERE: capture until next keyword, then trim any trailing "\" from user prompt
  if [[ "$PROMPT" =~ [Ww][Hh][Ee][Rr][Ee][[:space:]]*(.+) ]]; then
    where="$(sed -E 's/[[:space:]]*(title:|save[[:space:]]+to|save[[:space:]]+session[[:space:]]+as|x[[:space:]]*[:=]|y[[:space:]]*[:=]|scatter|line|bar|sql:).*//I' <<<"${BASH_REMATCH[1]}")"
    where="$(sed -E 's/[[:space:]]+$//' <<<"$where")"
    # If a stray backslash slipped in, drop it
    [[ "$where" =~ \\$ ]] && where="${where%\\}"
  fi

  # circle at (x,y) r=...
  if [[ "$PROMPT" =~ circle[[:space:]]*(at)?[[:space:]]*\(?[[:space:]]*([-0-9.]+)[[:space:]]*,[[:space:]]*([-0-9.]+)[[:space:]]*\)?([[:space:]]*r[[:space:]]*=?[[:space:]]*([-0-9.]+))? ]]; then
    cx="${BASH_REMATCH[2]}"; cy="${BASH_REMATCH[3]}"; cr="${BASH_REMATCH[5]}"
  fi

  # --- Build commands ---
  local cmds=()
  cmds+=("caddie csv:unset:all")
  [[ -n "$path"  ]] && cmds+=("caddie csv:set:file $path")
  [[ -n "$plot"  ]] && cmds+=("caddie csv:set:plot ${plot,,}")
  [[ -n "$x"     ]] && cmds+=("caddie csv:set:x $x")
  [[ -n "$y"     ]] && cmds+=("caddie csv:set:y $y")
  if [[ -n "$title" ]]; then
    local esc_title; esc_title="$(sed "s/'/'\\\\''/g" <<<"$title")"
    cmds+=("caddie csv:set:title '$esc_title'")
  fi
  [[ -n "$save"  ]] && cmds+=("caddie csv:set:save $save")

  if [[ -n "$segment_column" ]]; then
    cmds+=("caddie csv:set:segment_column $segment_column")
  fi

  if [[ -n "$segment_palette" ]]; then
    local esc_palette; esc_palette="$(sed "s/'/'\\\\''/g" <<<"$segment_palette")"
    cmds+=("caddie csv:set:segment_colors '$esc_palette'")
  fi

  if [[ -n "$x_scale_value" ]]; then
    cmds+=("caddie csv:set:x_scale ${x_scale_value,,}")
  fi

  if [[ -n "$y_scale_value" ]]; then
    cmds+=("caddie csv:set:y_scale ${y_scale_value,,}")
  fi

  if [[ -n "$x_range_spec" ]]; then
    local esc_x_range; esc_x_range="$(sed "s/'/'\\\\''/g" <<<"$x_range_spec")"
    cmds+=("caddie csv:set:x_range '$esc_x_range'")
  fi

  if [[ -n "$y_range_spec" ]]; then
    local esc_y_range; esc_y_range="$(sed "s/'/'\\\\''/g" <<<"$y_range_spec")"
    cmds+=("caddie csv:set:y_range '$esc_y_range'")
  fi


  if [[ -n "$where" ]]; then
    local esc_where; esc_where="$(sed "s/'/'\\\\''/g" <<<"$where")"
    if [[ -z "${query}" ]]; then
      cmds+=("caddie csv:set:scatter_filter '$esc_where'")
    fi
  fi

  if [[ -n "$sql" ]]; then
    local esc_sql; esc_sql="$(sed "s/'/'\\\\''/g" <<<"$sql")"
    cmds+=("caddie csv:set:sql '$esc_sql'")
  fi

  if [[ -n "$cx" && -n "$cy" ]]; then
    cmds+=("caddie csv:set:circle true")
    cmds+=("caddie csv:set:circle_x $cx")
    cmds+=("caddie csv:set:circle_y $cy")
    [[ -n "$cr" ]] && cmds+=("caddie csv:set:circle_r $cr")
  fi

  if [[ -n "$rings" ]]; then
    local rr; rr="$(tr -d ' ' <<<"$rings")"
    cmds+=("caddie csv:set:rings true")
    cmds+=("caddie csv:set:circle_radii $rr")
  fi

  cmds+=("caddie csv:list")

  if [[ -n "${query}"  ]]; then
    if [[ ${query} == "query" ]]; then
      cmds+=("caddie csv:query")
    else
      cmds+=("caddie csv:query:summary")
    fi
  fi

  case "${plot,,}" in
    line)       cmds+=("caddie csv:line");;
    bar)        cmds+=("caddie csv:bar");;
    scatter)    cmds+=("caddie csv:scatter");;
  esac

  [[ -n "$sess" ]] && cmds+=("caddie csv:session:save $sess")

  shopt -u nocasematch

  if (( DRY )); then
    printf '%s\n' "${cmds[@]}"
  else
    local cmd; for cmd in "${cmds[@]}"; do eval "$cmd"; done
  fi
}

if declare -F caddie_prompt_register_segment >/dev/null 2>&1; then
    caddie_prompt_register_segment caddie_csv_prompt_segment
fi

if declare -F caddie_completion_register >/dev/null 2>&1; then
    caddie_completion_register "csv" "$(caddie_csv_commands)"
fi

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
