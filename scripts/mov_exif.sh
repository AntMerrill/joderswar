#!/usr/bin/env bash
set -euo pipefail

# mov_exif.sh
# Extract EXIF / QuickTime metadata for MOV/MP4/M4V files into a Markdown summary.
#
# Usage:
#   mov_exif.sh <source_dir> [output_md]
#
# Examples:
#   mov_exif.sh images/exhibit2
#   mov_exif.sh runs/2025-11-14_run3/working runs/2025-11-14_run3/_logs/video_summary.md
#
# If output_md is not given, a default file named
#   video_exif_YYYYmmdd_HHMMSS.md
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
  log() {
    printf "[%s] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$*" >&2
  }
  die() {
    log "ERROR: $*"
    exit 1
  }

  log "WARNING: helpers.sh not found in: ${candidates[*]} — using built-in log/die."
}

load_helpers

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") <source_dir> [output_md]

Extract EXIF / QuickTime metadata for MOV/MP4/M4V files into a Markdown report.

Arguments:
  source_dir   Directory to scan recursively for video files
  output_md    Optional path for Markdown output. If omitted, a file named
               video_exif_YYYYmmdd_HHMMSS.md will be created in source_dir.
EOF
  exit 1
}

SOURCE_DIR="${1:-}"
OUTPUT_MD="${2:-}"

if [[ -z "$SOURCE_DIR" ]]; then
  usage
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  die "Source directory does not exist: $SOURCE_DIR"
fi

# Default output file if not specified
if [[ -z "$OUTPUT_MD" ]]; then
  TS="$(date +"%Y%m%d_%H%M%S")"
  OUTPUT_MD="$SOURCE_DIR/video_exif_${TS}.md"
fi

command -v exiftool >/dev/null 2>&1 || die "exiftool not found in PATH"

SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
OUTPUT_MD="$(cd "$(dirname "$OUTPUT_MD")" && pwd)/$(basename "$OUTPUT_MD")"

mkdir -p "$(dirname "$OUTPUT_MD")"

log "Scanning directory for videos: $SOURCE_DIR"
log "Output Markdown: $OUTPUT_MD"

# Check if there are any video files before calling exiftool
HAS_VIDEOS=$(find "$SOURCE_DIR" -type f \( -iname '*.mov' -o -iname '*.mp4' -o -iname '*.m4v' \) | head -n 1 || true)

if [[ -z "$HAS_VIDEOS" ]]; then
  log "No MOV/MP4/M4V files found under: $SOURCE_DIR"
  cat > "$OUTPUT_MD" <<EOF
# Video Metadata Summary

