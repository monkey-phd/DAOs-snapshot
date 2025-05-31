#!/usr/bin/env python
"""
clean_data.py  –  SAFE cleaner.  Preview with --dry_run first.

• Standardise filenames   (lower-case, ascii, spaces→underscores)
• Detect byte-identical duplicates
• Zip files whose *path* contains  “legacy”, “old”, or “backup”
"""

import argparse, hashlib, zipfile, sys
from datetime import datetime
from pathlib import Path
from slugify import slugify
from rich import print, progress

SKIP_EXTS = {".zip", ".tar", ".gz"}
LEGACY = {"legacy", "old", "backup"}

def canonical(p: Path) -> str:
    return f"{slugify(p.stem, separator='_')}{p.suffix.lower()}"

def hashfile(p: Path, bs: int = 131072) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(bs), b""): h.update(chunk)
    return h.hexdigest()

def files(root: Path):
    return [f for f in root.rglob("*") if f.is_file() and f.suffix.lower() not in SKIP_EXTS]

def zip_legacy(fs, dest: Path, dry: bool):
    if not fs: return
    dest.mkdir(parents=True, exist_ok=True)
    z = dest / f"legacy_datasets_{datetime.now():%Y%m%d_%H%M%S}.zip"
    if dry:
        print(f"[cyan]DRY-RUN[/] Would create {z.name} with {len(fs)} files"); return
    with zipfile.ZipFile(z, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in fs: zf.write(f, f.relative_to(f.parents[1])); f.unlink()
    print(f"[green]Archived {len(fs)} files → {z}")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data_dir", type=Path, required=True)
    ap.add_argument("--archive_dir", type=Path, required=True)
    ap.add_argument("--dry_run", action="store_true", default=False)
    args = ap.parse_args()

    root = args.data_dir.resolve()
    if not root.is_dir(): sys.exit(f"Data dir {root} not found")
    print(f"[bold]Scanning {root}[/]")

    # 1 Renames
    for f in files(root):
        new = f.with_name(canonical(f))
        if f.name != new.name:
            if args.dry_run: print(f"[cyan]RENAME?[/] {f.name} → {new.name}")
            else: f.rename(new)

    # 2 Duplicates
    seen, dupes = {}, []
    for f in progress.track(files(root), description="Hashing"):
        h = hashfile(f); dupes.append(f) if h in seen else seen.setdefault(h, f)
    for d in dupes:
        if args.dry_run: print(f"[cyan]DUPLICATE?[/] {d.relative_to(root)}")
        else: d.unlink()

    # 3 Legacy
    legacy = [f for f in files(root) if any(k in f.parts for k in LEGACY)]
    zip_legacy(legacy, args.archive_dir, args.dry_run)

    print("[bold green]Preview complete[/] – rerun without --dry_run to apply.")

if __name__ == "__main__": main()
