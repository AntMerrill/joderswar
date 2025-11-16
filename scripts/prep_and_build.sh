#!/usr/bin/env bash
set -euo pipefail

# prep_and_build.sh
#
# Run the full pipeline in order:
#   1) phone_import.sh  (prep JPG stills)
#   2) mov_exif.sh      (prep MOV/MP4 metadata)
#   3) update runs/current -> <run_dir> symlink
#   4) call build_any.sh to generate the PDF
#
# Usage:
#   prep_and_build.sh <source_dir> <run_dir> <project> <doc_num>
#
# Examples:
#   prep_and_build.sh images/exhibit2 runs/2025-11-15_run1 permits 14
#   prep_and_build.sh images/exhibit2 runs/2025-11-15_run1 inspections 2
#
# Assumptions:
#   - scripts/phone_import.sh exists and is executable
#   - scripts/mov_exif.sh exists and is executable
#   - build_any.sh (or build_any_v2.sh) is available inside scripts/ and
#     is callable as:
#       ./build_any.sh <project> <doc_num>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PHONE_IMPORT="$SCRIPT_DIR/phone_import.sh"
MOV_EXIF="$SCRIPT_DIR/mov_exif.sh"

find_build_any() {
  local candidates=(
    "$SCRIPT_DIR/build_any.sh"
    "$SCRIPT_DIR/build_any_v2.sh"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

if ! BUILD_ANY="$(find_build_any)"; then
  cat >&2 <<'EOF'
Error: Could not find an executable build_any.sh (or build_any_v2.sh).
Expected to locate it inside the scripts/ directory.
EOF
  exit 1
fi

if [[ $# -lt 4 ]]; then
  cat >&2 <<EOF
Usage: $(basename "$0") <source_dir> <run_dir> <project> <doc_num>

Example:
  $(basename "$0") images/exhibit2 runs/2025-11-15_run1 permits 14
EOF
  exit 1
fi

SOURCE_DIR="$1"
RUN_DIR="$2"
PROJECT="$3"
DOC_NUM="$4"

mkdir -p "$RUN_DIR"

echo "[prep_and_build] Source dir:   $SOURCE_DIR"
echo "[prep_and_build] Run dir:      $RUN_DIR"
echo "[prep_and_build] Project/doc:  $PROJECT $DOC_NUM"
echo

# 1) Run JPG still pipeline (prepper #1)
bash "$PHONE_IMPORT" --resize 1200 "$SOURCE_DIR" "$RUN_DIR"

# 2) Run MOV metadata extraction (prepper #2)
LOG_DIR="$RUN_DIR/_logs"
mkdir -p "$LOG_DIR"
bash "$MOV_EXIF" "$RUN_DIR/working" "$LOG_DIR/video_summary.tsv"

# 3) Update stable symlink: runs/current -> this run
cd "$REPO_ROOT"
mkdir -p runs
ln -sfn "$(realpath "$RUN_DIR")" runs/current
echo "[prep_and_build] Updated symlink: runs/current -> $RUN_DIR"

# 4) Call the finisher to build the PDF
echo "[prep_and_build] Calling finisher: $BUILD_ANY $PROJECT $DOC_NUM"
bash "$BUILD_ANY" "$PROJECT" "$DOC_NUM"

echo
echo "=========================================================="
echo "Prep and build complete."
echo "  Run directory:      $RUN_DIR"
echo "  Stable run symlink: $REPO_ROOT/runs/current"
echo "  JPGs:               $RUN_DIR/time_sorted, $RUN_DIR/resized"
echo "  MOV metadata:       $RUN_DIR/_logs/video_summary.tsv"
echo "  PDF built via:      $BUILD_ANY $PROJECT $DOC_NUM"
echo "=========================================================="