_No MOV/MP4/M4V files found in \`$SOURCE_DIR\`._
EOF
  log "Empty Markdown summary written to: $OUTPUT_MD"
  exit 0
fi

log "Video files detected — extracting metadata with exiftool"

{
  echo "# Video Metadata Summary"
  echo
} > "$OUTPUT_MD"

format_date() {
  local raw="$1"
  [[ -z "$raw" ]] && { echo "N/A"; return; }
  if [[ "$raw" =~ ^([0-9-]+ [0-9:]+)([+-][0-9]{2})([0-9]{2})$ ]]; then
    printf "%s (UTC%s:%s)" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
  else
    echo "$raw"
  fi
}

human_duration() {
  local raw="$1"
  [[ -z "$raw" ]] && { echo "N/A"; return; }
  if [[ "$raw" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    awk -v v="$raw" 'BEGIN {
      if (v >= 3600) {
        h = int(v / 3600);
        m = int((v - h * 3600) / 60);
        s = int(v - h * 3600 - m * 60 + 0.5);
        printf("~%dh %dm %ds", h, m, s);
      } else if (v >= 60) {
        m = int(v / 60);
        s = int(v - m * 60 + 0.5);
        printf("~%d min %d sec", m, s);
      } else {
        printf("~%.0f seconds", v);
      }
    }'
    return
  fi
  if [[ "$raw" =~ ^([0-9]+):([0-9]{2}):([0-9]{2})(\.[0-9]+)?$ ]]; then
    local hours=${BASH_REMATCH[1]}
    local mins=${BASH_REMATCH[2]}
    local secs=${BASH_REMATCH[3]}
    local total_secs=$((10#$hours * 3600 + 10#$mins * 60 + 10#$secs))
    if (( total_secs >= 3600 )); then
      local hh=$((total_secs / 3600))
      local mm=$(((total_secs % 3600) / 60))
      local ss=$((total_secs % 60))
      printf "~%dh %dm %ds" "$hh" "$mm" "$ss"
    elif (( total_secs >= 60 )); then
      local mm=$((total_secs / 60))
      local ss=$((total_secs % 60))
      printf "~%d min %d sec" "$mm" "$ss"
    else
      printf "~%d seconds" "$total_secs"
    fi
    return
  fi
  echo "$raw"
}

format_coord() {
  local value="$1"
  local axis="$2"
  [[ -z "$value" ]] && { echo "N/A"; return; }
  [[ "$value" == "nan" || "$value" == "NaN" ]] && { echo "N/A"; return; }
  local dir
  if [[ "$value" == -* ]]; then
    value="${value#-}"
    dir=$([[ "$axis" == "lat" ]] && echo "S" || echo "W")
  else
    dir=$([[ "$axis" == "lat" ]] && echo "N" || echo "E")
  fi
  printf "%.4f° %s" "$value" "$dir"
}

escape_md() {
  local value="$1"
  [[ -z "$value" ]] && { echo "N/A"; return; }
  value=${value//$'\r'/}
  value=${value//$'\n'/<br />}
  value=${value//|/\|}
  echo "$value"
}

integrity_notes() {
  local create_raw="$1"
  local media_raw="$2"
  if [[ -z "$create_raw" || -z "$media_raw" ]]; then
    echo "Insufficient data to compare timestamps"
  elif [[ "$create_raw" == "$media_raw" ]]; then
    echo "No edits detected; matching CreateDate/MediaCreateDate"
  else
    echo "Timestamps differ (CreateDate vs MediaCreateDate); review for edits"
  fi
}

location_summary() {
  local lat="$1"
  local lon="$2"
  if [[ -z "$lat" || -z "$lon" || "$lat" == "nan" || "$lon" == "nan" || "$lat" == "NaN" || "$lon" == "NaN" ]]; then
    echo "Not available"
  else
    echo "Coordinates available (~$(format_coord "$lat" lat), $(format_coord "$lon" lon))"
  fi
}

COUNT=0

exiftool -api QuickTimeUTC -m -r -n -d '%Y-%m-%d %H:%M:%S%z' \
  -ext mov -ext mp4 -ext m4v \
  -T \
  -FilePath \
  -FileName \
  -FileType \
  -MIMEType \
  -CreateDate \
  -MediaCreateDate \
  -ModifyDate \
  -Duration# \
  -ImageSize \
  -Rotation \
  -GPSLatitude \
  -GPSLongitude \
  -Make \
  -Model \
  -Software \
  -HandlerType \
  -CompressorID \
  "$SOURCE_DIR" |
while IFS=$'\t' read -r filepath filename filetype mimetype createdate mediacreatedate modifydate duration imagesize rotation gpslat gpslon make model software handlertype compressorid; do
  [[ -z "$filepath$filename" ]] && continue
  COUNT=$((COUNT + 1))
  cat >> "$OUTPUT_MD" <<EOF
### Video Metadata — $(escape_md "${filename:-N/A}")

| Field | Value |
|--------------------|------------------------------|
| File Name | $(escape_md "${filename:-N/A}") |
| MIME Type | $(escape_md "${mimetype:-N/A}") |
| CreateDate | $(escape_md "$(format_date "$createdate")") |
| MediaCreateDate | $(escape_md "$(format_date "$mediacreatedate")") |
| ModifyDate | $(escape_md "$(format_date "$modifydate")") |
| Duration | $(escape_md "$(human_duration "$duration")") |
| Device Make | $(escape_md "${make:-N/A}") |
| Device Model | $(escape_md "${model:-N/A}") |
| GPS Latitude | $(escape_md "$(format_coord "$gpslat" lat)") |
| GPS Longitude | $(escape_md "$(format_coord "$gpslon" lon)") |
| Location | $(escape_md "$(location_summary "$gpslat" "$gpslon")") |
| Integrity Notes | $(escape_md "$(integrity_notes "$createdate" "$mediacreatedate")") |

EOF
done

if [[ "$COUNT" -eq 0 ]]; then
  echo "_No metadata rows returned by exiftool._" >> "$OUTPUT_MD"
fi

log "✅ Video metadata written to: $OUTPUT_MD"
