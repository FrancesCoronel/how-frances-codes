# How Frances Codes 🤖

Personal Claude Code configuration — MCPs, plugins, hooks, settings, skills, and coding preferences.

**[View the site](https://fvcproductions.github.io/how-frances-codes/)**

## Fork It 🍴

Want your own version? Three steps:

```bash
# 1. Fork this repo on GitHub, then clone your fork
gh repo fork fvcproductions/how-frances-codes --clone

# 2. Run setup (auto-detects your name, GitHub user, projects)
cd how-frances-codes
./scripts/setup.sh

# 3. Do the first sync
~/bin/sync-claude-rules.sh
```

That's it. Setup will:

- Generate `config.json` with your GitHub username and display name
- Find all your Claude Code projects (repos with `.claude/` directories)
- Install a daily LaunchAgent that syncs at 10am
- Clear the sample data so your own config populates

Your site will be live at `https://<username>.github.io/how-frances-codes/` once GitHub Pages is enabled.

## Repository Structure 📦

```text
/
├── index.html          Site entry point (GitHub Pages serves from root)
├── config.json         Personalization config (name, GitHub user, projects)
├── CLAUDE.md           Personal global Claude instructions
├── settings.json       Global Claude settings (model, hooks, plugins)
├── .zshrc              Shell aliases for development
├── mcps.json           MCP server inventory
├── plugins.json        Plugin inventory
├── skills.json         Skills manifest
├── tools.json          Tools & software inventory
├── manifest.json       Insights report manifest
├── build-meta.json     Build timestamp for "last synced" display
├── favicon.svg         Site favicon
├── reports/            Insights reports
├── skills/             Skill template files
├── scripts/            Automation scripts
│   ├── setup.sh        One-command fork setup
│   ├── sync-claude-rules.sh
│   └── sync-insights.sh
└── .markdownlint.json  Linting config
```

## What Gets Synced 🔄

Every day at 10am, the sync script automatically:

1. Copies `~/.claude/CLAUDE.md` and `settings.json` to the repo
2. Copies `.zshrc` for shell alias documentation
3. Scans your project settings for MCP and plugin inventories
4. Syncs the latest `/insights` report if one exists
5. Runs markdown linting and commits changes

## CLAUDE.md 📄

Global instructions that shape how Claude Code works in every session:

- **Slack Messaging** 💬: mrkdwn formatting, project update templates, writing style guide
- **Git & PRs** 🔀: Branch naming, commit workflow, PR templates, draft + auto-merge
- **PR Descriptions** 📝: Structured template with Why, Testing, Before/After, Risks, Revert Plan
- **Code Review** 👀: Review PRs regardless of draft status

## MCP Servers 🔌

| Server | Tools | What it does |
|---|---|---|
| Slack | 9 | Read/send messages, canvases, search channels |
| Jira | 3 | Search issues, get details, list projects |
| Figma Desktop | 1 | Capture screenshots |
| Puppeteer | 7 | Headless browser control |

## Plugins 🧩

| Plugin | Source | Scope |
|---|---|---|
| Code Review | claude-plugins-official | Global |
| Frontend Design | claude-plugins-official | Global |

## Hooks 🪝

| Event | Matcher | Action |
|---|---|---|
| Notification | `idle_prompt` | macOS notification with Glass sound |
| Notification | `permission_prompt` | macOS notification with Ping sound |
| Stop | All | macOS notification with Submarine sound |
| PostToolUse | `Write\|Edit` | Auto-format with prettier/markdownlint |

## Auto-Sync ♻️

A daily LaunchAgent syncs `~/.claude/CLAUDE.md`, `settings.json`, and `.zshrc` to this repo every day at 10am. See [SYNC-README.md](SYNC-README.md) for details.

```bash
# Manual sync
~/bin/sync-claude-rules.sh
```

## License 📄

MIT
