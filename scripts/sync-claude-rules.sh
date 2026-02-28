#!/bin/bash
# Automated sync script for personal Claude rules, dotfiles, and tool inventory
# Syncs ~/.claude/CLAUDE.md, settings.json, .zshrc, and MCP/plugin inventory to GitHub repo daily

set -e

# Auto-detect repo path from script location (works for both symlinks and direct calls)
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_SOURCE" ]]; do
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_PATH="$(dirname "$SCRIPT_DIR")"
CLAUDE_FILE=~/.claude/CLAUDE.md
LOG_FILE="$REPO_PATH/sync.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Starting Claude rules sync ==="

if [[ ! -f "$CLAUDE_FILE" ]]; then
    log "ERROR: Claude rules file not found at $CLAUDE_FILE"
    exit 1
fi

if [[ ! -d "$REPO_PATH/.git" ]]; then
    log "ERROR: Repo not found at $REPO_PATH"
    exit 1
fi

# Copy current file to repo
log "Copying CLAUDE.md from ~/.claude to repo..."
cp "$CLAUDE_FILE" "$REPO_PATH/CLAUDE.md"

cd "$REPO_PATH"

# Install git hooks from repo (survives fresh clones)
if [[ -f "$REPO_PATH/scripts/hooks/pre-push" ]]; then
    cp "$REPO_PATH/scripts/hooks/pre-push" "$REPO_PATH/.git/hooks/pre-push"
    chmod +x "$REPO_PATH/.git/hooks/pre-push"
fi

# Pull latest changes from remote
log "Pulling latest changes from GitHub..."
if git pull --rebase origin master 2>&1 | tee -a "$LOG_FILE"; then
    log "Successfully pulled latest changes"
else
    log "Pull had conflicts, attempting to continue..."
fi

# Run markdown linting if available
if command -v markdownlint-cli2 &>/dev/null; then
    log "Running markdown linting..."
    markdownlint-cli2 --fix "CLAUDE.md" 2>&1 | tee -a "$LOG_FILE" || true
    # Copy linted version back
    cp "$REPO_PATH/CLAUDE.md" "$CLAUDE_FILE"
    log "Linted version copied back to ~/.claude"
else
    log "markdownlint-cli2 not found, skipping lint"
fi

# Also sync settings.json if it exists
if [[ -f ~/.claude/settings.json ]]; then
    cp ~/.claude/settings.json "$REPO_PATH/settings.json"
fi

# Also sync .zshrc if it exists
if [[ -f ~/.zshrc ]]; then
    log "Copying .zshrc to repo..."
    cp ~/.zshrc "$REPO_PATH/.zshrc"
fi

