#!/usr/bin/env bash

# Caddie CSV Tools - Prompt Module
# Handles natural language prompt processing

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
