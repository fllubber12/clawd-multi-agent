#!/bin/bash
# worktree-cleanup.sh - Clean up git worktree after fix is merged
#
# Usage:
#   worktree-cleanup.sh <worktree-name>
#
# Example:
#   worktree-cleanup.sh polymarket-sentry-fix-12345
#
# This will:
#   1. Remove the worktree directory
#   2. Prune the worktree reference from git
#   3. Optionally delete the branch

set -e

WORKTREE_NAME="${1:?Usage: worktree-cleanup.sh <worktree-name>}"

CLAWD_HOME="${CLAWD_HOME:-$HOME/clawd}"
WORKSPACE_DIR="$CLAWD_HOME/workspace"
WORKTREE_PATH="$WORKSPACE_DIR/$WORKTREE_NAME"

if [[ ! -d "$WORKTREE_PATH" ]]; then
    echo "[ERROR] Worktree not found: $WORKTREE_PATH"
    echo ""
    echo "Available worktrees:"
    ls -1 "$WORKSPACE_DIR" 2>/dev/null || echo "  (none)"
    exit 1
fi

# Extract project and branch from worktree name
# Format: <project>-<branch>
PROJECT=$(echo "$WORKTREE_NAME" | cut -d'-' -f1)
BRANCH=$(echo "$WORKTREE_NAME" | cut -d'-' -f2-)

CONFIG_FILE="$CLAWD_HOME/config/repositories.json"
PROJECT_PATH=$(jq -r ".projects.${PROJECT}.path // empty" "$CONFIG_FILE" | sed "s|~|$HOME|")

if [[ -z "$PROJECT_PATH" ]]; then
    echo "[WARN] Could not determine project path for: $PROJECT"
    echo "  Will remove worktree directory but cannot prune git reference"
    rm -rf "$WORKTREE_PATH"
    echo "[OK] Removed: $WORKTREE_PATH"
    exit 0
fi

echo "[INFO] Cleaning up worktree..."
echo "  Worktree: $WORKTREE_PATH"
echo "  Project: $PROJECT_PATH"
echo "  Branch: $BRANCH"

# Check for uncommitted changes in worktree
cd "$WORKTREE_PATH"
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo ""
    echo "[WARN] Uncommitted changes detected!"
    read -p "Discard changes and continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "[ABORT] Cleanup cancelled"
        exit 1
    fi
fi

# Remove worktree
cd "$PROJECT_PATH"
git worktree remove "$WORKTREE_PATH" --force

echo "[OK] Worktree removed"

# Ask about branch deletion
echo ""
read -p "Delete branch '$BRANCH'? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Check if branch is merged
    if git branch --merged | grep -q "$BRANCH"; then
        git branch -d "$BRANCH"
        echo "[OK] Branch deleted (was merged)"
    else
        echo "[WARN] Branch not merged. Force delete?"
        read -p "Force delete unmerged branch? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git branch -D "$BRANCH"
            echo "[OK] Branch force deleted"
        else
            echo "[INFO] Branch kept: $BRANCH"
        fi
    fi
else
    echo "[INFO] Branch kept: $BRANCH"
fi

echo ""
echo "[OK] Cleanup complete!"