# Sync skills directory and generate skills.json
if [[ -d ~/.claude/skills ]]; then
    log "Syncing skills..."
    mkdir -p "$REPO_PATH/skills"
    cp ~/.claude/skills/*.md "$REPO_PATH/skills/" 2>/dev/null || true
    # Generate skills.json manifest from skill files
    python3 -c "
import json, os, re

skills_dir = os.path.join('$REPO_PATH', 'skills')
skills = []
for f in sorted(os.listdir(skills_dir)):
    if not f.endswith('.md'):
        continue
    skill_id = f.replace('.md', '')
    path = os.path.join(skills_dir, f)
    with open(path) as fh:
        content = fh.read()
    # Extract title from first heading
    title_match = re.search(r'^#\s+(.+)', content, re.MULTILINE)
    name = title_match.group(1).strip() if title_match else skill_id.replace('-', ' ').title()
    # Extract first paragraph after the heading as description
    lines = content.split('\n')
    desc = ''
    found_heading = False
    for line in lines:
        if line.startswith('# '):
            found_heading = True
            continue
        if found_heading and line.strip() and not line.startswith('#'):
            desc = line.strip()
            break
    # Guess category from content or filename
    category = 'Other'
    if 'slack' in skill_id.lower():
        category = 'Slack'
    elif 'pr' in skill_id.lower() or 'git' in skill_id.lower():
        category = 'Git'
    skills.append({
        'name': name,
        'id': skill_id,
        'command': '/' + skill_id,
        'description': desc,
        'file': 'skills/' + f,
        'category': category,
    })

with open(os.path.join('$REPO_PATH', 'skills.json'), 'w') as out:
    json.dump(skills, out, indent=2)
print(f'Updated skills.json: {len(skills)} skills')
" 2>&1 | tee -a "$LOG_FILE" || log "Skills inventory generation failed (non-fatal)"
fi

# Generate MCP and plugin inventory from settings
log "Generating MCP and plugin inventory..."
python3 -c "
import json, os

repo_path = '$REPO_PATH'

# Read config.json for project paths
config_path = os.path.join(repo_path, 'config.json')
project_paths = []
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)
    project_paths = [os.path.expanduser(p) for p in config.get('project_paths', [])]

# Read global settings
global_settings = {}
global_path = os.path.expanduser('~/.claude/settings.json')
if os.path.exists(global_path):
    with open(global_path) as f:
        global_settings = json.load(f)

# Read project settings from all configured project paths
all_project_plugins = set()
for proj in project_paths:
    for suffix in ['.claude/settings.json', '.claude/settings.local.json']:
        path = os.path.join(proj, suffix)
        if os.path.exists(path):
            with open(path) as f:
                data = json.load(f)
            all_project_plugins.update(data.get('enabledPlugins', {}).keys())

# Extract plugins
global_plugins = set(global_settings.get('enabledPlugins', {}).keys())
all_plugins = global_plugins | all_project_plugins

plugins = []
for p in sorted(all_plugins):
    parts = p.split('@')
    name = parts[0].replace('-', ' ').title()
    marketplace = parts[1] if len(parts) > 1 else 'unknown'
    scope_parts = []
    if p in global_plugins: scope_parts.append('global')
    if p in all_project_plugins: scope_parts.append('project')
    plugins.append({
        'name': name,
        'id': parts[0],
        'marketplace': marketplace,
        'scope': ' + '.join(scope_parts)
    })

with open(os.path.join(repo_path, 'plugins.json'), 'w') as f:
    json.dump(plugins, f, indent=2)

print(f'Updated plugins.json: {len(plugins)} plugins')
" 2>&1 | tee -a "$LOG_FILE" || log "Plugin inventory generation failed (non-fatal)"

# Write build metadata for the site
echo "{\"synced_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "$REPO_PATH/build-meta.json"

# Sync insights report if one exists
if [[ -f ~/.claude/usage-data/report.html ]]; then
    log "Syncing latest insights report..."
    "$REPO_PATH/scripts/sync-insights.sh" || log "Insights sync failed (non-fatal)"
fi

# Run Lighthouse a11y check on the site
log "Running Lighthouse accessibility audit..."
if command -v npx &>/dev/null; then
    # Start a temp server, run Lighthouse, kill server
    python3 -m http.server 8799 --directory "$REPO_PATH" &>/dev/null &
    LH_SERVER_PID=$!
    sleep 1
    LH_SCORE=$(npx lighthouse http://localhost:8799/index.html \
        --only-categories=accessibility \
        --output=json \
        --chrome-flags="--headless --no-sandbox" 2>/dev/null \
        | python3 -c "import sys,json;print(int(json.load(sys.stdin)['categories']['accessibility']['score']*100))" 2>/dev/null)
    kill $LH_SERVER_PID 2>/dev/null
    if [[ -n "$LH_SCORE" ]]; then
        log "Lighthouse a11y score: $LH_SCORE/100"
        if [[ "$LH_SCORE" -lt 95 ]]; then
            log "WARNING: Accessibility score dropped below 95!"
        fi
    else
        log "Lighthouse audit returned no score (non-fatal)"
    fi
else
    log "npx not found, skipping Lighthouse audit"
fi

# Commit and push if there are changes
if [[ -n $(git status -s) ]]; then
    log "Changes detected, committing..."
    git add -A
    git commit -m "Auto-sync Claude rules — $(date '+%Y-%m-%d %H:%M')"
    log "Pushing to GitHub..."
    if git push origin master 2>&1 | tee -a "$LOG_FILE"; then
        log "Successfully synced to GitHub"
    else
        log "Failed to push to GitHub"
        exit 1
    fi
else
    log "No changes to sync"
fi

log "=== Sync completed ==="
