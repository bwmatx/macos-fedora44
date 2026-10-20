#!/usr/bin/env bash
# trim-bloat-fedora44.sh - bersihkan bloat & turunkan beban boot/login (21 Okt 2026)
# Bagian dari rice "macos-fedora44".
#
# © 2026 Adhiwibowo - https://adhiwibowo.my.id
# License: GPL-3.0 (lihat ../LICENSE)
#
# Latar (bukti dari pemindaian 21 Okt 2026, bukan tebakan):
#  - updatedb memindai /mnt/d + /mnt/e (NTFS/fuseblk): 19 dtk wall, 9,06 dtk CPU,
#    puncak 277,5 MB. Index plocate tetap dipakai, tapi /mnt + fuseblk/ntfs/ntfs3
#    di-prune.
#  - TuneD "throughput-performance" memaksa vm.swappiness=10 tiap boot. Dengan
#    zram 3,7 GB, profile anak "macos-zram" menyetel swappiness=100 +
#    page-cluster=0 (runtime sysctl; tidak mengganti paket kernel).
#  - tuned-ppd memetakan PPD "performance" -> throughput-performance dan
#    menimpanya setelah TuneD start; /etc/tuned/ppd.conf diarahkan ke
#    performance=macos-zram supaya profile bertahan setelah restart/reboot.
#  - NetworkManager-wait-online = 6,018 dtk dari total boot 34,151 dtk.
#  - gnome-software --gapplication-service = rata-rata 8,1% CPU selama 12 menit
#    + dnf5daemon-server; tidak dipakai karena update lewat dnf/flatpak langsung.
#  - abrt ~69 MB, rygel 25,7 MB, gnome-user-share 4,9 MB saat diam.
#  - stack virtualisasi (gnome-boxes/podman/toolbox/qemu/edk2) = 170 paket;
#    tidak ada VM, container, atau toolbox.
#  - Anaconda + Firefox = 8 paket. Firefox tidak pernah dibuka (atime 15 Okt,
#    tanpa profil ~/.mozilla); browser default Brave (Flatpak).
#
# Yang TIDAK disentuh:
#  - paket kernel / kernel-core / kernel-modules / linux-firmware
#  - driver & firmware NVIDIA (nvidia*, akmod-nvidia*, kmod-nvidia*), nouveau
#  - GRUB, fstab, driver ntfs3, Java, LibreOffice, evolution-data-server + GOA
#  - Brave/Packet/Storyteller (Flatpak), Bluetooth OPPO, Avahi, fwupd,
#    malcontent, localsearch, systemd-oomd-defaults, DING, Dash to Dock, Super+D.
#
# Pemakaian:
#   bash scripts/trim-bloat-fedora44.sh --dry-run   # lihat rencana, tanpa ubah
#   bash scripts/trim-bloat-fedora44.sh --apply     # jalankan (pkexec otomatis)
#   bash scripts/trim-bloat-fedora44.sh --revert    # balikkan config sistem
#
# --apply dan --revert butuh root; skrip akan memanggil pkexec sendiri.
# Semua perubahan dicatat ke /var/log/trim-bloat-fedora44.log.
# Setelah --apply: logout/login (atau reboot) agar service user benar-benar
# berhenti dan efek boot terlihat.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="$(readlink -f "$0")"
LOG="/var/log/trim-bloat-fedora44.log"
MODE="apply"
ROOT_CHILD=0

usage() {
  cat <<'EOF'
Pemakaian: bash scripts/trim-bloat-fedora44.sh [--dry-run|--apply|--revert]

  --dry-run  tampilkan rencana tanpa mengubah sistem
  --apply    terapkan pembersihan (default)
  --revert   balikkan konfigurasi updatedb/TuneD/service/autostart
             (paket yang sudah dihapus tidak diinstal ulang otomatis;
              perintah reinstall dicetak di akhir)
EOF
}

case "${1:-}" in
  --dry-run) MODE="dry-run" ;;
  --apply|"") MODE="apply" ;;
  --revert) MODE="revert" ;;
  --_root) MODE="${2:-apply}"; ROOT_CHILD=1 ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Argumen tidak dikenal: ${1:-}"; usage; exit 2 ;;
esac

