#!/usr/bin/env bash
# fix-ding-dock-flicker.sh - stabilkan margin dash-to-dock -> DING (anti-flicker)
# Bagian dari rice "macos-fedora44" (17 Okt 2026).
#
# Masalah: ikon desktop (DING) berkedip "terbuka-tutup" saat pointer berada di
# atas dock. Sebab: dash-to-dock (_updateVisibleDesktop) mengirim tinggi/lebar
# box-nya ke DING pada SETIAP perubahan allocation/animation. Saat hover
# (tooltip/preview/animasi), nilainya transien dan terus berubah-ubah; DING
# kemudian menghancurkan + membangun ulang SELURUH grid ikon desktop untuk
# tiap perubahan margin sekecil apa pun (updateGridWindows -> _createGridWindows).
#
# Perbaikan: kirim margin hanya saat pointer TIDAK di atas dock (nilai diam),
# dan bulatkan ke piksel utuh.
#
# Idempoten: deteksi marker [macos-fedora44]; backup sekali ke docking.js.d2d-orig.
# Jalankan ulang setelah `dnf update` paket gnome-shell-extension-dash-to-dock
# (file di /usr/share akan tertimpa versi baru dari paket).
#
# Pemakaian (butuh root - pakai pkexec, muncul dialog password):
#   pkexec bash fix-ding-dock-flicker.sh
#   pkexec bash fix-ding-dock-flicker.sh --revert   # kembalikan dari backup
#
# Setelah dijalankan: muat ulang ekstensi (lihat petunjuk di akhir output).
# Bila flicker masih ada setelah reload: logout/login sekali (cache modul JS).

set -euo pipefail

D2D=/usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com
TARGET="$D2D/docking.js"
BACKUP="$D2D/docking.js.d2d-orig"
MARKER='[macos-fedora44]'

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: butuh root. Jalankan: pkexec bash \"$0\"" >&2
    exit 1
fi

if [ "${1:-}" = "--revert" ]; then
    [ -f "$BACKUP" ] || { echo "ERROR: backup tidak ditemukan: $BACKUP" >&2; exit 1; }
    cp -a "$BACKUP" "$TARGET"
    echo "OK: docking.js dikembalikan dari backup."
    exit 0
fi

[ -f "$TARGET" ] || { echo "ERROR: tidak ditemukan: $TARGET" >&2; exit 1; }

if grep -qF "$MARKER" "$TARGET"; then
    echo "SKIP: sudah ter-patch (marker $MARKER ditemukan). Tidak ada perubahan."
    exit 0
fi

if [ ! -f "$BACKUP" ]; then
    cp -a "$TARGET" "$BACKUP"
    echo "Backup dibuat: $BACKUP"
else
    echo "Backup sudah ada: $BACKUP (dibiarkan apa adanya)."
fi

python3 - "$TARGET" <<'PYEOF'
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    src = fh.read()

old = """    _updateVisibleDesktop() {
        if (!this._intellihideIsEnabled)
            return;

        const {desktopIconsUsableArea} = DockManager.getDefault();
        if (this._position === St.Side.BOTTOM)
            desktopIconsUsableArea.setMargins(this.monitorIndex, 0, this._box.height, 0, 0);
        else if (this._position === St.Side.TOP)
            desktopIconsUsableArea.setMargins(this.monitorIndex, this._box.height, 0, 0, 0);
        else if (this._position === St.Side.RIGHT)
            desktopIconsUsableArea.setMargins(this.monitorIndex, 0, 0, 0, this._box.width);
        else if (this._position === St.Side.LEFT)
            desktopIconsUsableArea.setMargins(this.monitorIndex, 0, 0, this._box.width, 0);
    }
"""

new = """    _updateVisibleDesktop() {
        if (!this._intellihideIsEnabled)
            return;

        // [macos-fedora44] Jangan kirim margin saat pointer ada di atas dock:
        // tinggi/lebar box bisa berubah tiap frame (tooltip, preview, animasi
        // hover) dan setiap perubahan memicu DING menghancurkan lalu membangun
        // ulang seluruh grid ikon desktop (flicker). Kirim hanya saat dock
        // dalam keadaan diam, dan bulatkan ke piksel utuh.
        if (this._box.hover)
            return;

        const height = Math.round(this._box.height);
        const width = Math.round(this._box.width);
        const {desktopIconsUsableArea} = DockManager.getDefault();
        if (this._position === St.Side.BOTTOM)
            desktopIconsUsableArea.setMargins(this.monitorIndex, 0, height, 0, 0);
        else if (this._position === St.Side.TOP)
            desktopIconsUsableArea.setMargins(this.monitorIndex, height, 0, 0, 0);
        else if (this._position === St.Side.RIGHT)
            desktopIconsUsableArea.setMargins(this.monitorIndex, 0, 0, 0, width);
        else if (this._position === St.Side.LEFT)
            desktopIconsUsableArea.setMargins(this.monitorIndex, 0, 0, width, 0);
    }
"""

if old not in src:
    sys.exit("ERROR: pola _updateVisibleDesktop tidak ditemukan utuh - "
             "versi dash-to-dock mungkin berbeda. PATCH DIBATALKAN, file tidak diubah.")
if src.count(old) != 1:
    sys.exit("ERROR: pola ditemukan lebih dari sekali - PATCH DIBATALKAN.")

with open(path, "w", encoding="utf-8") as fh:
    fh.write(src.replace(old, new, 1))
print("Patch ditulis ke file.")
PYEOF

grep -qF "$MARKER" "$TARGET" || { echo "ERROR: verifikasi pasca-patch gagal." >&2; exit 1; }
echo "OK: patch diterapkan & terverifikasi."
echo
echo "Selanjutnya (sebagai user biasa):"
echo "  UUID=dash-to-dock@micxgx.gmail.com"
echo "  gnome-extensions disable \$UUID && sleep 1 && gnome-extensions enable \$UUID"
echo "  (bila flicker masih ada setelah reload: logout/login sekali)"
