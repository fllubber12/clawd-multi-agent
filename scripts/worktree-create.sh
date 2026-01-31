#!/bin/bash
# worktree-create.sh - Create isolated git worktree for fixes
#
# Usage:
#   worktree-create.sh <project> <branch-name>
#
# Example:
#   worktree-create.sh polymarket sentry-fix-12345
#
# Creates:
#   ~/clawd/workspace/<project>-<branch-name>/

set -e

PROJECT="${1:?Usage: worktree-create.sh <project> <branch-name>}"
BRANCH="${2:?Usage: worktree-create.sh <project> <branch-name>}"

CLAWD_HOME="${CLAWD_HOME:-$HOME/clawd}"
CONFIG_FILE="$CLAWD_HOME/config/repositories.json"
WORKSPACE_DIR="$CLAWD_HOME/workspace"

# Ensure workspace directory exists
mkdir -p "$WORKSPACE_DIR"

# Get project path from config
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] Config file not found: $CONFIG_FILE"
    exit 1
fi

PROJECT_PATH=$(jq -r ".projects.${PROJECT}.path // empty" "$CONFIG_FILE" | sed "s|~|$HOME|")

if [[ -z "$PROJECT_PATH" ]]; then
    echo "[ERROR] Unknown project: $PROJECT"
    echo "Available projects:"
    jq -r '.projects | keys[]' "$CONFIG_FILE"
    exit 1
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "[ERROR] Project directory not found: $PROJECT_PATH"
    exit 1
fi

# Worktree destination
WORKTREE_NAME="${PROJECT}-${BRANCH}"
WORKTREE_PATH="$WORKSPACE_DIR/$WORKTREE_NAME"

if [[ -d "$WORKTREE_PATH" ]]; then
    echo "[WARN] Worktree already exists: $WORKTREE_PATH"
    echo "Use worktree-cleanup.sh $WORKTREE_NAME to remove it first"
    exit 1
fi

# Create worktree
echo "[INFO] Creating worktree for $PROJECT..."
echo "  Source: $PROJECT_PATH"
echo "  Branch: $BRANCH"
echo "  Destination: $WORKTREE_PATH"

cd "$PROJECT_PATH"

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "[WARN] Uncommitted changes in $PROJECT_PATH"
    echo "  Worktree will be created from HEAD"
fi

# Create new branch and worktree
git worktree add -b "$BRANCH" "$WORKTREE_PATH" HEAD

# Set up venv symlink if project has one
VENV_PATH="$PROJECT_PATH/.venv"
if [[ -d "$VENV_PATH" ]]; then
    echo "[INFO] Linking venv..."
    ln -sf "$VENV_PATH" "$WORKTREE_PATH/.venv"
fi

# Copy .env if exists
ENV_FILE="$PROJECT_PATH/.env"
if [[ -f "$ENV_FILE" ]]; then
    echo "[INFO] Copying .env..."
    cp "$ENV_FILE" "$WORKTREE_PATH/.env"
fi

echo ""
echo "[OK] Worktree created successfully!"
echo ""
echo "To work in the worktree:"
echo "  cd $WORKTREE_PATH"
echo ""
echo "When done:"
echo "  $CLAWD_HOME/scripts/worktree-cleanup.sh $WORKTREE_NAME"
