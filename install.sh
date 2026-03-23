#!/bin/bash
# Install claude-skills by symlinking into ~/.claude/skills/
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.claude/skills"
mkdir -p "$TARGET"

count=0
for skill in "$REPO_DIR/skills"/*/; do
    [ -d "$skill" ] || continue
    name=$(basename "$skill")
    if [ -L "$TARGET/$name" ]; then
        echo "Update: $name (re-linked)"
        rm "$TARGET/$name"
    elif [ -d "$TARGET/$name" ]; then
        echo "Skip:   $name (non-symlink directory exists — back it up first)"
        continue
    else
        echo "Install: $name"
    fi
    ln -s "$skill" "$TARGET/$name"
    count=$((count + 1))
done

echo ""
echo "$count skill(s) installed. They are now available in Claude Code globally."
