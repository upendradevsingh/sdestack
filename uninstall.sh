#!/bin/bash
# Uninstall claude-skills by removing symlinks from ~/.claude/skills/
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.claude/skills"

count=0
for skill in "$REPO_DIR/skills"/*/; do
    [ -d "$skill" ] || continue
    name=$(basename "$skill")
    link="$TARGET/$name"
    if [ -L "$link" ]; then
        target=$(readlink "$link")
        if [ "$target" = "$skill" ]; then
            rm "$link"
            echo "Removed: $name"
            count=$((count + 1))
        else
            echo "Skip:   $name (symlink points elsewhere)"
        fi
    else
        echo "Skip:   $name (not a symlink)"
    fi
done

echo ""
echo "$count skill(s) uninstalled."
