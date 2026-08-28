#!/usr/bin/env python3
"""
build_downloader.py
===================
Compiles resonance_downloader.py into a self-contained Windows .exe using PyInstaller.

Run this script ONCE before building the Flutter release:
    conda run -n ml_ds_stable python build_downloader.py
    -- OR --
    python build_downloader.py   (if PyInstaller is globally available)

Output: downloader/dist/resonance_downloader.exe
The Flutter CMakeLists.txt then copies this .exe next to resonance_app.exe automatically.

Prerequisites:
    pip install pyinstaller yt-dlp requests
"""

import subprocess
import sys
import os
import re
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent          # = python_engine/
DOWNLOADER_SCRIPT = SCRIPT_DIR / "resonance_downloader.py"
OUTPUT_DIR = SCRIPT_DIR / "dist"


def generate_version_info():
    """Generates version_info.txt dynamically from root pubspec.yaml."""
    pubspec_path = SCRIPT_DIR.parent / "pubspec.yaml"
    version_str = "0.1.7-beta"
    build_num = 10

    if pubspec_path.exists():
        content = pubspec_path.read_text(encoding="utf-8")
        match = re.search(r"version:\s*([^\s]+)", content)
        if match:
            raw_version = match.group(1).strip()
            if "+" in raw_version:
                version_str, b_str = raw_version.split("+", 1)
                build_num = int(b_str) if b_str.isdigit() else 1
            else:
                version_str = raw_version
                build_num = 1

    clean_base = re.sub(r"^[vV]", "", version_str).split("-")[0]
    parts = [int(p) if p.isdigit() else 0 for p in clean_base.split(".")]
    while len(parts) < 3:
        parts.append(0)
    major, minor, patch = parts[:3]

    full_product_version = f"{version_str}+{build_num}"
    file_version_tuple = f"({major}, {minor}, {patch}, {build_num})"
    file_version_str = f"{major}.{minor}.{patch}.{build_num}"

    version_info_content = f'''VSVersionInfo(
  ffi=FixedFileInfo(
    filevers={file_version_tuple},
    prodvers={file_version_tuple},
    mask=0x3f,
    flags=0x0,
    OS=0x40004,
    fileType=0x1,
    subtype=0x0,
    date=(0, 0)
  ),
  kids=[
    StringFileInfo([
      StringTable(
        u'040904B0',
        [StringStruct(u'CompanyName', u'ChronoTech'),
        StringStruct(u'FileDescription', u'Resonance Audio Stream Resolver'),
        StringStruct(u'FileVersion', u'{file_version_str}'),
        StringStruct(u'InternalName', u'resonance_downloader'),
        StringStruct(u'LegalCopyright', u'Copyright (C) 2026 ChronoTech'),
        StringStruct(u'OriginalFilename', u'resonance_downloader.exe'),
        StringStruct(u'ProductName', u'Resonance'),
        StringStruct(u'ProductVersion', u'{full_product_version}')])
    ]),
    VarFileInfo([VarStruct(u'Translation', [0x0409, 1200])])
  ]
)
'''
    (SCRIPT_DIR / "version_info.txt").write_text(version_info_content, encoding="utf-8")
    print(f"  Generated version_info.txt ({full_product_version} -> {file_version_str})")


def build():
    if not DOWNLOADER_SCRIPT.exists():
        print(f"ERROR: {DOWNLOADER_SCRIPT} not found.")
        sys.exit(1)

    generate_version_info()

    print("=" * 60)
    print("  Building resonance_downloader.exe with PyInstaller")
    print("=" * 60)
    print(f"Source : {DOWNLOADER_SCRIPT}")
    print(f"Output : {OUTPUT_DIR / 'resonance_downloader.exe'}")
    print()

    # Use the .spec file so version_file and icon are always applied
    # (inline --version-file and --icon args would be ignored if spec already exists)
    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--clean",      # Remove previous build cache
        "--noconfirm",  # Overwrite dist/ without asking
        f"--distpath={OUTPUT_DIR}",
        f"--workpath={SCRIPT_DIR / 'build_tmp'}",
        str(SCRIPT_DIR / "resonance_downloader.spec"),
    ]

    result = subprocess.run(cmd, cwd=SCRIPT_DIR)

    if result.returncode == 0:
        exe_path = OUTPUT_DIR / "resonance_downloader.exe"
        size_mb = exe_path.stat().st_size / 1_048_576 if exe_path.exists() else 0
        print()
        print("=" * 60)
        print(f"  SUCCESS! resonance_downloader.exe ({size_mb:.1f} MB)")
        print(f"  Location: {exe_path}")
        print()
        print("  Next step: run  flutter build windows  to bundle it.")
        print("=" * 60)
    else:
        print()
        print("ERROR: PyInstaller failed. Check output above.")
        print("Install PyInstaller with:  pip install pyinstaller")
        sys.exit(1)


if __name__ == "__main__":
    build()
