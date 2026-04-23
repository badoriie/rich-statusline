---
name: statusline-setup
description: Install and configure the rich-statusline plugin. Use when the user says "setup statusline", "configure statusline", "install statusline", "enable statusline", or "statusline not working".
allowed-tools: [Read, Edit, Bash, Write]
---

# Rich Statusline Setup

Install the bundled `statusline-command.sh` script and configure Claude Code to use it.

## Steps

1. **Find the skill directory** — this SKILL.md lives inside the plugin install path. Resolve its absolute directory:
   ```sh
   SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
   ```
   The script is at `<skill-dir>/../../scripts/statusline-command.sh`.

2. **Copy the script** to `~/.claude/statusline-command.sh` and make it executable:
   ```sh
   cp "<skill-dir>/../../scripts/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
   chmod +x "$HOME/.claude/statusline-command.sh"
   ```

3. **Wire it into settings** — read `~/.claude/settings.json`, then set the `statusline` key:
   ```json
   {
     "statusline": "~/.claude/statusline-command.sh"
   }
   ```
   Use the Edit tool to update the file. If the file doesn't exist yet, create it with just the statusline key.

4. **Confirm** by telling the user the script was copied to `~/.claude/statusline-command.sh` and settings were updated. Remind them to start a new Claude Code session for the statusline to appear.

## Notes

- Do not overwrite an existing `statusline` setting without asking the user first.
- The script requires `jq` to be installed (`brew install jq` on macOS).
- The script reads live data from stdin (JSON piped in by Claude Code) — no further configuration is needed.
