#!/usr/bin/env bash
set -euo pipefail

# Main EXIF / autorotate / rename pipeline
#
# Usage:
#   phone_import.sh [--resize N] [--no-date-tree] [--redact] <source_dir> <run_dir>
#
# Examples:
#   phone_import.sh /media/hogan/iPhoneDCIM runs/2025-11-09_run1
#   phone_import.sh --resize 1200 /media/hogan/iPhoneDCIM runs/2025-11-09_run1
#   phone_import.sh --resize 1200 --redact /media/hogan/iPhoneDCIM runs/2025-11-09_run1
#
# This script will create (inside <run_dir>):
#   originals/, working/, time_sorted/, date_tree/ (optional),
#   resized/ (optional), redacted/ (optional), _logs/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load helpers if present; fall back if not.
if [[ -f "$SCRIPT_DIR/helpers.sh" ]]; then
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/helpers.sh"
else
  log() { printf "[%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$*" >&2; }
  die() { log "ERROR: $*"; exit 1; }
fi

RESIZE_MAX=""     # e.g. 1200 → create resized copies
DO_DATE_TREE=1    # 1 = build date_tree; 0 = skip
DO_REDACT=0       # 1 = create redacted (EXIF-stripped) copies

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [--resize N] [--no-date-tree] [--redact] <source_dir> <run_dir>

Options:
  --resize N      Resize long edge to N pixels into run_dir/resized/
  --no-date-tree  Skip building the YYYY/MM/DD date_tree
  --redact        Create EXIF-stripped copies in run_dir/redacted/

Arguments:
  source_dir      Directory containing raw phone images (e.g. DCIM copy)
  run_dir         Target run directory (e.g. runs/2025-11-09_run1)
EOF
  exit 1
}

# --- Parse options ---
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --resize)
      RESIZE_MAX="${2:-}"
      [[ -z "$RESIZE_MAX" ]] && die "--resize requires a numeric argument"
      shift 2
      ;;
    --no-date-tree)
      DO_DATE_TREE=0
      shift
      ;;
    --redact)
      DO_REDACT=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ "${#ARGS[@]}" -ne 2 ]]; then
  usage
fi

SOURCE_DIR="${ARGS[0]}"
RUN_DIR="${ARGS[1]}"

[[ -d "$SOURCE_DIR" ]] || die "Source dir does not exist: $SOURCE_DIR"

# Normalize RUN_DIR path and create directory skeleton.
mkdir -p "$RUN_DIR"
RUN_DIR="$(cd "$RUN_DIR" && pwd)"

ORIG_DIR="$RUN_DIR/originals"
WORK_DIR="$RUN_DIR/working"
TIME_SORTED_DIR="$RUN_DIR/time_sorted"
DATE_TREE_DIR="$RUN_DIR/date_tree"
RESIZED_DIR="$RUN_DIR/resized"
REDACTED_DIR="$RUN_DIR/redacted"
LOG_DIR="$RUN_DIR/_logs"

mkdir -p "$ORIG_DIR" "$WORK_DIR" "$TIME_SORTED_DIR" "$LOG_DIR"
[[ "$DO_DATE_TREE" -eq 1 ]] && mkdir -p "$DATE_TREE_DIR"
[[ -n "$RESIZE_MAX" ]] && mkdir -p "$RESIZED_DIR"
[[ "$DO_REDACT" -eq 1 ]] && mkdir -p "$REDACTED_DIR"

log "Run directory: $RUN_DIR"
log "Source directory: $SOURCE_DIR"

# --- Dependency checks ---
for cmd in rsync exiftool exiftran find xargs; do
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done

if [[ -n "$RESIZE_MAX" ]]; then
  if ! command -v convert >/dev/null 2>&1; then
    log "WARNING: ImageMagick 'convert' not found; disabling resize."
    RESIZE_MAX=""
  fi
fi

# --- Step 1: Copy originals ---
log "Step 1: Copying originals from $SOURCE_DIR to $ORIG_DIR"
rsync -av --progress "$SOURCE_DIR"/ "$ORIG_DIR"/

# --- Step 2: Create working copies ---
log "Step 2: Creating working copies in $WORK_DIR"
rsync -av "$ORIG_DIR"/ "$WORK_DIR"/

