#!/usr/bin/env bash
# ==============================================================================
# package_deb.sh
# Creates a standalone Debian package (.deb) for Resonance
# Equivalent to Windows Inno Setup installer.
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BUNDLE_DIR="${1:-$PROJECT_ROOT/build/linux/x64/release/bundle}"
OUTPUT_DIR="${2:-$PROJECT_ROOT/Output}"

if [ ! -d "$BUNDLE_DIR" ]; then
  echo "Error: Release bundle not found at: $BUNDLE_DIR"
  echo "Run 'flutter build linux --release' first."
  exit 1
fi

# Extract version from pubspec.yaml
PUBSPEC="$PROJECT_ROOT/pubspec.yaml"
RAW_VER=$(grep -m 1 '^version:' "$PUBSPEC" | awk '{print $2}')
BASE_VER=$(echo "$RAW_VER" | cut -d'+' -f1 | sed 's/-beta//g')
BUILD_NUM=$(echo "$RAW_VER" | cut -d'+' -f2)
if [ -z "$BUILD_NUM" ]; then BUILD_NUM="1"; fi
DEB_VERSION="${BASE_VER}-${BUILD_NUM}"

mkdir -p "$OUTPUT_DIR"
DEB_FILE="$OUTPUT_DIR/Resonance-v${RAW_VER}-Linux-x64.deb"

echo "=========================================================="
echo " Packaging Resonance Debian Package (.deb)"
echo " Version : $DEB_VERSION"
echo " Bundle  : $BUNDLE_DIR"
echo " Output  : $DEB_FILE"
echo "=========================================================="

STAGING_DIR="$PROJECT_ROOT/build/deb_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/DEBIAN"
mkdir -p "$STAGING_DIR/opt/resonance"
mkdir -p "$STAGING_DIR/usr/bin"
mkdir -p "$STAGING_DIR/usr/share/applications"
mkdir -p "$STAGING_DIR/usr/share/icons/hicolor/256x256/apps"

# 1. Copy Application Bundle to /opt/resonance
echo "  -> Copying application bundle..."
cp -r "$BUNDLE_DIR/"* "$STAGING_DIR/opt/resonance/"

# Ensure executable bits
chmod 755 "$STAGING_DIR/opt/resonance/resonance_app"
if [ -f "$STAGING_DIR/opt/resonance/resonance_downloader" ]; then
  chmod 755 "$STAGING_DIR/opt/resonance/resonance_downloader"
fi

# 2. Create /usr/bin/resonance wrapper launcher
cat << 'EOF' > "$STAGING_DIR/usr/bin/resonance"
#!/bin/sh
exec /opt/resonance/resonance_app "$@"
EOF
chmod 755 "$STAGING_DIR/usr/bin/resonance"

# 3. Create Desktop Launcher (.desktop)
cat << EOF > "$STAGING_DIR/usr/share/applications/resonance.desktop"
[Desktop Entry]
Name=Resonance
Comment=Modern Music Streaming & Downloader
Exec=/opt/resonance/resonance_app %U
Icon=resonance
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Player;Music;
StartupWMClass=resonance_app
Keywords=music;sound;streaming;audio;player;
EOF
chmod 644 "$STAGING_DIR/usr/share/applications/resonance.desktop"

# 4. Copy Application Icon
ICON_SRC="$PROJECT_ROOT/assets/icons/app_icon.png"
if [ -f "$ICON_SRC" ]; then
  cp "$ICON_SRC" "$STAGING_DIR/usr/share/icons/hicolor/256x256/apps/resonance.png"
  chmod 644 "$STAGING_DIR/usr/share/icons/hicolor/256x256/apps/resonance.png"
fi

# 5. Create Debian Control File
# libmpv2 is pinned per latest September 2026 standard
cat << EOF > "$STAGING_DIR/DEBIAN/control"
Package: resonance
Version: $DEB_VERSION
Section: sound
Priority: optional
Architecture: amd64
Maintainer: ChronoStudio <contact@chronostudio.dev>
Depends: libc6 (>= 2.34), libgtk-3-0 (>= 3.24.0), libmpv2
Description: Resonance Music Player
 Modern, sleek music streaming and downloading application powered by Flutter.
 Includes self-contained audio stream deciphering and downloader engine.
EOF

# 6. Build .deb with dpkg-deb
echo "  -> Building .deb package with dpkg-deb..."
dpkg-deb --build --root-owner-group "$STAGING_DIR" "$DEB_FILE"

# Clean staging directory
rm -rf "$STAGING_DIR"

SIZE_MB=$(du -m "$DEB_FILE" | cut -f1)
echo "=========================================================="
echo "  SUCCESS! Created $DEB_FILE (~${SIZE_MB} MB)"
echo "=========================================================="
