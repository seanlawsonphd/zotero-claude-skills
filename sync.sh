#!/bin/bash
# Publish step: copy the live skills from ~/.claude/skills into this repo, then commit and push.
#   ./sync.sh            (edit the skills in ~/.claude/skills first; this is one-directional)
set -euo pipefail
cd "$(dirname "$0")"
for skill in zotero-translator zotero-plugin; do
	rsync -a --delete --exclude '.DS_Store' --exclude '*-workspace/' "$HOME/.claude/skills/$skill/" "$skill/"
done
git status --short
echo "Review the diff, then: git add -A && git commit -m 'Sync skills' && git push"
