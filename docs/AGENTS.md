# Agent Modes & Prompts

This repository ships as a Caddie agent module. The Caddie shell advertises interactive “modes” that are stacked by
typing the first token of a command, pressing <kbd>return</kbd>, and then typing the next token. For example:

```text
caddie> rust
caddie[rust]-1.4>
```

The prompt reflects the active mode (`rust` in the example) and the agent version, making it easy to see which command
set is available at a glance. Returning to the root prompt is as simple as typing `exit` (or <kbd>Ctrl+D</kbd>).

## CSV Agent Prompt Flow

The CSV tools module integrates with the same prompt stack:

```text
caddie> csv
caddie[csv]-1.4>
```

Once the CSV mode is active, all `csv:*` commands are available without the `csv:` prefix. Typing `help` shows the CSV
command reference, and `exit` unwinds back to the previous prompt level.

### Nested SQL Prompt

Version 1.4 introduces a dedicated SQL prompt so you can compose and run multi-line statements without wrapping them in
`set sql '...'` calls. Drop into the nested prompt with:

```text
caddie[csv]-1.4> sql
caddie[csv sql]-1.4>
```

Key behaviours:

- Statements spanning multiple lines run automatically once they end with `;`
- `\g` (or `\go`) executes the current buffer, reusing the last statement if the buffer is empty
- `\summary` executes the buffer via `csv:query:summary`
- `\show`, `\history`, and `\clear` manage session defaults and in-flight queries
- `\q` (or `\quit`) exits back to `caddie[csv]-1.4>`

The SQL prompt updates `CADDIE_CSV_SQL`, so subsequent `csv:query` invocations (even outside the prompt) reuse the last
statement.

## Prompt Etiquette & Exiting

- `<Enter>` on a blank line keeps you in the current prompt level unless a statement is ready to execute.
- `exit` or <kbd>Ctrl+D</kbd> leaves the current mode; repeat as needed to reach the root `caddie>` prompt.
- Prompt segments include active CSV context — for example, `[csv:file.csv]` appears when a default CSV file is set.

Refer to [`docs/usage.md`](usage.md) for full command usage and integration tips.
