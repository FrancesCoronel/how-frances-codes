#!/bin/bash
# Syncs the latest Claude Code insights report to the GitHub repo
# with a dated filename and updates the manifest for the index page.
#
# Usage: ./sync-insights.sh [YYYY-MM-DD]
#   If no date is provided, today's date is used.

set -e

# Auto-detect repo path from script location
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_SOURCE" ]]; do
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
REPO_PATH="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="$REPO_PATH/reports"
REPORT_SRC=~/.claude/usage-data/report.html
LOG_FILE="$REPO_PATH/sync.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

DATE="${1:-$(date '+%Y-%m-%d')}"
DEST="$REPORTS_DIR/$DATE.html"

log "=== Starting insights sync for $DATE ==="

if [[ ! -f "$REPORT_SRC" ]]; then
    log "ERROR: No report found at $REPORT_SRC. Run /insights first."
    exit 1
fi

# Copy the report
mkdir -p "$REPORTS_DIR"
cp "$REPORT_SRC" "$DEST"
log "Copied report to $DEST"

# Extract stats from the HTML (macOS-compatible using python3)
# The report has stat-value/stat-label pairs like: <div class="stat-value">542</div><div class="stat-label">Messages</div>
STATS_JSON=$(python3 -c "
import re, json
html = open('$DEST').read()
pairs = re.findall(r'<div class=\"stat-value\">([^<]+)</div>\s*<div class=\"stat-label\">([^<]+)</div>', html)
stats = {label.strip().lower(): value.strip() for value, label in pairs}
# Extract numeric values (strip non-digits for counts like '+5,338/-1,477')
def num(key):
    v = stats.get(key, '0')
    m = re.match(r'[\d,.]+', v.replace(',', ''))
    return int(float(m.group())) if m else 0
result = {
    'messages': num('messages'),
    'files': num('files'),
    'days': num('days'),
    'lines': stats.get('lines', '0'),
    'msgs_per_day': stats.get('msgs/day', '0')
}
print(json.dumps(result))
" 2>/dev/null || echo '{}')

log "Stats: $STATS_JSON"

# Update manifest.json (now at repo root)
MANIFEST="$REPO_PATH/manifest.json"
python3 -c "
import json
stats = json.loads('$STATS_JSON') if '$STATS_JSON' else {}
manifest_path = '$MANIFEST'
try:
    with open(manifest_path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = []

data = [r for r in data if r['date'] != '$DATE']
data.append({
    'date': '$DATE',
    'file': 'reports/$DATE.html',
    'messages': stats.get('messages', 0),
    'files': stats.get('files', 0),
    'days': stats.get('days', 0),
    'lines': stats.get('lines', '0'),
    'msgs_per_day': stats.get('msgs_per_day', '0')
})
data.sort(key=lambda r: r['date'], reverse=True)
with open(manifest_path, 'w') as f:
    json.dump(data, f, indent=2)
print(f'Manifest updated: {len(data)} reports')
"

cd "$REPO_PATH"

# Commit and push
if [[ -n $(git status -s reports/ manifest.json) ]]; then
    git add reports/ manifest.json
    git commit -m "Add insights report — $DATE"
    log "Pushing to GitHub..."
    if git push origin master 2>&1 | tee -a "$LOG_FILE"; then
        log "Successfully synced insights to GitHub"
        echo ""
        echo "Report published. GitHub Pages will deploy shortly."
    else
        log "Failed to push"
        exit 1
    fi
else
    log "No new changes to sync"
fi

log "=== Insights sync completed ==="
