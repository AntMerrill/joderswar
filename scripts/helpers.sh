#!/usr/bin/env bash

# Simple logging helpers shared by other scripts.

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log() {
  # Log to stderr with timestamp
  printf "[%s] %s\n" "$(timestamp)" "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}
