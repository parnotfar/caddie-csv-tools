#!/usr/bin/env bash

# Caddie CSV Tools - Session Management Module
# Handles session save, restore, delete, and list operations

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
            env=$(caddie_csv_env_name "$alias") || continue
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
