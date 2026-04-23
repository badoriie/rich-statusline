---
name: statusline-setup
description: Install and configure the rich-statusline plugin. Use when the user says "setup statusline", "configure statusline", "install statusline", "enable statusline", or "statusline not working".
allowed-tools: [Read, Edit, Bash, Write]
---

# Rich Statusline Setup

Configure Claude Code to use the bundled `statusline-command.sh` script directly from the plugin install path — no copying needed.

## Steps

1. **Find the script path** — use the Bash tool to locate the installed script:
   ```sh
   ls ~/.claude/plugins/cache/badoriie/rich-statusline/*/scripts/statusline-command.sh
   ```
   Use the resulting absolute path in the next step.

2. **Wire it into settings** — read `~/.claude/settings.json`, then set the `statusLine` key (camelCase, object form) pointing at the resolved absolute path:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/absolute/path/to/plugin/scripts/statusline-command.sh"
     }
   }
   ```
   Use the Edit tool to update the file. If the file doesn't exist yet, create it with just this key.

3. **Confirm** by telling the user the `statusLine` setting was updated to point at the plugin path. Remind them to start a new Claude Code session for the statusline to appear.

## Notes

- Do not overwrite an existing `statusLine` setting without asking the user first.
- The script requires `jq` to be installed (`brew install jq` on macOS).
- The script reads live data from stdin (JSON piped in by Claude Code) — no further configuration is needed.
