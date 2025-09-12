#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CALLBACK_DIR="$SCRIPT_DIR/clean-secrets-callbacks"

STATS_FILE=".clean-secrets-commit-stats.json"
PROGRESS_FILE=".clean-secrets-commit-progress.log"
FILTER_REPO_LOG=".clean-secrets-git-filter-repo.log"
CALLBACK_LOG=".clean-secrets-callbacks.log"
LOG_FILE=".clean-secrets.log"
WORKDIR="$(pwd)"

# === Usage help ===
print_help() {
  cat <<EOF
Usage: $0 <repo-path> <gitleaks-json> [--cleanup]

Arguments:
  <repo-path>         Path to the Git repository (bare or worktree)
  <gitleaks-json>     Gitleaks scan output (JSON file)

Options:
  --cleanup           Perform final cleanup (reflog expire, git gc, delete temp files)
  --help              Show this help message and exit

Example:
  $0 my-repo.git full-scan.json --cleanup
EOF
}

# === Parse args ===
REPO_PATH="${1:-}"
GITLEAKS_FILE="${2:-}"
DO_CLEANUP="${3:-}"

if [[ "$REPO_PATH" == "--help" || "$GITLEAKS_FILE" == "--help" || "$DO_CLEANUP" == "--help" ]]; then
  print_help
  exit 0
fi

