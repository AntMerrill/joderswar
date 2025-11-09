#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: exif2table.sh [-o OUTPUT.md] IMAGE [IMAGE...]

Generate a Markdown table of EXIF metadata for the provided IMAGE files.

Options:
  -o, --output FILE   Write the Markdown table to FILE instead of stdout.
  -h, --help          Show this help message.
EOF
}

output=""
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --output" >&2; usage >&2; exit 1; }
      output="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  args+=("$@")
fi

if [[ ${#args[@]} -eq 0 ]]; then
  echo "No input images provided." >&2
  usage >&2
  exit 1
fi

if [[ -n "$output" ]]; then
  outdir=$(dirname "$output")
  mkdir -p "$outdir"
  exec >"$output"
fi

echo -e "\n## EXIF-Verified Provenance\n"
echo "| Image | Date/Time | Coordinates | Altitude | Device | Notes |"
echo "|:--|:--|:--|:--|:--|:--|"
for img in "${args[@]}"; do
  dt=$(exiftool -DateTimeOriginal -S -s "$img" | awk '{print $2" "$3}' | sed 's/:/-/; s/:/-/')
  lat=$(exiftool -GPSLatitude -S -s "$img"); lon=$(exiftool -GPSLongitude -S -s "$img")
  alt=$(exiftool -GPSAltitude -S -s "$img" | sed 's/ m Above Sea Level/m ASL/')
  dev="$(exiftool -Make -S -s "$img") $(exiftool -Model -S -s "$img")"; base=$(basename "$img")
  echo "| **$base** | ${dt:-N/A} | ${lat:-N/A}, ${lon:-N/A} | ${alt:-N/A} | ${dev:-N/A} |  |"
done

if [[ -n "$output" ]]; then
  echo "Markdown EXIF table written to $output" >&2
fi
