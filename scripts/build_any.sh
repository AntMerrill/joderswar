#!/usr/bin/env bash
set -euo pipefail

# build_any.sh  (joderswar version with pdf/ + small PDF)
#
# Usage:
#   build_any.sh <project> <doc_basename>
#
# Examples:
#   build_any.sh markdown inspections5
#   build_any.sh exhibits permits14
#
# <project> is a folder under the repo root (e.g. markdown, exhibits, tpl)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ $# -ne 2 ]]; then
  echo "Usage: $(basename "$0") <project> <doc_basename>" >&2
  exit 1
fi

PROJECT="${1%/}"        # strip trailing slash if user passes 'markdown/'
DOC_BASENAME="$2"

SRC_DIR="$REPO_ROOT/$PROJECT"
SRC_MD="$SRC_DIR/$DOC_BASENAME.md"

# All PDFs now go to repo_root/pdf
OUT_DIR="$REPO_ROOT/pdf"
mkdir -p "$OUT_DIR"

OUT_PDF="$OUT_DIR/$DOC_BASENAME.pdf"
SMALL_PDF="$OUT_DIR/${DOC_BASENAME}_small.pdf"

echo "[build_any] Project dir: $SRC_DIR"
echo "[build_any] Source file: $SRC_MD"
echo "[build_any] Output PDF (full):  $OUT_PDF"
echo "[build_any] Output PDF (small): $SMALL_PDF"

if [[ ! -f "$SRC_MD" ]]; then
  echo "ERROR: Source markdown not found: $SRC_MD" >&2
  exit 1
fi

# Resource paths:
#  .                         → repo root
#  $SRC_DIR                  → project folder (markdown/, exhibits/, etc.)
#  $REPO_ROOT/images         → raw images
#  $REPO_ROOT/runs           → per-run processed images
#  $REPO_ROOT/runs/current   → symlink to latest run (if you use it)
RESOURCE_PATH=".:$SRC_DIR:$REPO_ROOT/images:$REPO_ROOT/runs:$REPO_ROOT/runs/current"

# 1) Build the full-quality PDF with pandoc
pandoc "$SRC_MD" \
  -o "$OUT_PDF" \
  --resource-path="$RESOURCE_PATH"

echo "[build_any] ✅ Full PDF written to: $OUT_PDF"

# 2) If Ghostscript is available, make a small/SMS version
if command -v gs >/dev/null 2>&1; then
  echo "[build_any] Creating small (SMS) PDF via Ghostscript..."
  gs \
    -sDEVICE=pdfwrite \
    -dCompatibilityLevel=1.4 \
    -dPDFSETTINGS=/screen \
    -dNOPAUSE -dQUIET -dBATCH \
    -sOutputFile="$SMALL_PDF" \
    "$OUT_PDF"

  echo "[build_any] ✅ Small PDF written to: $SMALL_PDF"
else
  echo "[build_any] ⚠️ Ghostscript (gs) not found; skipping small-PDF generation."
  echo "           Install it with:  sudo apt-get install ghostscript"
fi

