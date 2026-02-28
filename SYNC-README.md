# Claude Rules Auto-Sync Setup

## Overview

Your personal Claude rules are automatically synced to GitHub with markdown linting every day at 10:00 AM.

## What's Set Up

### 1. Markdown Linting

- **Tool**: `markdownlint-cli2`
- **Config**: `.markdownlint.json` (in repo)
- **Auto-fixes**: Yes, common formatting issues are automatically corrected

### 2. Sync Script

- **Location**: `~/bin/sync-claude-rules.sh` (symlink to `scripts/sync-claude-rules.sh`)
- **What it does**:
  1. Copies `~/.claude/CLAUDE.md` and `~/.claude/settings.json` to the repo
  2. Pulls latest changes from GitHub
  3. Runs markdown linting and auto-fixes
  4. Copies linted version back to `~/.claude/CLAUDE.md`
  5. Generates MCP and plugin inventory from your settings
  6. Syncs the latest `/insights` report if one exists
  7. Commits and pushes changes if any exist
  8. Logs everything to `sync.log`

### 3. Daily Automation

- **Schedule**: Every day at 10:00 AM
- **Technology**: macOS LaunchAgent
- **Config**: `~/Library/LaunchAgents/com.<username>.sync-claude-rules.plist`

## Quick Start (Fork Setup)

```bash
gh repo fork fvcproductions/how-frances-codes --clone
cd how-frances-codes
./scripts/setup.sh
~/bin/sync-claude-rules.sh
```

## Manual Usage

### Run sync manually anytime

```bash
~/bin/sync-claude-rules.sh
```

### Check sync logs

```bash
tail -n 50 <repo-path>/sync.log
```

### Run markdown linting only

```bash
cd <repo-path>
markdownlint-cli2 --fix "CLAUDE.md"
```

## Managing the Daily Automation

### Check if automation is running

```bash
launchctl list | grep sync-claude-rules
```

### Stop daily automation

```bash
launchctl unload ~/Library/LaunchAgents/com.<username>.sync-claude-rules.plist
```

### Start daily automation

```bash
launchctl load ~/Library/LaunchAgents/com.<username>.sync-claude-rules.plist
```

### Change schedule

Edit the plist file and reload:

```bash
nano ~/Library/LaunchAgents/com.<username>.sync-claude-rules.plist
launchctl unload ~/Library/LaunchAgents/com.<username>.sync-claude-rules.plist
launchctl load ~/Library/LaunchAgents/com.<username>.sync-claude-rules.plist
```

Current schedule in plist:

- `Hour: 10` = 10:00 AM
- `Minute: 0` = :00

To change to a different time, update the `Hour` and `Minute` values.

## Markdown Linting Rules

The linter checks for:

- Consistent heading levels
- Proper list formatting
- Code block language specifications
- No trailing whitespace
- Consistent emphasis markers

Disabled rules:

- Line length (MD013) - allows long lines
- Inline HTML (MD033) - allows HTML in markdown
- First line heading (MD041) - not required

## Troubleshooting

### Sync failed?

Check the logs:

```bash
tail -n 50 <repo-path>/sync.log
```

### LaunchAgent not running?

Check system logs:

```bash
cat <repo-path>/launchd.log
cat <repo-path>/launchd.error.log
```

### Force a test run

```bash
launchctl start com.<username>.sync-claude-rules
```

## Files Involved

- `~/.claude/CLAUDE.md` - Your personal Claude rules (source of truth)
- `~/.claude/settings.json` - Your global Claude settings (also synced)
- `config.json` - Personalization config (name, GitHub user, project paths)
- `~/bin/sync-claude-rules.sh` - Symlink to the sync script
- `~/Library/LaunchAgents/com.<username>.sync-claude-rules.plist` - Daily schedule config

## Workflow

```text
~/.claude/CLAUDE.md + settings.json + .zshrc
       |
  [Copy to repo]
       |
  [Pull from GitHub]
       |
  [Run markdown linting]
       |
  [Copy back to ~/.claude]
       |
  [Generate MCP + plugin inventory]
       |
  [Sync insights report]
       |
  [Commit & push to GitHub]
```

This ensures your local file is always linted and your GitHub repo is always up to date.
