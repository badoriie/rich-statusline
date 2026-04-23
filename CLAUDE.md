# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

**rich-statusline** is a Claude Code plugin that renders a rich, multi-line terminal status line after each AI response. It displays working directory, git status, model info, context window usage, token costs, cache savings, and API rate limit tracking.

## No Build System

This is a static Bash plugin — no build, compile, or install step required. There is no `package.json`, `Makefile`, or test suite. The only runtime dependency is `jq`.

## Installation (for local development / testing changes)

Point `settings.json` directly at the script in the repo — no copying needed:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/path/to/rich-statusline/scripts/statusline-command.sh"
  }
}
```

Replace `/path/to/rich-statusline` with the absolute path to your local clone. Changes to `scripts/statusline-command.sh` take effect immediately on the next Claude Code response.

## Architecture

All logic lives in one file: `scripts/statusline-command.sh`.

**How it works:**
- Claude Code invokes the script after each response, passing session JSON on stdin
- The script uses `jq` to extract fields (model, tokens, costs, cache hits, rate limits, etc.)
- Helper functions format values (e.g., `pct_color` for color-coded percentages, `fmt_tokens` for human-readable token counts)
- Output is up to 5 ANSI-colored lines written to stdout (lines are omitted when their data is absent)
- Cumulative cost and cache savings are tracked per-session in `~/.claude/costs/` and `~/.claude/cache_savings/` (flat files named by session ID)

**Output lines:**
1. Working directory, git branch (`●` dirty / `○` untracked), output style
2. Model name, effort level, version, session ID
3. Context usage bar, output tokens, cache hits and dollar savings
4. Total session cost, duration, API time
5. 5-hour and 7-day rate limit usage with reset countdowns

## Plugin Files

- `.claude-plugin/plugin.json` — plugin identity (name, author, description)
- `.claude-plugin/marketplace.json` — marketplace registry; enables `/plugin marketplace add badoriie/rich-statusline`
- `skills/statusline-setup/SKILL.md` — a Claude Code skill that configures `settings.json` to point at the plugin's script

## Releasing a New Version

Releases are fully automated via release-please (`.github/workflows/release.yml`). Use [Conventional Commits](https://www.conventionalcommits.org/) in your commit messages:

| Prefix | Effect |
|--------|--------|
| `fix:` | patch bump (1.0.x) |
| `feat:` | minor bump (1.x.0) |
| `feat!:` or `BREAKING CHANGE:` | major bump (x.0.0) |
| `chore:`, `docs:`, etc. | no release |

**What happens automatically on merge to main:**
1. release-please opens a release PR with bumped versions in `plugin.json` and `marketplace.json`
2. Merging that PR creates the git tag and GitHub release
3. A follow-up job updates `marketplace.json`'s `"ref"` field to the new tag

`plugin.json` is the authoritative version source and takes precedence over `marketplace.json`.

## Making Changes

Edit `scripts/statusline-command.sh` directly. Since `settings.json` points at the repo, changes are live immediately — just trigger a Claude Code response. The script can also be tested manually:

```bash
echo '{"your":"json"}' | bash scripts/statusline-command.sh
```

Pass a representative Claude Code session JSON payload on stdin to verify formatting without a full Claude session.

## Pre-commit Hook

A pre-commit hook in `.githooks/pre-commit` runs three checks on every commit:

1. **Bash syntax** — `bash -n scripts/statusline-command.sh`
2. **jq expression syntax** — validates every `jq` filter in the script
3. **Line count consistency** — verifies the count in the script help text matches `README.md`, `plugin.json`, and `marketplace.json`

Enable it once per clone:

```bash
git config core.hooksPath .githooks
```
