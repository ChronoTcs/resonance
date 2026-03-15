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
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent          # = resonance_app/
DOWNLOADER_SCRIPT = SCRIPT_DIR / "resonance_downloader.py"
OUTPUT_DIR = SCRIPT_DIR / "dist"


def build():
    if not DOWNLOADER_SCRIPT.exists():
        print(f"ERROR: {DOWNLOADER_SCRIPT} not found.")
        sys.exit(1)

    print("=" * 60)
    print("  Building resonance_downloader.exe with PyInstaller")
    print("=" * 60)
    print(f"Source : {DOWNLOADER_SCRIPT}")
    print(f"Output : {OUTPUT_DIR / 'resonance_downloader.exe'}")
    print()

    cmd = [
        sys.executable, "-m", "PyInstaller",
        # Single-file executable — no extra folder, just one .exe
        "--onefile",
        "--noupx",               # Skip UPX compression (faster build, avoids AV flags)
        "--console",             # Keep console for JSON stdout/stdin communication
        "--clean",               # Remove previous build cache
        "--noconfirm",           # Overwrite dist/ without asking
        f"--distpath={OUTPUT_DIR}",
        f"--workpath={SCRIPT_DIR / 'build_tmp'}",
        f"--specpath={SCRIPT_DIR }",
        "--name=resonance_downloader",
        # Hidden imports that PyInstaller may miss for yt-dlp
        # "--hidden-import=yt_dlp.extractor",
        # "--hidden-import=yt_dlp.postprocessor",
        "--collect-all=yt_dlp",
        "--collect-all=mutagen",
        "--hidden-import=requests",
        "--hidden-import=urllib3",
        "--hidden-import=charset_normalizer",
        str(DOWNLOADER_SCRIPT),
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
