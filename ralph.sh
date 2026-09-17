#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [--tool claude|opencode] [--model MODEL] [max_iterations]

set -e

# Parse arguments
TOOL="opencode"  # Default to opencode
MODEL=""          # Optional model override
MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    --model=*)
      MODEL="${1#*=}"
      shift
      ;;
    *)
      # Assume it's max_iterations if it's a number
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "opencode" && "$TOOL" != "claude" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'opencode' or 'claude'."
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# prd.json / progress.txt live in the directory ralph.sh is invoked from (CWD),
# not alongside ralph.sh itself. Override with RALPH_PRD / RALPH_PROGRESS if needed.
PRD_FILE="${RALPH_PRD:-$PWD/prd.json}"
PROGRESS_FILE="${RALPH_PROGRESS:-$PWD/progress.txt}"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
# Per-iteration timeout in seconds. Set RALPH_ITER_TIMEOUT to override (default 30 min).
ITER_TIMEOUT="${RALPH_ITER_TIMEOUT:-1800}"

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph"
echo "  Tool:            $TOOL"
if [[ -n "$MODEL" ]]; then
  echo "  Model:           $MODEL"
fi
echo "  Max iterations:  $MAX_ITERATIONS"
echo "  Iter timeout:    ${ITER_TIMEOUT}s"
echo "  PRD file:        $PRD_FILE"

# Warn if MAX_ITERATIONS is fewer than the number of open stories
if [ -f "$PRD_FILE" ]; then
  OPEN_STORIES=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE" 2>/dev/null || echo "0")
  if [ "$OPEN_STORIES" -gt "$MAX_ITERATIONS" ]; then
    echo ""
    echo "WARNING: $OPEN_STORIES open stories but MAX_ITERATIONS=$MAX_ITERATIONS."
    echo "         Ralph will stop before all stories are complete."
    echo "         Run with: ralph.sh $OPEN_STORIES"
    echo ""
  fi
fi

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  # Run the selected tool with the ralph prompt
  # perl alarm provides a per-iteration timeout (macOS has no coreutils timeout by default)
  if [[ "$TOOL" == "opencode" ]]; then
    MODEL_FLAG=""
    if [[ -n "$MODEL" ]]; then
      MODEL_FLAG="-m $MODEL"
    fi
    OUTPUT=$(OPENCODE_PERMISSION='{"*":"allow"}' perl -e 'alarm shift; exec @ARGV' "$ITER_TIMEOUT" opencode run $MODEL_FLAG < "$SCRIPT_DIR/AGENTS.md" 2>&1) || true
  else
    # Claude Code: use --dangerously-skip-permissions for autonomous operation, --print for output
    MODEL_FLAG=""
    if [[ -n "$MODEL" ]]; then
      MODEL_FLAG="--model $MODEL"
    fi
    OUTPUT=$(perl -e 'alarm shift; exec @ARGV' "$ITER_TIMEOUT" claude --dangerously-skip-permissions $MODEL_FLAG --print < "$SCRIPT_DIR/CLAUDE.md" 2>&1) || true
  fi

  # Check for completion signal from the model
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  # Deterministic completion check: all stories passing in prd.json
  # (catches the case where the model completed work but the response was cut off / timed out)
  if [ -f "$PRD_FILE" ]; then
    REMAINING=$(jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE" 2>/dev/null || echo "-1")
    if [ "$REMAINING" = "0" ]; then
      echo ""
      echo "Ralph completed all tasks! (detected via prd.json)"
      echo "Completed at iteration $i of $MAX_ITERATIONS"
      exit 0
    fi
    echo "Iteration $i complete. $REMAINING stories remaining. Continuing..."
  else
    echo "Iteration $i complete. Continuing..."
  fi
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PRD_FILE and $PROGRESS_FILE for status."
exit 1
