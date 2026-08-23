#!/bin/bash
#
# setup.sh — Provision a fresh Raspberry Pi 5 for the rawsberry appliance.
#
# Assumes: Raspberry Pi OS Lite (64-bit) already flashed, SSH working,
#          network reachable. Run once on a fresh card.
#
# Usage:  ./setup.sh
#
# NOT covered by this script (must be done in Raspberry Pi Imager before
# first boot — see README): hostname, user account, SSH enable, Wi-Fi
# credentials. Those are pre-boot settings and cannot be scripted here.

set -euo pipefail

WIFI_COUNTRY="CO"
TIMEZONE="America/Bogota"
LOCALE="C.UTF-8"

# Renderer is pinned rather than installed from apt: apt gives 5.10 on the
# desktop and 5.11 here, and determinism is specified against one pinned build.
RT_VERSION="5.13"
RT_APPIMAGE="RawTherapee_${RT_VERSION}_arm64_release.AppImage"
RT_URL="https://github.com/RawTherapee/RawTherapee/releases/download/${RT_VERSION}/${RT_APPIMAGE}"
RT_SHA256="9e424633272a49bb47afe4bf065604858acf9de77c4d80e0f6557024492e2b55"
RT_PREFIX="/opt/rawtherapee-${RT_VERSION}"

echo "==> Regulatory domain (required before the Wi-Fi radio will operate)"
sudo raspi-config nonint do_wifi_country "$WIFI_COUNTRY"

echo "==> Timezone"
sudo timedatectl set-timezone "$TIMEZONE"

echo "==> Locale"
# C.UTF-8 gives POSIX numeric formatting (periods, not commas) while
# preserving UTF-8. Decimal commas would corrupt float values written
# into RawTherapee .pp3 files.
# Written to /etc/default/locale so systemd units and non-interactive
# processes inherit it — profile.d scripts would only cover login shells.
sudo update-locale LANG="$LOCALE" LC_ALL="$LOCALE"

echo "==> Package index and system upgrade"
sudo apt update
sudo apt upgrade -y

echo "==> Packages"
sudo apt install -y \
    git \
    tmux \
    curl

echo "==> RawTherapee ${RT_VERSION} (pinned)"
# Extracted rather than run through FUSE: Pi OS Lite ships no libfuse2, and an
# extracted tree removes a moving part from a path that must stay deterministic.
if [ ! -x "${RT_PREFIX}/usr/bin/rawtherapee-cli" ]; then
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    curl -fL --retry 3 -o "${tmp}/${RT_APPIMAGE}" "$RT_URL"

    # A release asset can be rebuilt and re-uploaded under the same tag, so a
    # working URL does not imply the pinned bytes. Refuse rather than install a
    # renderer that would silently break determinism downstream.
    actual="$(sha256sum "${tmp}/${RT_APPIMAGE}" | cut -d' ' -f1)"
    if [ "$actual" != "$RT_SHA256" ]; then
        echo "ERROR: checksum mismatch for ${RT_APPIMAGE}" >&2
        echo "  expected ${RT_SHA256}" >&2
        echo "  actual   ${actual}" >&2
        echo >&2
        echo "Compare the actual hash against the checksum published on the" >&2
        echo "release page: ${RT_URL%/*}" >&2
        echo >&2
        echo "  Does not match upstream either -> bad download, re-run setup.sh." >&2
        echo "  Matches upstream -> the asset was replaced. Do NOT just paste the" >&2
        echo "  new hash into RT_SHA256: different bytes mean a different renderer," >&2
        echo "  so neutral.pp3 must be regenerated and every eval number measured" >&2
        echo "  on the old build stops being comparable. Re-pin deliberately." >&2
        exit 1
    fi

    chmod +x "${tmp}/${RT_APPIMAGE}"
    ( cd "$tmp" && "./${RT_APPIMAGE}" --appimage-extract >/dev/null )
    sudo rm -rf "${RT_PREFIX}"
    sudo mv "${tmp}/squashfs-root" "${RT_PREFIX}"
fi
sudo ln -sf "${RT_PREFIX}/usr/bin/rawtherapee-cli" /usr/local/bin/rawtherapee-cli

echo "==> Verify"
rawtherapee-cli --version
echo "Locale file:"
cat /etc/default/locale

echo
echo "Done. Reconnect your SSH session for locale changes to take effect."
echo
echo "Remaining manual steps:"
echo "  1. Deploy key for GitHub:"
echo "       ssh-keygen -t ed25519 -C \"raspberrypi\""
echo "       cat ~/.ssh/id_ed25519.pub"
echo "     Add at: repo -> Settings -> Deploy keys (read-only)"
echo "  2. Clone:"
echo "       git clone git@github.com:jsepulvedaco/rawsberry.git"
