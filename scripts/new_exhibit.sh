#!/bin/bash
set -euo pipefail
TITLE="${1:-Exhibit}"; AUTHOR="${2:-Merrill Jensen}"; DATESTR="${3:-November 2025}"; SLUG="${4:-exhibit}"
export VAR_TITLE="$TITLE"; export VAR_AUTHOR="$AUTHOR"; export VAR_DATE="$DATESTR"; export VAR_SLUG="$SLUG"
envsubst < "tpl/exhibit.md.tpl"
