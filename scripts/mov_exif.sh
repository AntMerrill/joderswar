#!/usr/bin/env bash
set -euo pipefail

# mov_exif.sh
# Extract EXIF / QuickTime metadata for MOV/MP4/M4V files into a TSV.
#
# Usage:
#   mov_exif.sh <source_dir> [output_tsv]
#
# Examples:
#   mov_exif.sh images/exhibit2
#   mov_exif.sh runs/2025-11-14_run3/working runs/2025-11-14_run3/_logs/video_summary.tsv
#
# If output_tsv is not given, a default file named
#   video_exif_YYYYmmdd_HHMMSS.tsv
# will be created in the source_dir.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Load helpers.sh if available ---
load_helpers() {
  local candidates=(
    "$SCRIPT_DIR/helpers.sh"
    "$SCRIPT_DIR/../helpers.sh"
    "$(pwd)/helpers.sh"
  )
  for h in "${candidates[@]}"; do
    if [[ -f "$h" ]]; then
      # shellcheck source=/dev/null
      . "$h"
      return 0
    fi
  done

  # Fallback logging if helpers.sh not found
  log() { printf "[%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$*" >&2; }
  die() { log "ERROR: $*"; exit 1; }

  log "WARNING: helpers.sh not found in: ${candidates[*]} — using built-in log/die."
}

load_helpers

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") <source_dir> [output_tsv]

Extract EXIF / QuickTime metadata for MOV/MP4/M4V files into a TSV.

Arguments:
  source_dir   Directory to scan recursively for video files
  output_tsv   Optional path for TSV output. If omitted, a file named
               video_exif_YYYYmmdd_HHMMSS.tsv will be created in source_dir.
EOF
  exit 1
}

SOURCE_DIR="${1:-}"
OUTPUT_TSV="${2:-}"

if [[ -z "$SOURCE_DIR" ]]; then
  usage
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  die "Source directory does not exist: $SOURCE_DIR"
fi

# Default output file if not specified
if [[ -z "$OUTPUT_TSV" ]]; then
  TS="$(date +"%Y%m%d_%H%M%S")"
  OUTPUT_TSV="$SOURCE_DIR/video_exif_${TS}.tsv"
fi

command -v exiftool >/dev/null 2>&1 || die "exiftool not found in PATH"

SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
OUTPUT_TSV="$(cd "$(dirname "$OUTPUT_TSV")" && pwd)/$(basename "$OUTPUT_TSV")"

log "Scanning directory for videos: $SOURCE_DIR"
log "Output TSV: $OUTPUT_TSV"

# Check if there are any video files before calling exiftool
HAS_VIDEOS=$(find "$SOURCE_DIR" -type f \( -iname '*.mov' -o -iname '*.mp4' -o -iname '*.m4v' \) | head -n 1 || true)

if [[ -z "$HAS_VIDEOS" ]]; then
  log "No MOV/MP4/M4V files found under: $SOURCE_DIR"
  # Create an empty file with header row so it's still usable
  cat > "$OUTPUT_TSV" <<EOF
FilePath	FileName	FileType	MIMEType	CreateDate	MediaCreateDate	ModifyDate	Duration	ImageSize	Rotation	GPSLatitude	GPSLongitude	Make	Model	Software	HandlerType	CompressorID
EOF
  log "Empty TSV with header written to: $OUTPUT_TSV"
  exit 0
fi

log "Video files detected — extracting metadata with exiftool"

# Write header explicitly so tools don't choke if exiftool changes behaviour
cat > "$OUTPUT_TSV" <<EOF
FilePath	FileName	FileType	MIMEType	CreateDate	MediaCreateDate	ModifyDate	Duration	ImageSize	Rotation	GPSLatitude	GPSLongitude	Make	Model	Software	HandlerType	CompressorID
EOF

# Append exiftool output
exiftool -m -r \
  -ext mov -ext mp4 -ext m4v \
  -T \
  -FilePath \
  -FileName \
  -FileType \
  -MIMEType \
  -CreateDate \
  -MediaCreateDate \
  -ModifyDate \
  -Duration \
  -ImageSize \
  -Rotation \
  -GPSLatitude \
  -GPSLongitude \
  -Make \
  -Model \
  -Software \
  -HandlerType \
  -CompressorID \
  "$SOURCE_DIR" >> "$OUTPUT_TSV" || true

log "✅ Video metadata written to: $OUTPUT_TSV"