if [[ "$MODE" != "dry-run" && "$EUID" -ne 0 ]]; then
  if command -v pkexec >/dev/null 2>&1; then
    echo "Butuh root - membuka dialog pkexec..."
    exec pkexec bash "$SCRIPT_PATH" --_root "$MODE"
  else
    echo "!! pkexec tidak tersedia. Jalankan: sudo bash $0 --$MODE" >&2
    exit 1
  fi
fi

if [[ "$EUID" -eq 0 ]]; then
  exec > >(tee -a "$LOG") 2>&1
fi

TARGET_USER=""
TARGET_UID=""
TARGET_HOME=""
TARGET_GROUP=""
if [[ -n "${PKEXEC_UID:-}" ]]; then
  TARGET_USER="$(getent passwd "$PKEXEC_UID" | cut -d: -f1 || true)"
elif [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  TARGET_USER="$SUDO_USER"
else
  TARGET_USER="$(logname 2>/dev/null || true)"
  [[ "$TARGET_USER" == "root" ]] && TARGET_USER=""
fi
if [[ -n "$TARGET_USER" ]]; then
  TARGET_UID="$(id -u "$TARGET_USER")"
  TARGET_GROUP="$(id -gn "$TARGET_USER")"
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
fi

as_user() {
  [[ -n "$TARGET_USER" ]] || return 0
  runuser -u "$TARGET_USER" -- env \
    HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" \
    XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus" \
    "$@"
}

section() { printf '\n== %s ==\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }

# Paket yang tidak boleh ikut terhapus oleh transaksi apa pun.
# kernel* di sini hanya nama paket kernel; abrt-addon-kerneloops tidak match
# karena namanya dimulai "abrt-".
DNF_EXCLUDES=(
  --exclude='kernel*'
  --exclude='nvidia*'
  --exclude='akmod-nvidia*'
  --exclude='kmod-nvidia*'
  --exclude='nouveau*'
  --exclude='linux-firmware*'
)
PROTECTED_RE='^(kernel(-.*)?|nvidia.*|akmod-nvidia.*|kmod-nvidia.*|nouveau.*|linux-firmware.*|gnome-shell|gnome-shell-extension.*|gdm|mutter|gnome-session.*|gnome-control-center|nautilus|flatpak.*|evolution-data-server|gnome-online-accounts.*|libreoffice.*|java-.*|tuned|plocate|pipewire.*|wireplumber|bluez|bluez-libs|bluez-obexd|avahi.*|fwupd.*|malcontent.*|localsearch.*|systemd-oomd|zram-generator|NetworkManager.*|systemd|dnf5|python3-dnf.*|xdg-desktop-portal.*|gnome-bluetooth.*)$'

installed_names() {
  local spec
  for spec in "$@"; do
    if [[ "$spec" == *'*'* ]]; then
      rpm -qa --qf '%{name}\n' "$spec" 2>/dev/null | sort -u
    elif rpm -q "$spec" >/dev/null 2>&1; then
      printf '%s\n' "$spec"
    fi
  done
}

remove_pkgs() {
  local label="$1" clean="$2"; shift 2
  local pkgs=()
  local spec line
  while IFS= read -r line; do
    [[ -n "$line" ]] && pkgs+=("$line")
  done < <(installed_names "$@")

  if [[ ${#pkgs[@]} -eq 0 ]]; then
    echo "   - $label: sudah bersih / tidak terpasang"
    return 0
  fi

  section "Hapus: $label (${#pkgs[@]} paket)"
  printf '   %s\n' "${pkgs[@]}"

  local plan
  if [[ "$clean" == "keepdeps" ]]; then
    plan="$(dnf -q remove --assumeno \
      --setopt=clean_requirements_on_remove=False \
      "${DNF_EXCLUDES[@]}" "${pkgs[@]}" 2>&1 || true)"
  else
    plan="$(dnf -q remove --assumeno "${DNF_EXCLUDES[@]}" "${pkgs[@]}" 2>&1 || true)"
  fi
  if grep -q 'No packages marked for removal' <<<"$plan"; then
    echo "   - tidak ada paket yang perlu dihapus"
    return 0
  fi

  local bad
  bad="$(awk '/^[[:space:]]+/ {print $1}' <<<"$plan" | grep -E "$PROTECTED_RE" | sort -u || true)"
  if [[ -n "$bad" ]]; then
    warn "TRANSAKSI DIBATALKAN - paket dilindungi ikut terhapus:"
    printf '   %s\n' "$bad"
    return 1
  fi

  if [[ "$clean" == "keepdeps" ]]; then
    dnf -y remove --setopt=clean_requirements_on_remove=False \
      "${DNF_EXCLUDES[@]}" "${pkgs[@]}"
  else
    dnf -y remove "${DNF_EXCLUDES[@]}" "${pkgs[@]}"
  fi
}

stop_user_services() {
  as_user systemctl --user stop \
    gnome-software.service rygel.service gnome-user-share-webdav.service \
    evolution-alarm-notify.service 2>/dev/null || true
  as_user pkill -u "$TARGET_USER" -f 'gnome-software --gapplication-service' 2>/dev/null || true
  as_user pkill -u "$TARGET_USER" -f 'rygel' 2>/dev/null || true
  as_user pkill -u "$TARGET_USER" -f 'gnome-user-share-webdav' 2>/dev/null || true
  as_user pkill -u "$TARGET_USER" -f 'evolution-alarm-notify' 2>/dev/null || true
}

hide_evolution_alarm() {
  [[ -n "$TARGET_HOME" ]] || return 0
  local dir="$TARGET_HOME/.config/autostart"
  local file="$dir/org.gnome.Evolution-alarm-notify.desktop"
  install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_GROUP" "$dir"
  if [[ -f "$file" ]] && ! grep -q 'X-Macos-Fedora44-Trim=true' "$file"; then
    cp -a "$file" "$file.bak-trim-$(date +%Y%m%d-%H%M%S)"
  fi
  cat > "$file" <<'EOF'
[Desktop Entry]
Type=Application
Name=Evolution Alarm Notify
Hidden=true
X-GNOME-Autostart-enabled=false
X-Macos-Fedora44-Trim=true
EOF
  chown "$TARGET_USER:$TARGET_GROUP" "$file"
  chmod 0644 "$file"
  echo "   - autostart Evolution alarm disembunyikan: $file"
}

restore_evolution_alarm() {
  [[ -n "$TARGET_HOME" ]] || return 0
  local file="$TARGET_HOME/.config/autostart/org.gnome.Evolution-alarm-notify.desktop"
  if [[ -f "$file" ]] && grep -q 'X-Macos-Fedora44-Trim=true' "$file"; then
    rm -f "$file"
    local backup
    backup="$(ls -t "$file".bak-trim-* 2>/dev/null | head -1 || true)"
    [[ -n "$backup" ]] && cp -a "$backup" "$file"
    echo "   - autostart Evolution alarm dipulihkan"
  fi
}

apply_updatedb() {
  section "updatedb: prune /mnt + fuseblk/ntfs/ntfs3"
  if grep -q '^PRUNEPATHS = ".* /mnt' /etc/updatedb.conf; then
    echo "   - PRUNEPATHS sudah memuat /mnt"
  else
    cp -a /etc/updatedb.conf "/etc/updatedb.conf.bak-trim-$(date +%Y%m%d-%H%M%S)"
    sed -i -E 's/^(PRUNEPATHS = "[^"]*)"/\1 \/mnt"/' /etc/updatedb.conf
    echo "   - /mnt ditambahkan ke PRUNEPATHS"
  fi
  local fs
  for fs in fuseblk ntfs ntfs3; do
    if grep -Eq "^PRUNEFS = \".*[[:space:]]$fs([[:space:]]|\")" /etc/updatedb.conf; then
      echo "   - PRUNEFS sudah memuat $fs"
    else
      sed -i -E "s/^(PRUNEFS = \"[^\"]*)\"/\1 $fs\"/" /etc/updatedb.conf
      echo "   - $fs ditambahkan ke PRUNEFS"
    fi
  done
  echo "   Hasil:"
  grep -E '^(PRUNEFS|PRUNEPATHS)' /etc/updatedb.conf | sed 's/^/     /'

  section "updatedb: jalankan sekali, ukur CPU/RAM"
  systemctl start plocate-updatedb.service
  systemctl show plocate-updatedb.service \
    -p CPUUsageNSec -p MemoryPeak -p ExecMainStartTimestamp -p ExecMainExitTimestamp \
    | sed 's/^/   /'
}

apply_tuned() {
  section "TuneD: profile macos-zram (swappiness=100, page-cluster=0)"
  # TuneD 2.27 (Fedora 44) memakai /etc/tuned/profiles/<nama>, bukan
  # /etc/tuned/<nama>. Pindahkan profile lama bila ada.
  local dir="/etc/tuned/profiles/macos-zram"
  local legacy="/etc/tuned/macos-zram"
  local file="$dir/tuned.conf"
  if [[ -d "$legacy" ]]; then
    if [[ -f "$legacy/tuned.conf" ]] && grep -q 'managed by trim-bloat-fedora44.sh' "$legacy/tuned.conf"; then
      install -d -m 0755 /etc/tuned/profiles
      rm -rf "$dir"
      mv "$legacy" "$dir"
      echo "   - profile lama dipindahkan ke $dir"
    else
      warn "$legacy ada tetapi bukan milik skrip - dibiarkan"
    fi
  fi
  if [[ -f "$file" ]] && grep -q 'managed by trim-bloat-fedora44.sh' "$file"; then
    echo "   - profile sudah ada"
  else
    if [[ -e "$dir" ]]; then
      cp -a "$dir" "$dir.bak-trim-$(date +%Y%m%d-%H%M%S)"
    fi
    install -d -m 0755 "$dir"
    cat > "$file" <<'EOF'
# managed by trim-bloat-fedora44.sh
# Profile anak: tetap memakai throughput-performance, lalu override sysctl
# untuk zram 3,7 GB. Ini runtime sysctl, bukan penggantian paket kernel.
[main]
summary=macOS-style zram tuning (swappiness 100, page-cluster 0)
include=throughput-performance

[sysctl]
vm.swappiness=100
vm.page-cluster=0
EOF
  fi

  # tuned-ppd memetakan PPD "performance" ke throughput-performance dan
  # menimpanya satu detik setelah tuned start. Arahkan PPD performance ke
  # profile anak ini supaya swappiness 100 bertahan setelah restart/reboot.
  local ppd="/etc/tuned/ppd.conf"
  if [[ -f "$ppd" ]]; then
    if grep -Eq '^[[:space:]]*performance[[:space:]]*=[[:space:]]*macos-zram[[:space:]]*$' "$ppd"; then
      echo "   - ppd.conf: performance sudah -> macos-zram"
    elif grep -Eq '^[[:space:]]*performance[[:space:]]*=[[:space:]]*throughput-performance[[:space:]]*$' "$ppd"; then
      cp -a "$ppd" "$ppd.bak-trim-$(date +%Y%m%d-%H%M%S)"
      sed -i -E 's|^[[:space:]]*performance[[:space:]]*=[[:space:]]*throughput-performance[[:space:]]*$|performance=macos-zram|' "$ppd"
      echo "   - ppd.conf: performance -> macos-zram"
    else
      warn "ppd.conf: baris performance tidak dikenali - tidak diubah"
    fi
  else
    warn "$ppd tidak ada - mapping PPD dilewati"
  fi

  tuned-adm profile macos-zram
  # Restart membuktikan profile bertahan; tuned-ppd ikut restart (PartOf).
  systemctl restart tuned
  sleep 2
  if ! tuned-adm active 2>&1 | grep -q 'macos-zram'; then
    warn "profile macos-zram tidak bertahan setelah restart tuned"
    return 1
  fi
  if [[ "$(sysctl -n vm.swappiness)" != "100" || "$(sysctl -n vm.page-cluster)" != "0" ]]; then
    warn "sysctl tidak sesuai setelah restart tuned"
    sysctl vm.swappiness vm.page-cluster | sed 's/^/   /'
    return 1
  fi
  echo "   - aktif setelah restart: $(tuned-adm active)"
  sysctl vm.swappiness vm.page-cluster | sed 's/^/   /'
}

apply_services() {
  section "Service startup: matikan yang tidak dipakai"
  local unit
  for unit in \
    dnf-makecache.timer \
    NetworkManager-wait-online.service \
    ModemManager.service \
    atd.service; do
    if systemctl is-enabled "$unit" >/dev/null 2>&1 || systemctl is-active "$unit" >/dev/null 2>&1; then
      systemctl disable --now "$unit" 2>/dev/null || systemctl disable "$unit" 2>/dev/null || true
      echo "   - $unit: disabled"
    else
      echo "   - $unit: sudah nonaktif"
    fi
  done
  for unit in cups.socket cups.path; do
    if systemctl is-enabled "$unit" >/dev/null 2>&1 || systemctl is-active "$unit" >/dev/null 2>&1; then
      systemctl disable --now "$unit" 2>/dev/null || true
      echo "   - $unit: disabled"
    else
      echo "   - $unit: sudah nonaktif"
    fi
  done
  systemctl stop cups.service 2>/dev/null || true
  systemctl stop dnf5daemon-server.service 2>/dev/null || true
  # packagekitd hanya diaktifkan D-Bus oleh GNOME Software yang baru dihapus.
  systemctl stop packagekit.service 2>/dev/null || true
}

apply_packages() {
  stop_user_services

  remove_pkgs "GNOME Software + dnf5daemon" default \
    gnome-software dnf5daemon-server dnf5daemon-server-polkit
  remove_pkgs "Rygel + gnome-user-share" default \
    rygel gnome-user-share
  remove_pkgs "ABRT (crash reporter)" default \
    'abrt*'
  remove_pkgs "Guest tools + RustDesk" default \
    rustdesk spice-vdagent open-vm-tools open-vm-tools-desktop virtualbox-guest-additions
  remove_pkgs "Aplikasi GNOME tidak terpakai" default \
    gnome-weather gnome-maps gnome-contacts gnome-calendar gnome-logs \
    gnome-connections simple-scan snapshot gnome-tour gnome-remote-desktop \
    gnome-user-docs evolution-ews-core evolution-ews-langpacks
  remove_pkgs "Stack virtualisasi (tanpa VM/container)" default \
    gnome-boxes podman toolbox qemu-system-x86-core edk2-ovmf
  remove_pkgs "CUPS discovery + Bluetooth printing" default \
    cups-browsed bluez-cups
  # Jangan biarkan DNF menghapus dependency bersama (LibreOffice/dnf/Java).
  remove_pkgs "Anaconda + Firefox (pertahankan dependency)" keepdeps \
    'anaconda*' firefox firefox-langpacks kdump-anaconda-addon

  stop_user_services
  # Pastikan packagekitd tidak sempat diaktifkan ulang oleh proses GNOME Software
  # yang sedang dimatikan.
  systemctl stop packagekit.service 2>/dev/null || true
}

apply_flatpak() {
  section "Flatpak: buang SDK system yatim (Platform lintas-instalasi dijaga)"
  # JANGAN pakai 'flatpak uninstall --system --unused' di sini: Flatpak bisa
  # menganggap Platform 26.08 yatim karena tidak ada app *system* yang memakainya,
  # padahal app user Photocraft membutuhkannya. Kasus ini terbukti 21 Okt 2026.
  # SDK hanya dipakai untuk build, bukan runtime, jadi aman dibuang eksplisit.
  local sdk_refs=()
  local ref
  while IFS= read -r ref; do
    [[ -n "$ref" ]] && sdk_refs+=("$ref")
  done < <(flatpak list --system --runtime --columns=ref 2>/dev/null \
    | grep -E '^org\.(freedesktop|gnome)\.Sdk(\.Locale)?/' || true)
  if [[ ${#sdk_refs[@]} -eq 0 ]]; then
    echo "   - system: tidak ada SDK yatim"
  else
    echo "   - system SDK:"
    printf '     %s\n' "${sdk_refs[@]}"
    flatpak uninstall --system -y "${sdk_refs[@]}" 2>&1 | sed 's/^/     /' || true
  fi
  echo "   - user (runtime yatim):"
  as_user flatpak uninstall --user --unused -y 2>&1 | sed 's/^/     /' || true
}

verify_after() {
  section "Verifikasi setelah pembersihan"
  echo "   - Memori:"
  free -h | sed 's/^/     /'
  echo "   - zram:"
  zramctl | sed 's/^/     /'
  echo "   - Sysctl:"
  sysctl vm.swappiness vm.page-cluster | sed 's/^/     /'
  echo "   - Service gagal:"
  systemctl --failed --no-pager | sed 's/^/     /' || true
  echo "   - Service yang dimatikan:"
  systemctl is-enabled dnf-makecache.timer NetworkManager-wait-online.service \
    ModemManager.service atd.service cups.socket cups.path 2>&1 | sed 's/^/     /' || true
  echo "   - Kernel/NVIDIA (harus tetap ada):"
  rpm -q kernel-core nvidia-gpu-firmware 2>&1 | sed 's/^/     /'
  echo "   - Paket target (harus 'not installed'):"
  for p in gnome-software rygel gnome-user-share rustdesk abrt gnome-boxes \
           podman toolbox qemu-system-x86-core firefox anaconda-core; do
    printf '     %-28s %s\n' "$p" "$(rpm -q "$p" 2>&1 | tail -1)"
  done
  if [[ -n "$TARGET_USER" ]]; then
    echo "   - Service user:"
    as_user systemctl --user is-active gnome-software.service rygel.service \
      gnome-user-share-webdav.service evolution-alarm-notify.service 2>&1 \
      | sed 's/^/     /' || true
    echo "   - Proses sisa:"
    as_user pgrep -af 'gnome-software|rygel|gnome-user-share-webdav|evolution-alarm-notify' \
      | grep -v 'pgrep -af' | sed 's/^/     /' || echo "     (tidak ada)"
  fi
  echo "   - DING / Dash to Dock / Super+D (tidak diubah):"
  if [[ -n "$TARGET_USER" ]]; then
    as_user bash -lc "gnome-extensions list --enabled 2>/dev/null | grep -E 'ding@rastersoft|dash-to-dock' || true"
    as_user bash -lc "gsettings get org.gnome.desktop.wm.keybindings show-desktop 2>/dev/null || true"
    as_user bash -lc "gsettings get org.gnome.shell.extensions.dash-to-dock intellihide 2>/dev/null || true"
  fi
}

apply_all() {
  [[ "$EUID" -eq 0 ]] || { warn "apply harus root"; exit 1; }
  local kernel_before nvidia_before
  kernel_before="$(rpm -q kernel-core)"
  nvidia_before="$(rpm -q nvidia-gpu-firmware)"
  section "Guard awal"
  echo "   - $kernel_before"
  echo "   - $nvidia_before"

  apply_updatedb
  apply_tuned
  apply_services
  apply_packages
  apply_flatpak
  hide_evolution_alarm
  stop_user_services
  as_user systemctl --user daemon-reload 2>/dev/null || true

  verify_after

  section "Guard akhir"
  if [[ "$(rpm -q kernel-core)" != "$kernel_before" ]]; then
    warn "kernel-core berubah - periksa log!"
    exit 1
  fi
  if [[ "$(rpm -q nvidia-gpu-firmware)" != "$nvidia_before" ]]; then
    warn "nvidia-gpu-firmware berubah - periksa log!"
    exit 1
  fi
  echo "   - kernel-core & nvidia-gpu-firmware tidak berubah"
  echo
  echo "Selesai. Logout/login (atau reboot) agar service user benar-benar berhenti."
  echo "Efek boot terukur setelah reboot; repo belum di-commit."
}

revert_all() {
  [[ "$EUID" -eq 0 ]] || { warn "revert harus root"; exit 1; }
  section "Revert konfigurasi updatedb"
  local backup
  backup="$(ls -t /etc/updatedb.conf.bak-trim-* 2>/dev/null | head -1 || true)"
  if [[ -n "$backup" ]]; then
    cp -a "$backup" /etc/updatedb.conf
    echo "   - dipulihkan dari $backup"
  else
    echo "   - backup tidak ditemukan; /etc/updatedb.conf dibiarkan"
  fi

  section "Revert TuneD"
  local tuned_profile ppd_backup
  for tuned_profile in /etc/tuned/profiles/macos-zram /etc/tuned/macos-zram; do
    if [[ -f "$tuned_profile/tuned.conf" ]] && \
       grep -q 'managed by trim-bloat-fedora44.sh' "$tuned_profile/tuned.conf"; then
      rm -rf "$tuned_profile"
      echo "   - profile $tuned_profile dihapus"
    fi
  done
  ppd_backup="$(ls -t /etc/tuned/ppd.conf.bak-trim-* 2>/dev/null | head -1 || true)"
  if [[ -n "$ppd_backup" ]]; then
    cp -a "$ppd_backup" /etc/tuned/ppd.conf
    echo "   - ppd.conf dipulihkan dari $ppd_backup"
  fi
  tuned-adm profile throughput-performance
  systemctl restart tuned 2>/dev/null || true
  sleep 1
  sysctl -w vm.page-cluster=3 >/dev/null 2>&1 || true
  echo "   - aktif: $(tuned-adm active); page-cluster=$(sysctl -n vm.page-cluster)"

  section "Revert service"
  systemctl enable cups.socket cups.path >/dev/null 2>&1 || true
  systemctl enable ModemManager.service atd.service dnf-makecache.timer \
    NetworkManager-wait-online.service >/dev/null 2>&1 || true
  echo "   - cups.socket/cups.path, ModemManager, atd, dnf-makecache, wait-online di-enable"
  echo "   - jalankan 'systemctl start ...' bila ingin langsung aktif"

  restore_evolution_alarm
  if [[ -n "$TARGET_USER" ]]; then
    as_user systemctl --user daemon-reload 2>/dev/null || true
  fi

  section "Paket yang perlu diinstal ulang manual (bila diinginkan)"
  cat <<'EOF'
   sudo dnf install gnome-software dnf5daemon-server dnf5daemon-server-polkit
   sudo dnf install rygel gnome-user-share
   sudo dnf install abrt abrt-cli abrt-tui
   sudo dnf install rustdesk spice-vdagent open-vm-tools open-vm-tools-desktop virtualbox-guest-additions
   sudo dnf install gnome-weather gnome-maps gnome-contacts gnome-calendar gnome-logs \
     gnome-connections simple-scan snapshot gnome-tour gnome-remote-desktop \
     gnome-user-docs evolution-ews-core evolution-ews-langpacks
   sudo dnf install gnome-boxes podman toolbox qemu-system-x86-core edk2-ovmf
   sudo dnf install cups-browsed bluez-cups
   sudo dnf install anaconda-core anaconda-tui kdump-anaconda-addon firefox firefox-langpacks
EOF
  echo "   Flatpak yang dihapus sebagai 'unused' akan diunduh ulang otomatis bila diperlukan."
}

dry_run() {
  section "Rencana (dry-run)"
  echo "updatedb: /etc/updatedb.conf -> PRUNEPATHS += /mnt; PRUNEFS += fuseblk ntfs ntfs3"
  echo "TuneD: /etc/tuned/macos-zram/tuned.conf -> include throughput-performance;"
  echo "        vm.swappiness=100; vm.page-cluster=0"
  echo "Service: dnf-makecache.timer, NetworkManager-wait-online.service,"
  echo "         ModemManager.service, atd.service, cups.socket, cups.path -> disable"
  echo "User: stop gnome-software/rygel/gnome-user-share-webdav/evolution-alarm-notify"
  echo "Autostart: ~/.config/autostart/org.gnome.Evolution-alarm-notify.desktop -> Hidden=true"
  echo
  echo "Paket yang akan dihapus (hanya yang terpasang):"
  local spec line
  for spec in \
    gnome-software dnf5daemon-server dnf5daemon-server-polkit \
    rygel gnome-user-share \
    'abrt*' \
    rustdesk spice-vdagent open-vm-tools open-vm-tools-desktop virtualbox-guest-additions \
    gnome-weather gnome-maps gnome-contacts gnome-calendar gnome-logs \
    gnome-connections simple-scan snapshot gnome-tour gnome-remote-desktop \
    gnome-user-docs evolution-ews-core evolution-ews-langpacks \
    gnome-boxes podman toolbox qemu-system-x86-core edk2-ovmf \
    cups-browsed bluez-cups \
    'anaconda*' firefox firefox-langpacks kdump-anaconda-addon; do
    while IFS= read -r line; do
      [[ -n "$line" ]] && printf '   - %s\n' "$line"
    done < <(installed_names "$spec")
  done
  echo
  echo "Flatpak: buang SDK system yatim + runtime user yatim"
  echo "         (Platform lintas-instalasi seperti Photocraft 26.08 tidak dibuang)"
  echo "Tidak akan menyentuh kernel*, nvidia*, akmod-nvidia*, kmod-nvidia*, linux-firmware*."
}

case "$MODE" in
  dry-run) dry_run ;;
  apply) apply_all ;;
  revert) revert_all ;;
  *) warn "mode tidak dikenal: $MODE"; exit 2 ;;
esac
