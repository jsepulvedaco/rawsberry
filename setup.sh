#!/bin/bash
#
# setup.sh — Provision a fresh Raspberry Pi 5 for the edge-raw-jpeg appliance.
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
    rawtherapee

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
echo "       git clone git@github.com:jsepulvedaco/edge-raw-jpeg.git"
