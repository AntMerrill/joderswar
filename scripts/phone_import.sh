#!/usr/bin/env bash
set -euo pipefail

# phone_import.sh
# Prepper for JPG + PNG images:
#   - copy originals
#   - autorotate JPGs
#   - EXIF logs
#   - resized versions
#   - time_sorted + date_tree (non-fatal if already exists)
#
# Usage:
#   phone_import.sh [--resize N] <source_dir> <run_dir>

# ------------- ARGUMENT PARSING -------------------

RESIZE_MAX=""
if [[ "${1:-}" == "--resize" ]]; then
    RESIZE_MAX="$2"
    shift 2
fi

if [[ $# -ne 2 ]]; then
    echo "Usage: phone_import.sh [--resize N] <source_dir> <run_dir>" >&2
    exit 1
fi

SRC="$1"
RUN="$2"

timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

log() {
    echo "[$(timestamp)] $*"
}

# ------------- DIRECTORY SETUP --------------------

ORIG_DIR="$RUN/originals"
WORK_DIR="$RUN/working"
LOG_DIR="$RUN/_logs"
TIME_SORTED_DIR="$RUN/time_sorted"
DATE_TREE_DIR="$RUN/date_tree"
RESIZED_DIR="$RUN/resized"

mkdir -p "$ORIG_DIR" "$WORK_DIR" "$LOG_DIR" "$TIME_SORTED_DIR" "$DATE_TREE_DIR" "$RESIZED_DIR"

log "Run directory: $RUN"
log "Source directory: $SRC"

# ------------- STEP 1: COPY ORIGINALS --------------

log "Step 1: Copying originals from $SRC to $ORIG_DIR"
rsync -av --exclude=".*" "$SRC/" "$ORIG_DIR/" >/dev/null

# ------------- STEP 2: COPY WORKING ----------------

log "Step 2: Creating working copies in $WORK_DIR"
rsync -av --exclude=".*" "$SRC/" "$WORK_DIR/" >/dev/null

# ------------- STEP 3: EXIF LOGS -------------------

log "Step 3: Logging EXIF summary and orientation (before autorotate)"
find "$WORK_DIR" -type f -iname "*.jpg" -o -iname "*.jpeg" | \
  xargs -r exiftool -Orientation -T > "$LOG_DIR/exif_summary.tsv" 2>/dev/null || true

exiftool -r -if '$MIMEType eq "image/jpeg" and $Orientation and $Orientation ne "Horizontal (normal)"' \
  -p '$FilePath\t$Orientation' "$WORK_DIR" \
  > "$LOG_DIR/before_autorot.log" || true

log "EXIF summary written to: $LOG_DIR/exif_summary.tsv"
log "Non-horizontal orientations (before) written to: $LOG_DIR/before_autorot.log"

# ------------- STEP 4: AUTOROTATE -------------------

log "Step 4: Autorotating JPEGs with exiftran -ai"

find "$WORK_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \) -print0 \
  | xargs -0 -r -n 1 exiftran -ai || true

# ------------- STEP 5: ORIENTATION AFTER ------------

log "Step 5: Logging orientation (after autorotate)"
exiftool -r -if '$MIMEType eq "image/jpeg" and $Orientation and $Orientation ne "Horizontal (normal)"' \
  -p '$FilePath\t$Orientation' "$WORK_DIR" \
  > "$LOG_DIR/after_autorot.log" || true

log "Non-horizontal orientations (after) written to: $LOG_DIR/after_autorot.log"

# ------------- STEP 6: TIME_SORTED ------------------

log "Step 6: Building time_sorted set in $TIME_SORTED_DIR"

(
  cd "$WORK_DIR"
  exiftool -m -P -ext jpg -ext jpeg -ext png \
      -if 'defined $DateTimeOriginal' \
      '-FileName<${DateTimeOriginal;DateFmt("%Y-%m-%d")}__%f.%e' \
      -o "$TIME_SORTED_DIR" . \
      || true   # <-- NON-FATAL IF FILE EXISTS
)

# ------------- STEP 7: DATE_TREE --------------------

log "Step 7: Building date_tree set in $DATE_TREE_DIR"

(
  cd "$WORK_DIR"
  exiftool -m -P -ext jpg -ext jpeg -ext png \
      -if 'defined $DateTimeOriginal' \
      '-Directory<${DateTimeOriginal;DateFmt("%Y/%m/%d")}' \
      -o "$DATE_TREE_DIR" . \
      || true   # <-- NON-FATAL IF FILE EXISTS
)

# ------------- STEP 8: RESIZED IMAGES --------------

if [[ -n "$RESIZE_MAX" ]]; then
    log "Step 8: Creating resized images (max ${RESIZE_MAX}px) in $RESIZED_DIR"
    mogrify -path "$RESIZED_DIR" -resize "${RESIZE_MAX}x" "$WORK_DIR"/*.JPG "$WORK_DIR"/*.JPEG "$WORK_DIR"/*.PNG || true
else
    log "Step 8: Skipping resized images (no --resize flag)"
fi

# ------------- STEP 9: REDACT PLACEHOLDER ----------

log "Step 9: Skipping redacted copies (no --redact flag)"

log "✅ phone_import.sh completed successfully."
log "Outputs are under: $RUN"

