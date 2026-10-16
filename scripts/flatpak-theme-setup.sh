#!/usr/bin/env bash
# flatpak-theme-setup.sh - menyamakan tema macOS (MacTahoe) untuk aplikasi Flatpak
# Bagian dari rice "macos-fedora44". Dijalankan sebagai user biasa (tanpa sudo).
# Idempoten: aman dijalankan berulang kali.
#
# Latar belakang:
#  - Sandbox Flatpak tidak melihat ~/.themes, ~/.local/share/icons, ~/.config/dconf.
#  - Runtime org.freedesktop.Platform tidak menyediakan modul GIO libdconfsettings.so,
#    sehingga GSettings di sandbox jatuh ke backend keyfile (tema kembali ke Adwaita).
#  - Di sandbox, XDG_CONFIG_HOME/XDG_DATA_HOME diarahkan ke ~/.var/app/<id>/...,
#    jadi dconf dan ikon tidak membaca lokasi standar host.
#
# Yang dilakukan skrip ini:
#  1. Menyalin modul dconf (libdconfsettings.so + libdconf.so.1) ke
#     ~/.local/share/flatpak-dconf/ - sumber utama bundel Brave (runtime cocok),
#     fallback paket dconf host (/usr/lib64).
#  2. flatpak override --user: izin tema/ikon/dconf + bus ca.desrt.dconf + env
#     GIO_EXTRA_MODULES & LD_LIBRARY_PATH.
#  3. Symlink per aplikasi:
#       ~/.var/app/<id>/config/dconf -> ~/.config/dconf
#       ~/.var/app/<id>/data/icons   -> ~/.local/share/icons
#     (khusus com.brave.Browser, symlink dconf dilewati - Brave sudah membawa
#      modul dconf sendiri dan membaca dconf host; jangan diubah).
#
# Membongkar (kembali ke default Flatpak, lalu restart aplikasi):
#   flatpak override --user --reset
#   rm -f ~/.var/app/*/config/dconf ~/.var/app/*/data/icons
#   rm -rf ~/.local/share/flatpak-dconf
#
# Catatan: aplikasi yang menggambar kontrol jendelanya sendiri (mis. suite
# Storyteller berbasis egui) tidak terpengaruh - itu batasan aplikasi.

set -euo pipefail

MODDIR="$HOME/.local/share/flatpak-dconf"
BRAVE_DIRS=(/var/lib/flatpak/app/com.brave.Browser "$HOME/.local/share/flatpak/app/com.brave.Browser")

echo "== [1/3] Menyiapkan modul dconf sandbox di $MODDIR"
mkdir -p "$MODDIR"

MODULE_SRC="$(find "${BRAVE_DIRS[@]}" -path '*files/lib/gio/modules/libdconfsettings.so' 2>/dev/null | head -n1 || true)"
LIB_SRC="$(find "${BRAVE_DIRS[@]}" -path '*files/lib/libdconf.so.1.0.0' 2>/dev/null | head -n1 || true)"
[ -n "$MODULE_SRC" ] || MODULE_SRC="/usr/lib64/gio/modules/libdconfsettings.so"
[ -n "$LIB_SRC" ] || LIB_SRC="/usr/lib64/libdconf.so.1"

if [ ! -f "$MODULE_SRC" ] || [ ! -f "$LIB_SRC" ]; then
  echo "ERROR: modul dconf tidak ditemukan (pasang Brave Flatpak atau paket dconf Fedora)." >&2
  exit 1
fi

cp -f "$MODULE_SRC" "$MODDIR/libdconfsettings.so"
cp -f "$LIB_SRC" "$MODDIR/libdconf.so.1.0.0"
ln -sf libdconf.so.1.0.0 "$MODDIR/libdconf.so.1"
echo "   modul: $MODULE_SRC"
echo "   lib  : $LIB_SRC"

echo "== [2/3] Izin berbagi & lingkungan untuk semua sandbox (override --user)"
flatpak override --user --filesystem="$HOME/.themes:ro"
flatpak override --user --filesystem="$HOME/.local/share/icons:ro"
flatpak override --user --filesystem="$HOME/.config/dconf:ro"
flatpak override --user --filesystem=xdg-run/dconf
flatpak override --user --filesystem="$MODDIR:ro"
flatpak override --user --talk-name=ca.desrt.dconf
flatpak override --user --env="GIO_EXTRA_MODULES=$MODDIR:/app/lib/gio/modules"
flatpak override --user --env="LD_LIBRARY_PATH=$MODDIR"

echo "== [3/3] Symlink per aplikasi"
for base in "$HOME"/.var/app/*/; do
  [ -d "$base" ] || continue
  id="$(basename "$base")"
  mkdir -p "$base/config" "$base/data"
  if [ ! -e "$base/config/dconf" ] && [ ! -L "$base/config/dconf" ]; then
    if [ "$id" = "com.brave.Browser" ]; then
      echo "   $id: dconf dilewati (Brave sudah membawa modul dconf sendiri)"
    else
      ln -s "$HOME/.config/dconf" "$base/config/dconf"
      echo "   $id: config/dconf -> ~/.config/dconf"
    fi
  fi
  if [ ! -e "$base/data/icons" ] && [ ! -L "$base/data/icons" ]; then
    ln -s "$HOME/.local/share/icons" "$base/data/icons"
    echo "   $id: data/icons -> ~/.local/share/icons"
  fi
done

echo
echo "Selesai. Restart aplikasi Flatpak yang sedang berjalan agar setelan berlaku."
echo "Verifikasi (dari dalam sandbox): gsettings get org.gnome.desktop.interface gtk-theme"
