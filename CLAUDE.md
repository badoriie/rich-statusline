# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

**rich-statusline** is a Claude Code plugin that renders a rich, multi-line terminal status line after each AI response. It displays working directory, git status, model info, context window usage, token costs, cache savings, and API rate limit tracking.

## No Build System

This is a static Bash plugin — no build, compile, or install step required. There is no `package.json`, `Makefile`, or test suite. The only runtime dependency is `jq`.

## Installation (for local development / testing changes)

```bash
# Copy the script to the Claude config directory
cp scripts/statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh

# Ensure ~/.claude/settings.json contains:
# {
#   "statusLine": {
#     "type": "command",
#     "command": "~/.claude/statusline-command.sh"
#   }
# }
# Note: use camelCase "statusLine" and the object form with "type" and "command"
```

After editing `statusline-command.sh`, re-copy it to `~/.claude/` to test changes live in a Claude Code session.

## Architecture

All logic lives in one file: `scripts/statusline-command.sh`.

**How it works:**
- Claude Code invokes the script after each response, passing session JSON on stdin
- The script uses `jq` to extract fields (model, tokens, costs, cache hits, rate limits, etc.)
- Helper functions format values (e.g., `pct_color` for color-coded percentages, `fmt_tokens` for human-readable token counts)
- Output is 4–5 ANSI-colored lines written to stdout
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
- `skills/statusline-setup/SKILL.md` — a Claude Code skill that automates copying the script and setting `settings.json`

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

Edit `scripts/statusline-command.sh` directly. To test: copy it to `~/.claude/statusline-command.sh` and trigger a Claude Code response. The script can also be tested manually:

```bash
echo '{"your":"json"}' | bash scripts/statusline-command.sh
```

Pass a representative Claude Code session JSON payload on stdin to verify formatting without a full Claude session.
