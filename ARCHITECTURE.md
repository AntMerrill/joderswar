joderswar/
├── scripts/
│   ├── phone_import.sh        # JPG prepper
│   ├── mov_exif.sh            # MOV prepper
│   ├── prep_and_build.sh      # ONE command to run everything
│   ├── build_any.sh           # Your PDF finisher
│   └── helpers.sh
│
├── templates/
│   ├── exhibit.md.tpl
│   ├── statement.md.tpl
│   └── coverpage.md.tpl
│
├── images/                    # You drop raw material here manually
│   ├── exhibit1/
│   ├── exhibit2/
│   └── hopper/                # optional “dump everything here” folder
│
├── runs/                      # auto-generated; all ignored by git
│   ├── current -> 2025-11-15_run1/
│   ├── 2025-11-14_run1/
│   ├── 2025-11-15_run1/
│   └── ...
│
├── exhibits/                  # your .md files, curated text
│   ├── permits14.md
│   ├── inspections2.md
│   ├── false_report.md
│   └── ...
│
├── pdf/                       # final output PDFs (optional tracked)
│   ├── permits14.pdf
│   ├── inspections2.pdf
│   └── ...
│
├── ARCHITECTURE.md
├── WORKFLOW.md
├── README.md
└── .gitignore

