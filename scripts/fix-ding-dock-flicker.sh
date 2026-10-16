#!/usr/bin/env bash
# fix-ding-dock-flicker.sh - stabilkan margin dash-to-dock -> DING (anti-flicker)
# Bagian dari rice "macos-fedora44" (17 Okt 2026).
#
# Masalah: ikon desktop (DING) berkedip "terbuka-tutup" saat pointer berada di
# atas dock. Sebab: dash-to-dock (_updateVisibleDesktop) mengirim tinggi/lebar
# box-nya ke DING pada SETIAP perubahan allocation (animasi hover/magnifikasi,
# tooltip, preview jendela, slide intellihide) - nilainya transien dan terus
# berubah; DING kemudian menghancurkan + membangun ulang SELURUH grid ikon
# desktop untuk tiap perubahan margin (updateGridWindows -> _createGridWindows).
#
# Perbaikan (v2 - settle):
#   1) Margin tidak dikirim selagi pointer ada di atas dock.
#   2) Nilai hanya dikirim setelah "diam" 300 ms (semua pemicu transien
#      me-reset timer; hanya nilai akhir yang lolos) dan dibulatkan ke piksel.
#   Dengan begitu nilainya stabil (80) dan DING tidak pernah membangun ulang
#   grid saat hover.
#
# PENTING (17 Okt 2026): GNOME Shell menyimpan cache modul JS selama sesi
# berjalan - lihat extensionSystem.js (import() tanpa cache-buster; komentar
# "The extension is now cached and it's impossible to load a different
# version"). Disable/enable ekstensi TIDAK memuat ulang file dari disk.
# Setelah menjalankan skrip ini WAJIB logout & login sekali (Wayland: shell
# tidak bisa di-restart tanpa logout).
# Jalankan ulang skrip setelah `dnf update` paket
# gnome-shell-extension-dash-to-dock (file di /usr/share tertimpa paket),
# lalu logout/login lagi.
#
# Pemakaian (butuh root - pakai pkexec, muncul dialog password):
#   pkexec bash fix-ding-dock-flicker.sh
#   pkexec bash fix-ding-dock-flicker.sh --revert   # kembalikan dari backup
#
# Idempoten: deteksi tag _mfSettleTimeoutId; backup sekali ke docking.js.d2d-orig.

set -euo pipefail

D2D=/usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com
TARGET="${TARGET_OVERRIDE:-$D2D/docking.js}"
BACKUP="$D2D/docking.js.d2d-orig"
MARKER='[macos-fedora44]'
V2TAG='_mfSettleTimeoutId'

if [ "${PATCH_ALLOW_NONROOT:-0}" != "1" ] && [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: butuh root. Jalankan: pkexec bash \"$0\"" >&2
    exit 1
fi

if [ "${1:-}" = "--revert" ]; then
    [ -f "$BACKUP" ] || { echo "ERROR: backup tidak ditemukan: $BACKUP" >&2; exit 1; }
    cp -a "$BACKUP" "$TARGET"
    echo "OK: docking.js dikembalikan dari backup."
    echo "CATATAN: butuh logout/login agar GNOME memuat ulang kode."
    exit 0
fi

[ -f "$TARGET" ] || { echo "ERROR: tidak ditemukan: $TARGET" >&2; exit 1; }

if grep -qF "$V2TAG" "$TARGET"; then
    echo "SKIP: docking.js sudah v2 (tag $V2TAG ditemukan). Tidak ada perubahan."
    echo "CATATAN: bila baru pertama kali, logout/login agar kode v2 dimuat GNOME."
    exit 0
fi

if [ ! -f "$BACKUP" ]; then
    cp -a "$TARGET" "$BACKUP"
    echo "Backup dibuat: $BACKUP"
else
    echo "Backup sudah ada: $BACKUP (dibiarkan apa adanya)."
fi

python3 - "$TARGET" <<'PYEOF'
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    src = fh.read()

new_fn = '''    _updateVisibleDesktop() {
        if (!this._intellihideIsEnabled)
            return;

        // [macos-fedora44] Anti-flicker DING (v2 - settle):
        // 1) Jangan kirim margin selagi pointer ada di atas dock (tinggi/lebar
        //    box bisa berubah tiap frame karena tooltip/preview/magnifikasi).
        if (this._box.hover)
            return;

        // 2) Tunggu nilai benar-benar diam (300 ms) sebelum dikirim: semua
        //    pemicu transien me-reset timer, jadi hanya nilai akhir yang
        //    sampai ke DING (dibulatkan ke piksel utuh). Tanpa ini, tiap
        //    perubahan margin membuat DING menghancurkan + membangun ulang
        //    seluruh grid ikon desktop (flicker).
        if (this._mfSettleTimeoutId) {
            GLib.source_remove(this._mfSettleTimeoutId);
            this._mfSettleTimeoutId = 0;
        }
        this._mfSettleTimeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
            this._mfSettleTimeoutId = 0;
            try {
                if (this._box.hover)
                    return GLib.SOURCE_REMOVE;
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
            } catch (e) {
                // Dock sedang dibongkar / belum siap: abaikan.
            }
            return GLib.SOURCE_REMOVE;
        });
    }
'''

pat = re.compile(
    r"    _updateVisibleDesktop\(\) \{\n"
    r".*?"
    r"\n    \}\n\n"
    r"    _updateStaticBox\(\) \{",
    re.S)

if len(pat.findall(src)) != 1:
    sys.exit("ERROR: blok _updateVisibleDesktop.._updateStaticBox tidak "
             "ditemukan persis sekali - versi dash-to-dock mungkin berbeda. "
             "PATCH DIBATALKAN, file tidak diubah.")

src = pat.sub(new_fn + "\n    _updateStaticBox() {", src, count=1)

with open(path, "w", encoding="utf-8") as fh:
    fh.write(src)
print("Patch v2 ditulis ke file.")
PYEOF

grep -qF "$V2TAG" "$TARGET" || { echo "ERROR: verifikasi pasca-patch gagal." >&2; exit 1; }
echo "OK: patch v2 diterapkan & terverifikasi."
echo
echo "PENTING: GNOME menyimpan cache modul JS selama sesi berjalan."
echo "Logout lalu login (atau reboot) agar kode v2 benar-benar dimuat."
