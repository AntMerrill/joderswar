#!/bin/bash
set -euo pipefail
KEY="${1:-}"; NUM="${2:-}"; QUALITY="${3:-ebook}"
if [[ -z "$KEY" ]]; then echo "Usage: $0 <keyword_or_basename> [num] [quality]"; exit 1; fi
ROOT="$(pwd)"
if [[ -n "$NUM" ]]; then SRC="${KEY}${NUM}.md"; OUT="${KEY}${NUM}.pdf"; OUT_SMALL="${KEY}${NUM}_small.pdf"
else SRC="${KEY}.md"; OUT="${KEY}.pdf"; OUT_SMALL="${KEY}_small.pdf"; fi
SUBDIRS_COLON=$(find "$ROOT" -maxdepth 2 -type d -print0 | xargs -0 -I{} printf "%s:" "{}" | sed 's/:$//')
RES=".:$ROOT:$SUBDIRS_COLON"
echo "=== Building $OUT from $SRC ==="
pandoc "$SRC" -o "$OUT" --pdf-engine=xelatex -V geometry:margin=0.6in --resource-path="$RES"
GS_COMMON="-sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dDetectDuplicateImages=true -dCompressFonts=true -dNOPAUSE -dQUIET -dBATCH"
gs $GS_COMMON "-dPDFSETTINGS=/$QUALITY" -sOutputFile="$OUT_SMALL" "$OUT" || true
echo "✅ Done."
