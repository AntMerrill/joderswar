# Joderswar — Codex Exhibit Factory

This repository has been repurposed into a Markdown → PDF exhibit generator.

**Structure**
- tpl/exhibit.md.tpl — master exhibit template  
- scripts/new_exhibit.sh — generate new exhibit markdown  
- scripts/exif2table.sh — append EXIF provenance tables  
- scripts/build_any.sh — build full & compressed PDFs (Pandoc + Ghostscript)

Legacy Python code lives in `attic/`.
