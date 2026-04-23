# rich-statusline

A rich 5-line status line for [Claude Code](https://claude.ai/code) that shows everything you need at a glance after each response.

## What it shows

```
~/projects/my-app  main ●  [style: concise]
Claude Sonnet 4.6 │ effort: auto │ v2.1.87 │ id: abc123...
context: 34k/200k │ tokens out: 22k │ cache hit: 54k  saved: $0.0015 (total: $0.42)
cost: $0.031 (total: $1.240) │ session: 12m30s │ lines: +201 / -145
5h limit: 17%  resets in 2h30m (14:32) │ 7d limit: 27%  resets in 3d14h
```

- **Line 1** — working directory, git branch, dirty indicator, output style
- **Line 2** — model, effort level, Claude Code version, session ID
- **Line 3** — context window usage, output tokens, cache hits + cumulative savings
- **Line 4** — cost (session + total), session duration (with API time), lines added/removed
- **Line 5** — 5-hour and 7-day rate limit usage with reset countdowns

## Requirements

- `jq` — `brew install jq` on macOS

## Installation

In Claude Code, add this repo as a marketplace, then install the plugin:

```
/plugin marketplace add badoriie/rich-statusline
/plugin install rich-statusline@badoriie
```

Then ask Claude to "setup the statusline" — it will invoke the bundled skill to configure `settings.json` automatically, pointing directly at the plugin's script.

## Manual setup

Find the script path, then add it to `~/.claude/settings.json`:

```sh
ls ~/.claude/plugins/cache/badoriie/rich-statusline/*/scripts/statusline-command.sh
```

```json
{
  "statusLine": {
    "type": "command",
    "command": "/absolute/path/from/above"
  }
}
```

Restart Claude Code.

## License

MIT
