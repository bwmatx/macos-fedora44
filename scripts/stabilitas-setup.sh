#!/usr/bin/env bash
# stabilitas-setup.sh - mitigasi beban & penyelamat darurat (beku 17 Okt 2026)
# Bagian dari rice "macos-fedora44". Idempoten, dijalankan sebagai user biasa.
#
# Latar: laptop ini (i3-7020U / RAM 3,7 GiB / iGPU HD 620) pernah beku total
# (layar diam tapi kursor masih bergerak = hang jalur grafis) saat membuka
# App Grid lewat F4. Diagnosis: blur berat di jalur Overview + driver nouveau
# (dipakai RustDesk) + tekanan memori.
#
# Yang dilakukan:
#  1. Blur My Shell: matikan blur 'overview' (latar Overview/App Grid) dan
#     'appfolder'. Panel (top bar), lockscreen, dan coverflow-alt-tab tetap ON.
#  2. RustDesk: nonaktifkan service - laptop ini bukan target remote.
#     Aktifkan lagi bila perlu: sudo systemctl enable --now rustdesk
#  3. SysRq=1 via /etc/sysctl.d/99-sysrq-reisub.conf (REISUB darurat).
#     Kalau beku lagi: Alt+SysRq+R E I S U B - bukan power button.
#
# Bagian 2 & 3 butuh root; skrip memanggil pkexec (muncul dialog password).
# Kalau pkexec tidak tersedia, perintah sudo alternatif dicetak di akhir.

set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "== [1/3] Blur My Shell: overview + appfolder OFF"
if gsettings list-schemas 2>/dev/null | grep -q '^org.gnome.shell.extensions.blur-my-shell.overview$'; then
  gsettings set org.gnome.shell.extensions.blur-my-shell.overview blur false
  gsettings set org.gnome.shell.extensions.blur-my-shell.appfolder blur false
  echo "   overview  = $(gsettings get org.gnome.shell.extensions.blur-my-shell.overview blur)"
  echo "   appfolder = $(gsettings get org.gnome.shell.extensions.blur-my-shell.appfolder blur)"
else
  echo "   (Blur My Shell tidak terpasang - dilewati)"
fi

echo "== [2/3] RustDesk: disable + stop"
if systemctl is-enabled rustdesk >/dev/null 2>&1 || systemctl is-active rustdesk >/dev/null 2>&1; then
  if command -v pkexec >/dev/null 2>&1; then
    pkexec sh -c 'systemctl disable --now rustdesk' \
      || echo "!! gagal - jalankan manual: sudo systemctl disable --now rustdesk"
  else
    echo "!! pkexec tidak ada - jalankan manual: sudo systemctl disable --now rustdesk"
  fi
else
  echo "   sudah nonaktif"
fi

echo "== [3/3] SysRq=1 (REISUB darurat)"
if [ "$(cat /proc/sys/kernel/sysrq)" = "1" ]; then
  echo "   sudah aktif"
else
  if command -v pkexec >/dev/null 2>&1; then
    pkexec sh -c "cp '$REPO_DIR/config/sysctl.d/99-sysrq-reisub.conf' /etc/sysctl.d/ && sysctl -w kernel.sysrq=1" \
      || echo "!! gagal - jalankan manual: sudo cp config/sysctl.d/99-sysrq-reisub.conf /etc/sysctl.d/ && sudo sysctl -w kernel.sysrq=1"
  else
    echo "!! pkexec tidak ada - jalankan manual: sudo cp config/sysctl.d/99-sysrq-reisub.conf /etc/sysctl.d/ && sudo sysctl -w kernel.sysrq=1"
  fi
fi

echo
echo "Selesai. Kalau beku lagi: Alt+SysRq+R E I S U B (jangan power button)."
