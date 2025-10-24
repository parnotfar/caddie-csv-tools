#!/usr/bin/env bash

# Caddie CSV Tools - SQL Module
# Handles SQL prompt, history, editing, and related functionality

# SQL Command History Management
CADDIE_CSV_SQL_HISTORY=()
CADDIE_CSV_SQL_HISTORY_INDEX=-1

# Global variable to hold the current history line
CADDIE_CSV_SQL_CURRENT_HISTORY_LINE=""

# Global variable to hold edited content
CADDIE_CSV_SQL_EDITED_CONTENT=""

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
