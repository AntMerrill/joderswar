# Joderswar — Codex Exhibit Factory

This repository has been repurposed into a Markdown → PDF exhibit generator.

**Structure**
- tpl/exhibit.md.tpl — master exhibit template  
- scripts/new_exhibit.sh — generate new exhibit markdown  
- scripts/exif2table.sh — append EXIF provenance tables or write them to Markdown files
- scripts/build_any.sh — build full & compressed PDFs (Pandoc + Ghostscript)

Legacy Python code lives in `attic/`.

## Exporting EXIF data to Markdown

Use `scripts/exif2table.sh` to capture EXIF metadata from one or more
image files. The script prints a ready-to-paste Markdown table to
stdout. Pass `-o output.md` to write the table directly to a Markdown
file:

```bash
scripts/exif2table.sh -o provenance.md /path/to/images/*.jpg
```

This will create `provenance.md` containing the "EXIF-Verified
Provenance" section that can be inserted into an exhibit document.
