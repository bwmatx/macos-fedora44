#!/usr/bin/env bash
# desktop-icons-setup.sh - ikon desktop ala Windows (Desktop Icons NG / DING)
# Bagian dari rice "macos-fedora44". Dijalankan sebagai user biasa (tanpa sudo).
# Idempoten: aman dijalankan berulang kali.
#
# Latar belakang:
#  - GNOME (Fedora) tidak punya ikon desktop bawaan; solusi standar = ekstensi
#    "Desktop Icons NG (DING)" - sama seperti default Ubuntu.
#  - Fedora 44 tidak memaketkan DING, jadi diambil dari extensions.gnome.org
#    (GNOME 50 -> DING v99, version_tag=75576).
#  - Catatan penting: menaruh folder ekstensi langsung TIDAK cukup pada sesi
#    yang sedang berjalan - shell GNOME 50 tidak memindai folder ekstensi baru.
#    Cara yang terbukti bekerja tanpa logout: daftarkan lewat D-Bus
#    InstallRemoteExtension (shell mengunduh & mendaftar sendiri).
#
# Yang dilakukan:
#  1. Pastikan ekstensi terpasang di ~/.local/share/gnome-shell/extensions/ding@rastersoft.com
#     (dari salinan di repo ini; unduh dari extensions.gnome.org bila belum ada).
#  2. Aktifkan ekstensi (fallback: daftar via D-Bus InstallRemoteExtension).
#  3. Preferensi awal: Home/Trash tampil, drive/HDD disembunyikan, ikon mulai
#     dari kiri-atas, urut nama (semuanya bisa diubah di Extensions ->
#     Desktop Icons NG (DING) -> Preferences).
#
# Bongkar: gnome-extensions uninstall ding@rastersoft.com (logout/login bila
# perlu); shortcut di ~/Desktop aman dihapus manual.

set -euo pipefail

UUID="ding@rastersoft.com"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_EXT="$REPO_DIR/gnome-shell/extensions/$UUID"
ZIP_URL="https://extensions.gnome.org/download-extension/ding@rastersoft.com.shell-extension.zip?version_tag=75576"

echo "== [1/3] Memasang ekstensi DING"
if [ ! -f "$EXT_DIR/metadata.json" ]; then
  mkdir -p "$EXT_DIR"
  if [ -f "$REPO_EXT/metadata.json" ]; then
    cp -a "$REPO_EXT/." "$EXT_DIR/"
    echo "   disalin dari repo: $REPO_EXT"
  else
    TMP="$(mktemp -d)"
    echo "   mengunduh dari extensions.gnome.org ..."
    curl -sSL -o "$TMP/ding.zip" "$ZIP_URL"
    unzip -q -o "$TMP/ding.zip" -d "$EXT_DIR"
    rm -rf "$TMP"
    echo "   diunduh & diekstrak dari EGO"
  fi
else
  echo "   sudah terpasang: $EXT_DIR"
fi

echo "== [2/3] Mengaktifkan ekstensi"
gnome-extensions enable "$UUID" 2>/dev/null || true
sleep 1
if ! gnome-extensions info "$UUID" 2>/dev/null | grep -q "State: ACTIVE"; then
  echo "   shell belum mendaftarkannya -> daftar via D-Bus InstallRemoteExtension ..."
  gdbus call --session --dest org.gnome.Shell.Extensions \
    --object-path /org/gnome/Shell/Extensions \
    --method org.gnome.Shell.Extensions.InstallRemoteExtension "$UUID" >/dev/null 2>&1 || true
  sleep 6
  gnome-extensions enable "$UUID" 2>/dev/null || true
  sleep 1
fi
gnome-extensions info "$UUID" 2>/dev/null | grep -E "Name:|Enabled:|State:" || \
  echo "   (belum aktif - coba logout lalu login sekali)"

echo "== [3/3] Preferensi awal"
export GSETTINGS_SCHEMA_DIR="$EXT_DIR/schemas"
gsettings set org.gnome.shell.extensions.ding show-home true
gsettings set org.gnome.shell.extensions.ding show-trash true
gsettings set org.gnome.shell.extensions.ding show-volumes false
gsettings set org.gnome.shell.extensions.ding start-corner top-left
gsettings set org.gnome.shell.extensions.ding arrangeorder NAME

echo
echo "Selesai. Shortcut aplikasi desktop: pakai scripts/buat-shortcut-desktop.sh"