# --- Step 3: EXIF summary & orientation log (before) ---
log "Step 3: Logging EXIF summary and orientation (before autorotate)"
EXIF_SUMMARY="$LOG_DIR/exif_summary.tsv"
BEFORE_ORIENT="$LOG_DIR/before_autorot.log"

exiftool -r -if '$MIMEType eq "image/jpeg"' \
  -T -FilePath -DateTimeOriginal -Orientation -Make -Model \
  "$WORK_DIR" > "$EXIF_SUMMARY"

exiftool -r -if '$MIMEType eq "image/jpeg" and $Orientation and $Orientation ne "Horizontal (normal)"' \
  -p '$FilePath\t$Orientation' "$WORK_DIR" > "$BEFORE_ORIENT" || true

log "EXIF summary written to: $EXIF_SUMMARY"
log "Non-horizontal orientations (before) written to: $BEFORE_ORIENT"

# --- Step 4: Autorotate JPEGs with exiftran ---
log "Step 4: Autorotating JPEGs with exiftran -ai"

find "$WORK_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) -print0 \
  | xargs -0 -n 50 exiftran -ai

# --- Step 5: Orientation log (after) ---
log "Step 5: Logging orientation (after autorotate)"
AFTER_ORIENT="$LOG_DIR/after_autorot.log"

exiftool -r -if '$MIMEType eq "image/jpeg" and $Orientation and $Orientation ne "Horizontal (normal)"' \
  -p '$FilePath\t$Orientation' "$WORK_DIR" > "$AFTER_ORIENT" || true

log "Non-horizontal orientations (after) written to: $AFTER_ORIENT"

# --- Step 6: Build time_sorted (chronological renaming) ---
log "Step 6: Building time_sorted set in $TIME_SORTED_DIR"

(
  cd "$WORK_DIR"
  exiftool -m -P -ext jpg -ext jpeg -ext png \
    -if 'defined $DateTimeOriginal' \
    '-FileName<${DateTimeOriginal;DateFmt("%Y-%m-%d")}__%f.%e' \
    -o "$TIME_SORTED_DIR" .
)

# --- Step 7: Build date_tree (optional) ---
if [[ "$DO_DATE_TREE" -eq 1 ]]; then
  log "Step 7: Building date_tree set in $DATE_TREE_DIR"
  (
    cd "$WORK_DIR"
    exiftool -r -ext jpg -ext jpeg -ext png \
      -if 'defined $DateTimeOriginal' \
      -d '%Y/%m/%d/%f%-c.%%e' \
      '-FileName<${DateTimeOriginal}' \
      -o "$DATE_TREE_DIR" .
  )
else
  log "Step 7: Skipping date_tree (disabled by --no-date-tree)"
fi

# --- Step 8: Resize into resized/ (optional) ---
if [[ -n "$RESIZE_MAX" ]]; then
  log "Step 8: Creating resized images (max ${RESIZE_MAX}px) in $RESIZED_DIR"

  # preserve relative paths from time_sorted to resized
  find "$TIME_SORTED_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print0 \
    | while IFS= read -r -d '' f; do
        rel="${f#"$TIME_SORTED_DIR/"}"
        out="$RESIZED_DIR/$rel"
        mkdir -p "$(dirname "$out")"
        convert "$f" -resize "${RESIZE_MAX}x" "$out"
      done
else
  log "Step 8: Skipping resize (no --resize specified)"
fi

# --- Step 9: Create redacted EXIF-stripped copies (optional) ---
if [[ "$DO_REDACT" -eq 1 ]]; then
  log "Step 9: Creating EXIF-stripped copies in $REDACTED_DIR"
  rsync -av "$TIME_SORTED_DIR"/ "$REDACTED_DIR"/

  exiftool -overwrite_original -all= \
    -r "$REDACTED_DIR" \
    -ext jpg -ext jpeg -ext png > "$LOG_DIR/redact_exiftool.log"

  log "Redacted copies created; EXIF stripping log: $LOG_DIR/redact_exiftool.log"
else
  log "Step 9: Skipping redacted copies (no --redact flag)"
fi

log "✅ phone_import.sh completed successfully."
log "Outputs are under: $RUN_DIR"
