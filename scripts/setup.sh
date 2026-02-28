#!/bin/bash
# One-command setup for how-<name>-codes
# Fork the repo, clone it, run this script, and you're done.
#
# Usage: ./scripts/setup.sh
#
# What it does:
#   1. Auto-detects your GitHub username and display name
#   2. Generates config.json with your info
#   3. Creates the daily LaunchAgent for auto-syncing
#   4. Symlinks the sync script to ~/bin/
#   5. Clears sample data so your own data populates on first sync

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_PATH="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$REPO_PATH/config.json"

echo "🤖 Setting up how-you-code..."
echo ""

# --- Detect GitHub info ---
if command -v gh &>/dev/null; then
    GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "")
    GH_NAME=$(gh api user --jq '.name // .login' 2>/dev/null || echo "")
    # Detect GitHub host (enterprise vs public)
    GH_HOST=$(git remote get-url origin 2>/dev/null | sed -n 's|.*[/@]\([^:/]*\)[:/].*|\1|p' || echo "github.com")
else
    echo "⚠️  gh CLI not found. Install it: https://cli.github.com"
    echo "   Falling back to git config..."
    GH_USER=$(git config user.name 2>/dev/null | tr ' ' '-' | tr '[:upper:]' '[:lower:]' || echo "")
    GH_NAME=$(git config user.name 2>/dev/null || echo "")
    GH_HOST="github.com"
fi

if [[ -z "$GH_USER" ]]; then
    echo "Could not detect GitHub username."
    read -rp "Enter your GitHub username: " GH_USER
fi
if [[ -z "$GH_NAME" ]]; then
    read -rp "Enter your display name: " GH_NAME
fi

# Extract first name for the site title
FIRST_NAME=$(echo "$GH_NAME" | awk '{print $1}')

echo "   GitHub user: $GH_USER"
echo "   Display name: $GH_NAME ($FIRST_NAME)"
echo "   GitHub host: $GH_HOST"
echo ""

# --- Detect project paths (repos with .claude/ directories) ---
echo "🔍 Scanning for Claude Code projects..."
PROJECT_PATHS=()
SEARCH_DIRS=("$HOME/Documents/GitHub" "$HOME/Projects" "$HOME/repos" "$HOME/src" "$HOME/code")
for dir in "${SEARCH_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        while IFS= read -r -d '' claude_dir; do
            project=$(dirname "$claude_dir")
            # Skip the how-*-codes repo itself
            if [[ "$project" != "$REPO_PATH" ]]; then
                PROJECT_PATHS+=("$project")
                echo "   Found: $project"
            fi
        done < <(find "$dir" -maxdepth 2 -name ".claude" -type d -print0 2>/dev/null)
    fi
done
if [[ ${#PROJECT_PATHS[@]} -eq 0 ]]; then
    echo "   No projects with .claude/ found (that's ok, you can add them to config.json later)"
fi
echo ""

# --- Generate config.json ---
echo "📝 Writing config.json..."
PROJECT_JSON="[]"
if [[ ${#PROJECT_PATHS[@]} -gt 0 ]]; then
    PROJECT_JSON=$(python3 -c "
import json
paths = $(python3 -c "import json; print(json.dumps([p.replace('$HOME', '~') for p in '''${PROJECT_PATHS[*]}'''.split()]))")
print(json.dumps(paths))
" 2>/dev/null || echo "[]")
fi

# Get avatar URL from GitHub API
AVATAR_URL=""
if command -v gh &>/dev/null; then
    AVATAR_URL=$(gh api user --jq '.avatar_url' 2>/dev/null || echo "")
fi

REPO_NAME=$(basename "$REPO_PATH")

cat > "$CONFIG_FILE" << EOF
{
  "name": "$FIRST_NAME",
  "full_name": "$GH_NAME",
  "github_username": "$GH_USER",
  "github_host": "$GH_HOST",
  "avatar_url": "$AVATAR_URL",
  "repo_name": "$REPO_NAME",
  "subtitle": "Personal Claude Code setup — MCPs, plugins, skills, hooks, and coding preferences",
  "project_paths": $PROJECT_JSON
}
EOF
echo "   Written to $CONFIG_FILE"
echo ""

# --- Clear sample data ---
echo "🧹 Clearing sample data..."
echo "[]" > "$REPO_PATH/manifest.json"
echo "{\"synced_at\": \"\"}" > "$REPO_PATH/build-meta.json"
rm -f "$REPO_PATH/reports/"*.html
# Clear personal files that will be replaced on first sync
: > "$REPO_PATH/CLAUDE.md"
echo "{}" > "$REPO_PATH/settings.json"
echo "[]" > "$REPO_PATH/plugins.json"
echo "[]" > "$REPO_PATH/mcps.json"
: > "$REPO_PATH/.zshrc"
echo "   Cleared reports, manifest, settings, plugins, mcps, CLAUDE.md, .zshrc"
echo ""

# --- Symlink sync script ---
echo "🔗 Setting up sync script..."
mkdir -p ~/bin
SYNC_SCRIPT="$REPO_PATH/scripts/sync-claude-rules.sh"
chmod +x "$SYNC_SCRIPT"
chmod +x "$REPO_PATH/scripts/sync-insights.sh"
if [[ -L ~/bin/sync-claude-rules.sh ]]; then
    rm ~/bin/sync-claude-rules.sh
fi
ln -s "$SYNC_SCRIPT" ~/bin/sync-claude-rules.sh
echo "   Symlinked ~/bin/sync-claude-rules.sh → $SYNC_SCRIPT"
echo ""

# --- Install LaunchAgent (daily at 10am) ---
echo "⏰ Installing daily sync (10:00 AM)..."
PLIST_LABEL="com.$(echo "$GH_USER" | tr '[:upper:]' '[:lower:]').sync-claude-rules"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

# Find node path for PATH env var
NODE_PATH=""
if command -v node &>/dev/null; then
    NODE_PATH=":$(dirname "$(which node)")"
fi

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$HOME/bin/sync-claude-rules.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>10</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$REPO_PATH/launchd.log</string>
    <key>StandardErrorPath</key>
    <string>$REPO_PATH/launchd.error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin$NODE_PATH</string>
    </dict>
</dict>
</plist>
EOF

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
echo "   Installed $PLIST_PATH"
echo "   Schedule: Every day at 10:00 AM"
echo ""

# --- Install git hooks ---
if [[ -f "$REPO_PATH/scripts/hooks/pre-push" ]]; then
    cp "$REPO_PATH/scripts/hooks/pre-push" "$REPO_PATH/.git/hooks/pre-push"
    chmod +x "$REPO_PATH/.git/hooks/pre-push"
    echo "🪝 Installed pre-push hook (Lighthouse a11y check)"
    echo ""
fi

# --- Done ---
echo "✅ Setup complete!"
echo ""
echo "What happens next:"
echo "  1. Run ~/bin/sync-claude-rules.sh to do the first sync now"
echo "  2. Your site will be live at:"
echo "     https://pages.$GH_HOST/$GH_USER/$(basename "$REPO_PATH")/"
echo "  3. The sync runs automatically every day at 10:00 AM"
echo ""
echo "To sync manually anytime:"
echo "  ~/bin/sync-claude-rules.sh"
