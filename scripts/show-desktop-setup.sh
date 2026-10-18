#!/usr/bin/env bash
# show-desktop-setup.sh - aktifkan "Show Desktop" ala Windows (Win+D / Super+D)
# Bagian dari rice "macos-fedora44" (19 Okt 2026).
# © 2026 Adhiwibowo - adhiwibowo.my.id
#
# Temuan (dari source mutter 50.0, bukan dugaan):
# - Fitur show-desktop sudah NATIVE di mutter: src/core/keybindings.c ->
#   handle_show_desktop() = toggle meta_workspace_manager_show_desktop() /
#   unshow_desktop() + meta_workspace_focus_default_window() (restore fokus,
#   persis perilaku Win+D).
# - Window bertipe DESKTOP (ikon desktop DING) dan dock otomatis dikecualikan;
#   saat desktop aktif, window DESKTOP malah difokuskan. Jendela baru yang
#   dibuka saat mode desktop aktif ikut di-minimize (ala Windows).
# - Key "show-desktop" di schema org.gnome.desktop.wm.keybindings default-nya
#   KOSONG ([]) dan tidak ada UI-nya di GNOME Settings - itulah sebabnya
#   Super+D tidak pernah berfungsi (GNOME Shell juga tidak menimpa key ini).
# - Set via gsettings berlaku LANGSUNG tanpa logout: mutter memantau
#   perubahan gsettings (bukti: batch rebuild tabel keybinding muncul di
#   jurnal gnome-shell tepat pada detik set).
#
# Pemakaian:
#   bash show-desktop-setup.sh                          # bind ke Super+D (default)
#   bash show-desktop-setup.sh "['<Super>d','<Alt>d']"  # binding custom
#   bash show-desktop-setup.sh --revert                 # kosongkan (kembali default)
#
# Idempoten: bila nilainya sudah sama, tidak menulis ulang.

set -euo pipefail

SCHEMA=org.gnome.desktop.wm.keybindings
KEY=show-desktop
WANT="['<Super>d']"

if [ "${1:-}" = "--revert" ]; then
    gsettings reset "$SCHEMA" "$KEY"
    echo "OK: $KEY dikembalikan ke default ([] = tanpa shortcut)."
    exit 0
fi

if [ -n "${1:-}" ]; then
    WANT="$1"
fi

CUR=$(gsettings get "$SCHEMA" "$KEY")
if [ "$CUR" = "$WANT" ]; then
    echo "SKIP: $KEY sudah $WANT (tidak ada perubahan)."
else
    gsettings set "$SCHEMA" "$KEY" "$WANT"
    echo "OK: $KEY: $CUR -> $WANT (berlaku langsung, tanpa logout)."
fi

echo
echo "Tes: buka 2-3 aplikasi -> Super+D (semua minimize, kembali ke desktop),"
echo "Super+D lagi -> semua jendela kembali dengan fokus ke jendela terakhir."
echo "Catatan: fitur native mutter; ikon desktop (DING) & dock tidak terpengaruh."
