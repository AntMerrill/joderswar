#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: build_any.sh <project_dir> <doc_basename> [quality]

Examples:
  build_any.sh tpl inspections1
  build_any.sh tpl timeline_master1 print
USAGE
}

PROJECT_DIR_KEY="${1:-}"
DOC_BASENAME="${2:-}"
QUALITY="${3:-ebook}"

if [[ -z "$PROJECT_DIR_KEY" || -z "$DOC_BASENAME" ]]; then
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/$PROJECT_DIR_KEY"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: Project directory '$PROJECT_DIR_KEY' not found under $REPO_ROOT" >&2
  exit 1
fi

SRC="$PROJECT_DIR/$DOC_BASENAME.md"
if [[ ! -f "$SRC" ]]; then
  echo "Error: Source markdown '$SRC' does not exist" >&2
  exit 1
fi

OUTPUT_DIR="${BUILD_OUTPUT_DIR:-$PROJECT_DIR}"
mkdir -p "$OUTPUT_DIR"
OUT="$OUTPUT_DIR/$DOC_BASENAME.pdf"
OUT_SMALL="$OUTPUT_DIR/${DOC_BASENAME}_small.pdf"

SUBDIRS_COLON=$(find "$REPO_ROOT" -maxdepth 2 -type d -print0 | xargs -0 -I{} printf "%s:" "{}" | sed 's/:$//')
RESOURCE_PATH="$REPO_ROOT:$SUBDIRS_COLON"

echo "[build_any] Project dir: $PROJECT_DIR"
echo "[build_any] Source file: $SRC"
echo "[build_any] Output PDF:  $OUT"

pandoc "$SRC" -o "$OUT" --pdf-engine=xelatex -V geometry:margin=0.6in --resource-path="$RESOURCE_PATH"

GS_COMMON=(
  -sDEVICE=pdfwrite
  -dCompatibilityLevel=1.4
  -dDetectDuplicateImages=true
  -dCompressFonts=true
  -dNOPAUSE
  -dQUIET
  -dBATCH
)

gs "${GS_COMMON[@]}" "-dPDFSETTINGS=/$QUALITY" -sOutputFile="$OUT_SMALL" "$OUT" || true
echo "[build_any] ✅ PDF written to: $OUT"