# More robust argument validation - check argument count first
if [[ $# -lt 2 || -z "$REPO_PATH" || -z "$GITLEAKS_FILE" ]]; then
  echo "[ERROR] Missing arguments."
  print_help
  exit 1
fi

# === Initialize log file early ===
rm -f "$PROGRESS_FILE" "$LOG_FILE" "$STATS_FILE" "$FILTER_REPO_LOG" "$CALLBACK_LOG"
touch "$PROGRESS_FILE" "$LOG_FILE" "$STATS_FILE" "$FILTER_REPO_LOG" "$CALLBACK_LOG"

echo "[INFO] Started at $(date)" | tee -a "$LOG_FILE"
echo "[DEBUG] Script is running, PATH: $PATH" | tee -a "$LOG_FILE"

# === Validate Git repo ===
if ! git -C "$REPO_PATH" rev-parse --is-inside-work-tree > /dev/null 2>&1 && \
   ! git -C "$REPO_PATH" rev-parse --is-bare-repository > /dev/null 2>&1; then
  echo "[ERROR] '$REPO_PATH' is not a Git repository (worktree or bare)." | tee -a "$LOG_FILE"
  exit 1
fi

if [[ ! -f "$GITLEAKS_FILE" ]]; then
  echo "[ERROR] Gitleaks file '$GITLEAKS_FILE' not found." | tee -a "$LOG_FILE"
  exit 1
fi

# === Count total commits ===
echo "[INFO] Counting commits..." | tee -a "$LOG_FILE"
cd "$REPO_PATH"
TOTAL_COMMITS=$(git rev-list --all --count)
echo "{\"total_commits\": $TOTAL_COMMITS}" > "$WORKDIR/$STATS_FILE"
cd "$WORKDIR"

# === Copy gitleaks JSON into repo directory if needed ===
if [ "$GITLEAKS_FILE" != "$REPO_PATH/full-scan.json" ]; then
  cp "$GITLEAKS_FILE" "$REPO_PATH/full-scan.json"
fi

# === Isolate Git config ===
echo "[INFO] Isolating Git config..." | tee -a "$LOG_FILE"
TEMP_HOME=$(mktemp -d)
export HOME="$TEMP_HOME"
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_LOCAL=/dev/null
# Preserve PATH to ensure git-filter-repo can be found
export PATH="$PATH"

# === Tail progress and git-filter-repo log ===
echo "[INFO] Tailing commit progress..." | tee -a "$LOG_FILE"
# Ensure log files exist before tailing
touch "$FILTER_REPO_LOG" "$PROGRESS_FILE"
tail -n 0 -f "$FILTER_REPO_LOG" "$PROGRESS_FILE" | tee -a "$LOG_FILE" &
TAIL_PID=$!
# Trap guarantees the tail process is cleaned up even on error or Ctrl+C.
trap "kill $TAIL_PID 2>/dev/null || true" EXIT

# === Run git-filter-repo ===
echo "[INFO] Running git-filter-repo..." | tee -a "$LOG_FILE"

# Check if git-filter-repo is available
if ! command -v git-filter-repo >/dev/null 2>&1; then
  echo "[ERROR] git-filter-repo not found in PATH" | tee -a "$LOG_FILE"
  echo "[ERROR] PATH: $PATH" | tee -a "$LOG_FILE"
  echo "[ERROR] Please install git-filter-repo: pip3 install git-filter-repo" | tee -a "$LOG_FILE"
  exit 1
fi

echo "[INFO] Using git-filter-repo: $(command -v git-filter-repo)" | tee -a "$LOG_FILE"

(
  cd "$REPO_PATH"
  export PATH="$PATH"
  PROGRESS_FILE="$WORKDIR/$PROGRESS_FILE" \
  STATS_FILE="$WORKDIR/$STATS_FILE" \
  GITLEAKS_FILE="full-scan.json" \
  CALLBACK_LOG="$WORKDIR/$CALLBACK_LOG" \
  git filter-repo --force \
    --commit-callback "$(cat "$CALLBACK_DIR/commit.py")" \
    --file-info-callback "$(cat "$CALLBACK_DIR/file-info.py")" \
    --message-callback "$(cat "$CALLBACK_DIR/message.py")"
) > "$FILTER_REPO_LOG" 2>&1
FILTER_EXIT_CODE=$?

# === Stop tail ===
kill "$TAIL_PID" > /dev/null 2>&1 || true
wait "$TAIL_PID" 2>/dev/null || true
echo "[INFO] Progress tracking finished." | tee -a "$LOG_FILE"

# === Final stats ===
if [[ -f "$STATS_FILE" && -f "$PROGRESS_FILE" ]]; then
  total=$(jq '.total_commits' "$STATS_FILE")
  seen=$(wc -l < "$PROGRESS_FILE" | xargs)
  echo "[INFO] Processed $seen / $total commits" | tee -a "$LOG_FILE"
  rm -f "$PROGRESS_FILE"
fi

# === Callback log info ===
if [[ -f "$CALLBACK_LOG" ]]; then
  callback_lines=$(wc -l < "$CALLBACK_LOG" | xargs)
  echo "[INFO] Callback log contains $callback_lines entries: $CALLBACK_LOG" | tee -a "$LOG_FILE"
fi

# === Generate Simple Recap ===
echo "" | tee -a "$LOG_FILE"
echo "=== SECRET CLEANUP RECAP ===" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

if [[ -f "$CALLBACK_LOG" ]]; then
  echo "📊 SUMMARY:" | tee -a "$LOG_FILE"
  
  # Count secrets removed
  secrets_removed=$(grep -c "Removed secret from line" "$CALLBACK_LOG" 2>/dev/null || echo "0")
  files_modified=$(grep -c "Modified.*lines in" "$CALLBACK_LOG" 2>/dev/null || echo "0")
  messages_redacted=$(grep -c "Found 'SECRET' in commit message" "$CALLBACK_LOG" 2>/dev/null || echo "0")
  
  echo "   • Secrets removed: $secrets_removed" | tee -a "$LOG_FILE"
  echo "   • Files modified: $files_modified" | tee -a "$LOG_FILE"
  echo "   • Commit messages redacted: $messages_redacted" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  
  # Show files with secrets
  if [[ $secrets_removed -gt 0 ]]; then
    echo "📁 FILES WITH SECRETS REMOVED:" | tee -a "$LOG_FILE"
    grep "Removed secret from line" "$CALLBACK_LOG" | sed 's/.*Removed secret from line [0-9]* in //' | sort | uniq -c | sort -nr | head -5 | while read count file; do
      echo "   • $file: $count secrets" | tee -a "$LOG_FILE"
    done
    echo "" | tee -a "$LOG_FILE"
  fi
  
  echo "📄 Full callback log: $CALLBACK_LOG" | tee -a "$LOG_FILE"
else
  echo "No callback log found - detailed recap not available." | tee -a "$LOG_FILE"
fi

# === Optional cleanup ===
if [[ "$DO_CLEANUP" == "--cleanup" ]]; then
  echo "[INFO] Performing final cleanup..." | tee -a "$LOG_FILE"
  (
    cd "$REPO_PATH"
    rm -rf .git/filter-repo/
    rm -f full-scan.json
    git reflog expire --expire=now --all
    git gc --prune=now --aggressive
  )
else
  echo "[INFO] Skipping final cleanup (use --cleanup to enable)" | tee -a "$LOG_FILE"
fi

rm -rf "$TEMP_HOME"
echo "[DONE] Completed at $(date)" | tee -a "$LOG_FILE"

exit $FILTER_EXIT_CODE