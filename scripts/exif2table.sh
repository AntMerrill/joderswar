#!/bin/bash
set -euo pipefail
echo -e "\n## EXIF-Verified Provenance\n"
echo "| Image | Date/Time | Coordinates | Altitude | Device | Notes |"
echo "|:--|:--|:--|:--|:--|:--|"
for img in "$@"; do
  dt=$(exiftool -DateTimeOriginal -S -s "$img" | awk '{print $2" "$3}' | sed 's/:/-/; s/:/-/')
  lat=$(exiftool -GPSLatitude -S -s "$img"); lon=$(exiftool -GPSLongitude -S -s "$img")
  alt=$(exiftool -GPSAltitude -S -s "$img" | sed 's/ m Above Sea Level/m ASL/')
  dev="$(exiftool -Make -S -s "$img") $(exiftool -Model -S -s "$img")"; base=$(basename "$img")
  echo "| **$base** | ${dt:-N/A} | ${lat:-N/A}, ${lon:-N/A} | ${alt:-N/A} | ${dev:-N/A} |  |"
done
