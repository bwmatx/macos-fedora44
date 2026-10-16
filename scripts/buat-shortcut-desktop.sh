#!/usr/bin/env bash
# buat-shortcut-desktop.sh - buat shortcut aplikasi di Desktop (ala Windows)
# Bagian dari rice "macos-fedora44". Dijalankan sebagai user biasa.
#
# Pemakaian:
#   buat-shortcut-desktop.sh                 # daftar app yang bisa dijadikan shortcut
#   buat-shortcut-desktop.sh brave           # buat shortcut "brave" di ~/Desktop
#   buat-shortcut-desktop.sh files terminal  # bisa beberapa sekaligus
#
# Cara kerja: mencari file .desktop di lokasi standar (user, sistem, ekspor
# Flatpak), menyalinnya ke ~/Desktop, menetapkan chmod 755, lalu menandai
# metadata::trusted=true - syarat GNOME/DING agar shortcut hasil salinan bisa
# diluncurkan (tanpa ini muncul peringatan "untrusted launcher").
# Pencocokan kata kunci: prioritas ke kolom Name aplikasi, lalu ke nama file.

set -euo pipefail

DIRS=(
  "$HOME/.local/share/applications"
  "/usr/share/applications"
  "/var/lib/flatpak/exports/share/applications"
  "$HOME/.local/share/flatpak/exports/share/applications"
)
DESK="$HOME/Desktop"
mkdir -p "$DESK"

list_apps() {
  local d f name
  for d in "${DIRS[@]}"; do
    [ -d "$d" ] || continue
    for f in "$d"/*.desktop; do
      [ -f "$f" ] || continue
      name=$(grep -m1 '^Name=' "$f" 2>/dev/null | cut -d= -f2-)
      [ -n "$name" ] && printf '%s|%s\n' "$name" "$f"
    done
  done | sort -u
}

if [ $# -eq 0 ]; then
  echo "Daftar aplikasi yang bisa dijadikan shortcut:"
  echo
  list_apps | while IFS='|' read -r name path; do printf '  %-38s %s\n' "$name" "$(basename "$path")"; done
  echo
  echo "Contoh: $(basename "$0") brave"
  exit 0
fi

rc=0
for q in "$@"; do
  mapfile -t hits < <(list_apps | awk -F'|' -v q="$q" 'index(tolower($1), tolower(q)) > 0')
  if [ ${#hits[@]} -eq 0 ]; then
    mapfile -t hits < <(list_apps | awk -F'|' -v q="$q" 'index(tolower($2), tolower(q)) > 0')
  fi
  if [ ${#hits[@]} -eq 0 ]; then
    echo "TIDAK DITEMUKAN: '$q' - jalankan tanpa argumen untuk melihat daftar." >&2
    rc=1
    continue
  fi
  if [ ${#hits[@]} -gt 1 ]; then
    echo "AMBIGU: '$q' cocok dengan lebih dari satu, pakai kata kunci lebih spesifik:" >&2
    printf '%s\n' "${hits[@]}" | while IFS='|' read -r n p; do printf '  %-38s %s\n' "$n" "$(basename "$p")"; done >&2
    rc=1
    continue
  fi
  src="${hits[0]#*|}"
  dst="$DESK/$(basename "$src")"
  cp -Lf "$src" "$dst"
  chmod 755 "$dst"
  gio set "$dst" metadata::trusted true
  echo "Shortcut dibuat: $dst"
done
exit $rc
