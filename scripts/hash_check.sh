#!/usr/bin/env bash
set -euo pipefail

# Generate SHA-256 hash logs for a given run directory.
#
# Usage:
#   hash_check.sh <run_dir>
#
# Example:
#   hash_check.sh runs/2025-11-09_run1
#
# Outputs:
#   _logs/hashes_originals.txt
#   _logs/hashes_working.txt
#   _logs/hashes_time_sorted.txt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/helpers.sh" ]]; then
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/helpers.sh"
else
  log() { printf "[%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$*" >&2; }
  die() { log "ERROR: $*"; exit 1; }
fi

RUN_DIR="${1:-}"

if [[ -z "$RUN_DIR" ]]; then
  cat >&2 <<EOF
Usage: $(basename "$0") <run_dir>

Example:
  $(basename "$0") runs/2025-11-09_run1
EOF
  exit 1
fi

[[ -d "$RUN_DIR" ]] || die "Run dir does not exist: $RUN_DIR"

RUN_DIR="$(cd "$RUN_DIR" && pwd)"
LOG_DIR="$RUN_DIR/_logs"
mkdir -p "$LOG_DIR"

command -v sha256sum >/dev/null 2>&1 || die "sha256sum not found"

hash_dir() {
  local subdir="$1"
  local label="$2"
  local dir="$RUN_DIR/$subdir"
  local outfile="$LOG_DIR/hashes_${label}.txt"

  if [[ -d "$dir" ]]; then
    log "Hashing JPEG/PNG files in $dir → $outfile"
    # Sort paths to ensure stable ordering.
    find "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0 \
      | sort -z \
      | xargs -0 sha256sum > "$outfile"
  else
    log "Skipping $subdir (directory not present)"
  fi
}

hash_dir "originals"   "originals"
hash_dir "working"     "working"
hash_dir "time_sorted" "time_sorted"

log "✅ Hash logs written under: $LOG_DIR"
