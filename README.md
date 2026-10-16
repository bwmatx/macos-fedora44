# MacOs-Fedora44

Backup lengkap konfigurasi tampilan **macOS Tahoe 26** untuk **Fedora 44 + GNOME Shell 50 (Wayland)**.
Semua konfigurasi bersifat **user-level** - tidak ada perubahan system-level, kernel, GRUB, maupun driver.
Restore cukup dengan `git clone` lalu ikuti langkah di bagian "Cara Restore".

---

## 1. Ringkasan Sistem

| Item | Nilai |
|---|---|
| OS | Fedora 44 Workstation |
| Desktop | GNOME Shell 50.0, sesi Wayland |
| Tema GTK / Shell | MacTahoe-Light |
| Tema Ikon | MacTahoe-light (varian MacTahoe & MacTahoe-dark juga tersedia di `icons/`) |
| Tema Kursor | MacTahoe-light |
| Mode Warna | Light only (`gtk-dark.css` dipaksa mengarah ke tampilan Light) |
| Tombol Jendela | `close,minimize,maximize` di kiri (gaya macOS) |
| Wallpaper | Big Sur |

---

## 2. Struktur Folder

```
MacOs-Fedora44/
├── README.md                  <- dokumen ini
├── themes/                    <- ~/.themes (12 varian MacTahoe, versi sudah dipatch)
├── icons/                     <- tema ikon MacTahoe 3 varian + apple-logo.svg
├── gnome-shell/
│   └── extensions/            <- 6 ekstensi user-level (AppMenu, LogoMenu, dll)
├── config/
│   ├── gtk-3.0/               <- ~/.config/gtk-3.0
│   └── gtk-4.0/               <- ~/.config/gtk-4.0 (css tema GTK4 + patch + asset)
├── scripts/
│   ├── gnome-appearance-sync.sh
│   ├── gnome-theme-switcher
│   └── org.gnome.GTK4ThemeSwitcher.desktop
├── systemd/
│   └── gnome-appearance-sync.service
├── wallpapers/
│   └── 2026-10-15-23-44-02-BigSur-wallpaper.jpg
├── dconf/
│   ├── org.gnome.ini          <- dump semua setelan /org/gnome/ (dipakai untuk restore)
│   └── full.ini               <- dump seluruh dconf (cadangan menyeluruh)
└── theme-source/              <- sumber tema MacTahoe (installer, hanya referensi)
```

---

## 3. Deskripsi Fitur

### 3.1 Tampilan top bar (GNOME Shell)

- Tinggi top bar diatur **28 px** (modifikasi langsung di `themes/MacTahoe-Light/gnome-shell/gnome-shell.css`).
- Teks top bar dipaksa **putih** pada mode light (blok CSS tambahan di akhir file gnome-shell.css).
- **Ikon action center (quick settings)** dibuat gelap (`#16181d`) dan slider putih agar kontras di panel terang.
- **Radius popup / panel menu** 24 px (via ekstensi Liquid Glass: `menu-corner-radius`, `panel-menu-corner-radius`).
- Jam dipindah posisinya oleh ekstensi **Moveclock**.

### 3.2 Menu bar gaya macOS (ektensi AppMenu)

- UUID: `appmenu@ChathurangaBW.github.io` (AppMenu v5.7.1).
- Menampilkan **nama aplikasi yang sedang fokus** (tebal) + menu **File / Edit / View / Go / Window / Help** di sebelah ikon apel.
- Sejak 16 Okt 2026: menu juga tampil di **bar monitor sekunder** (patch §3.13e).
- Memakai **menu asli aplikasi** (dbusmenu / GtkActions) bila tersedia; butuh paket `libdbusmenu`.
- Pintasan pencarian menu: **Ctrl+Space**.
- Konfigurasi: `show-os-icon=false` (ikon OS dimatikan karena sudah pakai LogoMenu), `show-user-switcher=false`, `lock-to-focused-app=true`, `hide-overview-button=false`.

### 3.3 Ikon apel (ekstensi LogoMenu)

- UUID: `logomenu@aryan_k`.
- Ikon apel di paling kiri top bar, membuka menu ala Apple.
- **Sudah dipatch**: klik kiri membuka menu (perbaikan `vfunc_event` pada `extension.js`).
- Sejak 16 Okt 2026: ikon apel juga tampil di **bar monitor sekunder** (patch §3.13d).

### 3.4 Dock (ekstensi Dash to Dock)

- UUID: `dash-to-dock@micxgx.gmail.com` (paket Fedora `gnome-shell-extension-dash-to-dock`).
- Posisi, ukuran, dan perilaku dock diatur lewat dconf (tersimpan di `dconf/org.gnome.ini`).
- Sejak 16 Okt 2026: **intelligent autohide** (`intellihide=true`, mode `FOCUS_APPLICATION_WINDOWS`) — dock tampil di desktop (tidak ada jendela menutupi) dan sembunyi otomatis hanya saat jendela aplikasi menutupi area dock; muncul lagi saat kursor menyentuh tepi bawah layar.

### 3.5 Efek kaca (Liquid Glass + Blur My Shell)

- **Liquid Glass** (`liquid-glass@thinkingcoding1231.gmail.com`): tint untuk top bar, action center, notifikasi, panel menu, dan dock.
- **Blur My Shell** (`blur-my-shell@aunetx`, paket Fedora): blur panel/top bar.
- Bar monitor sekunder ikut dapat blur (Blur My Shell) dengan geometri identik dengan bar utama lewat patch §3.13 (a/b).
- Sejak 16 Okt 2026: menu popup di bar sekunder (action center, kalender, menu aplikasi) juga mendapat kaca Liquid Glass lewat patch §3.13f.
- Kombinasi ini menggantikan ekstensi Just Perfection yang sengaja tidak dipakai (RAM mesin hanya 3.7 GB).

### 3.6 Ekstensi lain

| Ekstensi | UUID | Fungsi |
|---|---|---|
| Magnific Launcher | `magnific-launcher@gilsonf` | Launcher gaya Spotlight |
| Compiz-alike Magic Lamp | `compiz-alike-magic-lamp-effect@hermes83.github.com` | Animasi minimize efek lampu |
| Moveclock | `moveclock@kuvaus.org` | Memindah posisi jam |
| Background Logo | `background-logo@fedorahosted.org` | Logo di latar desktop (paket Fedora) |
| User Theme | `user-theme@gnome-shell-extensions.gcampax.github.com` | Memuat tema shell dari `~/.themes` |
| Top Bar All Monitors | `topbar-all-monitors@fa8i.github.io` | Top bar fungsional (Activities, jam, kalender, Quick Settings) di semua monitor |

### 3.7 Tema GTK4 + patch khusus (penting)

File aktif: `config/gtk-4.0/gtk-Light.css` (dipakai oleh semua aplikasi GTK4/libadwaita, termasuk Files/Nautilus).

Patch yang sudah diterapkan:

1. **Anti-transparansi (15 Okt 2026)** - semua `color-mix(..., transparent)` pada background window/popover/dialog/sidebar diganti warna opak, supaya tidak ada area tembus pandang yang aneh.
2. **Fix sintaks `color-mix()` (16 Okt 2026)** - 6 deklarasi border-color (baris 1302, 1319, 1328, 1352, 1369, 1378) kurang koma sehingga GTK membuang rule tersebut tiap load. Sudah ditambahkan koma.
3. **Fix dialog GNOME 50 / libadwaita 1.9 (16 Okt 2026)** - pada GNOME 50, node `dialog` membentang seluruh jendela saat modal terbuka; tema lama mengecatnya putih sehingga popup (New Folder / Properties) tampak seperti "halaman putih sendiri". Ditambahkan override di akhir file:
   ```css
   dialog {
     background: none;
     background-color: transparent;
     background-image: none;
   }
   ```

Catatan: `gtk.css` dan `gtk-dark.css` di folder ini adalah **salinan** `gtk-Light.css` (light only). Skrip sinkronisasi akan mengubahnya menjadi symlink saat mode berubah.

### 3.8 Tema shell & GTK3

- Semua varian ada di `themes/`: MacTahoe-Light, MacTahoe-Dark, Light-solid, Dark-solid, versi hdpi/xhdpi, dst.
- Versi **MacTahoe-Light** di repo ini sudah berisi semua modifikasi (top bar 28 px, teks putih, patch GTK4, dsb).
- Tema GTK3 untuk aplikasi lama ikut memakai MacTahoe-Light dari `~/.themes` yang sama.

### 3.9 Tombol jendela & pintasan

- `button-layout` = `close,minimize,maximize:` (kiri, gaya macOS "traffic lights").
- **F4** = alias buka **App Grid**.
- **Ctrl+Space** = pencarian menu AppMenu.

### 3.10 Skrip sinkronisasi light/dark otomatis

- `scripts/gnome-appearance-sync.sh` - dijalankan otomatis oleh systemd user service `gnome-appearance-sync.service` saat skema warna (toggle Dark Mode) berubah.
- Yang disinkronkan: tema GTK3, tema shell, tema ikon, kursor, symlink CSS GTK4, tint Liquid Glass (action center, notifikasi, panel menu, top bar, dock), dan kecerahan panel Blur My Shell.
- Setup ini dioptimalkan untuk **Light mode**; profil dark tetap tersedia di skrip.

### 3.11 Utility tema

- `scripts/gnome-theme-switcher` - aplikasi GTK4 (Python) untuk mengganti/mengatur tema.
- Entry .desktop: `org.gnome.GTK4ThemeSwitcher.desktop` (nama: GNOME-GTK-Theme-Setting) muncul di App Grid.

### 3.12 Wallpaper

- `wallpapers/2026-10-15-23-44-02-BigSur-wallpaper.jpg` - dipakai untuk desktop, lockscreen, dan screensaver.

### 3.13 Paritas bar monitor sekunder (patch lokal, 16 Okt 2026)

Semua patch di bawah ini membuat bar top di **monitor sekunder** (dari ekstensi Top Bar All Monitors) tampil dan berperilaku seperti bar monitor utama. Salinan yang sudah dipatch semuanya tersimpan di repo ini (`gnome-shell/extensions/` dan `themes/`).

**a. Ekstensi Top Bar All Monitors** - `gnome-shell/extensions/topbar-all-monitors@fa8i.github.io/extension.js`
- `_syncStyleClass()` meniru *style class* **dan nama/id** panel utama (`panel`), supaya seluruh CSS tema ber-selector `#panel` (tinggi 28px, teks putih, dsb.) ikut berlaku di bar sekunder.
- Setelah panel dipublikasikan, ekstensi memanggil API internal **Blur My Shell** (`blur_existing_panels()`, dibungkus try/catch) sebagai jaring pengaman agar panel sekunder ikut di-blur; jalur utama BMS (sinyal `workareas-changed`) biasanya sudah menangkapnya sendiri.

**b. Paritas geometri bar (CSS tema, rev2 16 Okt 2026)** - `themes/MacTahoe-Light/gnome-shell/gnome-shell.css`
- Blok `.topbar-all-monitors-panel-box #panel`: tinggi panel **34px full-bleed** (tanpa margin; menang spesifisitas atas rule tema `#panel { height: 28px !important }`).
- `.panel-button`: tinggi 28px + margin 3px atas/bawah; `#panelLeft`/`#panelRight`: padding sisi 10px (margin 6 + padding 4). Semua persis meniru tata letak `_applyLayout` Liquid Glass yang dipakai bar utama, sehingga posisi ikon apel, tombol kanan, dan tinggi bar terukur identik piksel.
- Latar belakang (blur gelap) kedua bar 100% dari Blur My Shell. Catatan rev2: pendekatan pill rev1 (margin 3/6 + tint putih 0.45) dibuang karena BMS memotong area blur persis sebesar persegi panel - margin membuat celah wallpaper di tepi bar yang tampak "mengambang".

**c. Moveclock** - `gnome-shell/extensions/moveclock@kuvaus.org/extension.js`
- Jam + status menu ikut dipindah ke kanan di bar sekunder; diterapkan ulang saat startup selesai / monitor berubah; dipulihkan saat disable.

**d. LogoMenu** - `gnome-shell/extensions/logomenu@aryan_k/extension.js`
- Ikon apel dipasang di tiap bar sekunder; tombol Activities tiap bar mengikuti setelan `show-activities-button` (default: disembunyikan).

**e. AppMenu** - `gnome-shell/extensions/appmenu@ChathurangaBW.github.io/`
- `menuManager.js`: `MenuManager` menerima parameter panel (default `Main.panel`) sehingga bisa dipasang di panel mana pun.
- `extension.js`: satu `MenuManager` tambahan per bar sekunder; menu disinkronkan setiap jendela fokus berganti; dibersihkan saat panel hilang / ekstensi di-disable.

**f. Liquid Glass (kaca menu bar sekunder)** - `gnome-shell/extensions/liquid-glass@thinkingcoding1231.gmail.com/` (`extension.js`, `dist/quickSettingsManager.js`, `dist/panelMenuManager.js`)
- Akar masalah: LG hanya memproses `Main.panel` (bar utama). Menu di bar sekunder adalah instance terpisah yang dibuat shell untuk tiap panel, jadi tidak pernah diproses dan tampak transparan — tema sendiri menyetel `.quick-settings { background-color: rgba(0, 0, 0, 0.01) }`; latar putih action center di bar utama datang dari kaca LG, bukan dari tema.
- **Action center (quick settings) bar sekunder di-clone persis dari bar utama**: `QuickSettingsManager` menerima parameter menu opsional, dan `SecondaryQuickSettingsSync` (kelas baru di file yang sama) membuat satu instance penuh per menu QS clone di bar sekunder. Karena membaca setelan yang sama (`quick-settings-*`), hasilnya identik dengan bar utama: tint `#ffffff` 0.45, blur 10, radius 30, expand 12, y-offset 17, animasi spring.
- **Kalender bar sekunder juga di-clone dari bar utama**: satu instance `UIManager` resep `menu-*` (tint 0.20, blur 8, radius 24, expand 12, y-offset 17) per kalender sekunder, tanpa menulis CSS accent/settled-height (itu milik instance bar utama).
- **Pemicu sync (rev3, perbaikan kasus yang sempat gagal)**: mengikuti pola `PanelMenuManager` — `child-added`/`child-removed` pada kotak panel bar utama, `startup-complete`, `monitors-changed`, `extension-state-changed` — plus 5 percobaan berjeda (1,5/3/6/12/25 dtk). Wajib begitu karena panel sekunder baru dibuat saat `startup-complete` dan box-nya baru dinamai `panelBox` setelah alokasi pertama (`_publishPanel` di Top Bar All Monitors); percobaan tunggal di awal startup selalu meleset dan keliru tidak pernah dicoba lagi.
- `PanelMenuManager` memindai panel sekunder untuk menu **selain** quick settings & kalender (menu apel, menu aplikasi, dll.) via kaca "menu ekstra" `panel-menu-*`; quick settings **dan kalender** selalu dikecualikan dari jalur itu di semua panel agar tidak dobel kaca.
- Status attach/gagal ditulis ke journal (tidak senyap): `[Liquid Glass] Kaca quick settings bar sekunder terpasang (1 menu)` dan `Kaca kalender bar sekunder terpasang (1 menu)`; bila gagal, alasannya ikut tercetak.
- Bar utama tidak diubah (blok `reserved` bar utama tetap = kalender + quick settings, hasil identik dengan aslinya).
- **Penting: patch ini baru aktif setelah logout/login** — kode ekstensi di-cache selama sesi berjalan; disable/enable saja tidak memuat ulang kode (sudah diuji).

> **Jangan update ekstensi-ekstensi ini (termasuk Liquid Glass sejak patch f) dari extensions.gnome.org tanpa re-patch** - update akan menimpa file dan patch hilang. Salinan yang sudah dipatch tersimpan di repo ini untuk restore.

### 3.14 Tema & tombol jendela untuk aplikasi Flatpak (16 Okt 2026)

Aplikasi Flatpak (sandbox) tidak otomatis ikut tema karena tiga hal: (1) `~/.themes`, `~/.local/share/icons`, dan `~/.config/dconf` tidak terlihat di dalam sandbox; (2) runtime `org.freedesktop.Platform` tidak menyediakan modul GIO `libdconfsettings.so`, sehingga GSettings di sandbox jatuh ke backend keyfile (tema kembali ke Adwaita); (3) di sandbox, `XDG_CONFIG_HOME`/`XDG_DATA_HOME` diarahkan ke `~/.var/app/<id>/...`, jadi dconf dan ikon tidak membaca lokasi standar host.

Semua perbaikan dipasang oleh `scripts/flatpak-theme-setup.sh` (idempoten, aman diulang):

- **Izin berbagi** (`flatpak override --user`): `~/.themes:ro`, `~/.local/share/icons:ro`, `~/.config/dconf:ro`, `xdg-run/dconf`, `~/.local/share/flatpak-dconf:ro`, plus `--talk-name=ca.desrt.dconf` agar penulisan setelan tetap lewat service dconf host.
- **Modul dconf untuk sandbox**: `libdconfsettings.so` + `libdconf.so.1` disalin dari bundel Brave (dibangun untuk runtime 25.08 yang sama) ke `~/.local/share/flatpak-dconf/`, lalu diaktifkan lewat `GIO_EXTRA_MODULES` + `LD_LIBRARY_PATH`; fallback salinan paket dconf host (`/usr/lib64`).
- **Symlink per aplikasi** di `~/.var/app/<id>/`: `config/dconf -> ~/.config/dconf` dan `data/icons -> ~/.local/share/icons` (menyiasati redirect XDG di atas).

**Hasil (terverifikasi)** - `gsettings` di dalam sandbox wordcraft/photocraft/gridcraft mengembalikan `gtk-theme=MacTahoe-Light`, `icon-theme=MacTahoe-light`, `button-layout=close,minimize,maximize:`. Aplikasi GTK Flatpak ikut tema, ikon, kursor, dan tombol mac di kiri, dan tetap sinkron terang/gelap karena membaca dconf host secara langsung (tanpa salin). Catatan: `com.brave.Browser` tidak diberi symlink dconf karena Brave sudah membawa modul dconf sendiri dan membaca dconf host - jangan diubah.

**Batasan**: aplikasi yang menggambar kontrol jendelanya sendiri tidak bisa ikut tema sistem. Suite Storyteller (wordcraft/photocraft/gridcraft) berbasis egui - tombol jendelanya UI internal aplikasi (di luar jangkauan tema GTK; sudah dibuktikan lewat tangkapan layar). Untuk Brave: agar frame jendela memakai tombol mac, aktifkan **Settings -> Appearance -> "Use system title bar and borders"** lalu restart Brave.

```bash
bash scripts/flatpak-theme-setup.sh   # pasang ulang (idempoten)

# membongkar (kembali ke default Flatpak):
flatpak override --user --reset
rm -f ~/.var/app/*/config/dconf ~/.var/app/*/data/icons
rm -rf ~/.local/share/flatpak-dconf
```

### 3.15 Ikon desktop ala Windows: Desktop Icons NG / DING (17 Okt 2026)

GNOME/Fedora tidak punya ikon desktop bawaan. Solusinya ekstensi **Desktop Icons NG (DING)** - ekstensi yang sama dipakai Ubuntu secara default. Fedora 44 tidak memaketkannya, jadi dipasang dari extensions.gnome.org: **GNOME 50 -> DING v99** (`version_tag=75576`).

Yang didapat: file dengan ekstensi apa pun (gambar, PDF, dokumen, arsip) tampil di desktop dan dobel-klik membuka dengan aplikasi default; shortcut aplikasi (`.desktop`) tampil beserta ikonnya; folder Home dan Trash ikut tampil (ikon drive/HDD sengaja dimatikan); klik-kanan menyediakan **New Folder**, Rename, Properties, dan menu desktop lainnya.

- **Penting (temuan saat pemasangan)**: menaruh folder ekstensi langsung ke `~/.local/share/gnome-shell/extensions/` **tidak cukup pada sesi yang sedang berjalan** - shell GNOME 50 tidak memindai folder ekstensi baru (`gnome-extensions enable` gagal dengan "does not exist"). Cara yang terbukti berhasil tanpa logout: minta shell mendaftarkan sendiri lewat D-Bus (mekanisme yang sama dengan tombol install di extensions.gnome.org):
  ```bash
  gdbus call --session --dest org.gnome.Shell.Extensions \
    --object-path /org/gnome/Shell/Extensions \
    --method org.gnome.Shell.Extensions.InstallRemoteExtension "ding@rastersoft.com"
  ```
  Setelah itu `gnome-extensions enable ding@rastersoft.com` berhasil. Alternatif paling sederhana: logout lalu login sekali.
- **Shortcut aplikasi**: `bash scripts/buat-shortcut-desktop.sh brave` (tanpa argumen = daftar aplikasi yang bisa dipilih). Skrip menyalin `.desktop` ke `~/Desktop`, `chmod 755`, dan menandai `metadata::trusted=true` - syarat GNOME/DING agar shortcut hasil salinan boleh diluncurkan (di kode DING: `app/fileItem.js` membaca atribut `metadata::trusted`). Yang sudah dipasang di desktop: **Brave**, **Files (Nautilus)**, **Terminal (Ptyxis)**.
- **Preferensi DING** (ukuran ikon, warna teks label, urutan, tampil/tidaknya Home/Trash/drive): aplikasi **Extensions -> Desktop Icons NG (DING) -> Preferences**. Lewat CLI perlu `GSETTINGS_SCHEMA_DIR` karena skema ekstensi tidak terpasang di jalur standar:
  ```bash
  GSETTINGS_SCHEMA_DIR=~/.local/share/gnome-shell/extensions/ding@rastersoft.com/schemas \
    gsettings list-recursively org.gnome.shell.extensions.ding
  ```
  Setelan awal (dipasang skrip): `show-home`/`show-trash=true`, `show-volumes=false` (ikon HDD/drive tidak tampil), `start-corner=top-left`, `arrangeorder=NAME`, `icon-size=standard`.
- Salinan ekstensi tersimpan di repo (`gnome-shell/extensions/ding@rastersoft.com/`) supaya restore tidak mengunduh ulang; pasang ulang semuanya: `bash scripts/desktop-icons-setup.sh` (idempoten). Kalau DING pernah di-update dari EGO, perbarui juga salinan di repo dengan menyalin ulang folder ekstensinya.
- **Bongkar**: `gnome-extensions uninstall ding@rastersoft.com` (logout/login bila perlu); shortcut di `~/Desktop` aman dihapus manual.

### 3.16 Stabilitas & penghematan beban (17 Okt 2026)

Diagnosis beku 17 Okt ~03:10 (boot sebelum reboot): layar diam total **tetapi kursor masih bisa bergerak** - khas hang jalur grafis/kompositor, bukan OOM/kernel panic (tidak ada OOM-kill, panic, atau softlockup di jurnal; jurnal berhenti mendadak lalu daya dipotong). Konteks mesin: RAM 3,7 GiB + iGPU HD 620 + i3-7020U (2 core/4 thread); sesaat sebelum beku jurnal mencatat `libinput ... your system is too slow`; shell juga pernah SIGSEGV (16 Okt 17:18). Insiden terjadi saat membuka App Grid lewat **F4** (pintasan `toggle-application-view=['<Super>a','F4']`, lihat §3.9).

Tindakan yang dipasang - idempoten lewat `bash scripts/stabilitas-setup.sh` (bagian root memakai pkexec, muncul dialog password):

- **RustDesk dinonaktifkan total** (`systemctl disable --now rustdesk`) - laptop ini bukan target remote (yang rutin di-remote = PC). Alasan kuat: `nouveau` mencatat **1.789 baris error `fifo: PBDMA0`** (semuanya di channel proses rustdesk) + 16 `gr: TRAP` dalam satu boot; RustDesk merender lewat renderD128 (NVIDIA/nouveau) yang bermasalah di mesin ini. Aktifkan kembali bila perlu: `sudo systemctl enable --now rustdesk`.
- **Blur My Shell dikurangi di jalur berat yang jarang dipakai**: `overview blur=false` (latar Overview/App Grid - jalur beku) dan `appfolder blur=false`. **Tetap ON**: `panel` (top bar), `lockscreen`, `coverflow-alt-tab`; `applications` (blur jendela) dan `dash-to-dock` memang sudah OFF sebelumnya.
- **SysRq darurat (REISUB)**: `/etc/sysctl.d/99-sysrq-reisub.conf` -> `kernel.sysrq=1` (sebelumnya 16 = hanya sync). Kalau beku lagi: **Alt+SysRq+R E I S U B** (reboot aman, tanpa power button), atau coba Ctrl+Alt+F3 dulu.

Hasil uji pasca-mitigasi (17 Okt ~04:10): App Grid lewat **F4** (jalur yang memicu beku) dibuka ulang - **aman, tidak beku**. Jurnal boot berjalan bersih dari penanda hang: 0 `libinput ... too slow`, 0 SIGSEGV, 0 OOM-kill, 0 soft lockup; banjir error `nouveau fifo: PBDMA0` juga berhenti total sejak RustDesk dinonaktifkan (1.789 baris semuanya tumpah hanya dalam 1 menit, 03:12:27-03:12:28, saat RustDesk masih hidup; nol error setelah `Stopped rustdesk` 03:27:52).

Temuan lain (belum diubah, menunggu keputusan): `gnome-software` memakai CPU ~5% terus setelah boot; **±6 detik pertama log boot menampilkan jam +7 jam** karena kernel membaca RTC (yang berisi waktu lokal) sebagai UTC - lalu systemd menerapkan koreksi -420 menit dan chronyd sinkron sehingga jam akhirnya benar (`RTC in local TZ: yes`, efek dual-boot Windows; perbaikan permanen opsional: `timedatectl set-local-rtc 0` + Windows disetel RTC=UTC); `glycin-svg` (loader thumbnail GNOME) pernah crash berulang; repo di partisi NTFS (`ntfs-3g`) berat CPU saat operasi git; `swappiness` zram masih 10.

### 3.17 Fix flicker ikon desktop (DING) saat pointer masuk dock (17 Okt 2026)

Gejala: saat pointer menyentuh/menyusuri dock, ikon-ikon desktop berkedip cepat "terbuka-tertutup" selama hover. Root cause (terbukti dari kode + rekaman D-Bus, bukan dugaan):

1. **Dash-to-Dock v105** (`docking.js` -> `_updateVisibleDesktop()`) mengirim tinggi/lebar box dock ke DING pada setiap perubahan allocation/animasi. Saat hover (animasi tooltip/window preview), nilainya transien dan pecahan - rekaman `dbus-monitor` memperlihatkan `marginBottom` bergoyang `80.0` <-> `~104.29` <-> `~130.7` (termasuk nilai pecahan 100.194, 101.58, ...) lalu kembali `80.0` saat pointer menjauh.
2. **DING** (`app/desktopManager.js` -> `updateGridWindows()`) me-rebuild SELURUH grid ikon desktop bila ada selisih margin sekecil apa pun, termasuk beda pecahan. Bukti jurnal: 168 kali `"Creating desktop index 0"` dalam 1 jam; puncaknya 52 kali dalam semenit (03:42) saat dock disentuh.

**Temuan penting (jebakan verifikasi):** GNOME Shell 50 **meng-cache modul JS ekstensi selama sesi berjalan** (`extensionSystem.js`: `import()` tanpa cache-buster + komentar resmi "The extension is now cached and it's impossible to load a different version"). Artinya `disable`/`enable` ekstensi **tidak** memuat file baru dari disk - hanya **logout/login** yang membongkar cache. Konsekuensinya: patch percobaan pertama (v1) tidak pernah benar-benar aktif saat diuji ~04:00 (sesi masih menjalankan kode lama dari login 03:12), dan rekaman "0 sinyal" waktu itu tidak sah karena tidak ada hover yang benar-benar terjadi. Semua angka verifikasi di bawah diambil ulang setelah logout/login dengan rekaman live.

Perbaikan final (v2) - patch kecil di file sistem dash-to-dock (`/usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/docking.js`), DING tidak disentuh sama sekali:

- `_updateVisibleDesktop()`: (1) **hover-gate** - margin tidak dikirim selagi pointer ada di atas dock; (2) **settle 300 ms** - `GLib.timeout_add` yang di-reset oleh setiap pemicu transien, jadi hanya nilai yang sudah benar-benar diam yang lolos; (3) `Math.round()` tinggi/lebar (piksel utuh); (4) guard `try/catch` saat dock sedang dibongkar. Nilai diam yang sama dengan sebelumnya tetap tidak memicu rebuild di DING.
- Pasang/ulang: `pkexec bash scripts/fix-ding-dock-flicker.sh` - idempoten (deteksi tag `_mfSettleTimeoutId`), backup otomatis sekali ke `docking.js.d2d-orig`, ada mode `--revert`. **Setelah skrip dijalankan wajib logout/login** (disable/enable tidak cukup - lihat temuan di atas). **Jalankan ulang setiap kali paket `gnome-shell-extension-dash-to-dock` di-update** (`dnf update`), lalu logout/login lagi.

Verifikasi final (17 Okt 04:53-04:56, sesi baru setelah logout/login): sesi baru memuat kode v2 (PID shell berganti); uji hover nyata ~79 detik (zoom masuk/keluar 6-8x, diam di ikon ber-preview, buka/tutup aplikasi) -> **0 sinyal pada path DING** di rekaman `dbus-monitor` dan **0 kali `"Creating desktop index"`** di jurnal. Pembanding sebelum patch (sesi lama): 9 sinyal + 9 rebuild hanya dalam ~23 detik hover. Tooltip, window preview, dan intellihide tetap berjalan normal. Catatan: versi upstream terbaru (v110) masih memakai pengiriman nilai live yang sama, jadi upgrade paket bukan solusi - patch ini yang menutup celah.

---

## 4. Cara Restore (pakai git clone)

### Langkah 0 - Dependensi (sekali saja)

```bash
sudo dnf install gnome-shell-extension-user-theme \
                 gnome-shell-extension-background-logo \
                 gnome-shell-extension-dash-to-dock \
                 gnome-shell-extension-blur-my-shell \
                 libdbusmenu
```

(Paket `libdbusmenu` dibutuhkan AppMenu untuk menu aplikasi asli. `python3-gi` + `gtk4` biasanya sudah terpasang di Fedora Workstation, dibutuhkan oleh gnome-theme-switcher.)

### Langkah 1 - Clone

```bash
git clone <URL-REPO-ANDA> ~/MacOs-Fedora44
cd ~/MacOs-Fedora44
```

### Langkah 2 - Copy tema, ikon, ekstensi

```bash
mkdir -p ~/.themes ~/.local/share/icons ~/.local/share/gnome-shell/extensions
cp -a themes/. ~/.themes/
cp -a icons/. ~/.local/share/icons/
cp -a gnome-shell/extensions/. ~/.local/share/gnome-shell/extensions/
```

### Langkah 3 - Copy konfigurasi GTK

```bash
mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0
cp -a config/gtk-3.0/. ~/.config/gtk-3.0/
cp -a config/gtk-4.0/. ~/.config/gtk-4.0/
```

### Langkah 4 - Script, service, dan utility

```bash
mkdir -p ~/.local/bin ~/.config/systemd/user ~/.local/share/applications
cp -a scripts/gnome-appearance-sync.sh scripts/gnome-theme-switcher ~/.local/bin/
chmod +x ~/.local/bin/gnome-appearance-sync.sh ~/.local/bin/gnome-theme-switcher
cp -a scripts/org.gnome.GTK4ThemeSwitcher.desktop ~/.local/share/applications/
cp -a systemd/gnome-appearance-sync.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable gnome-appearance-sync.service
```

### Langkah 5 - Wallpaper

```bash
mkdir -p ~/.local/share/backgrounds
cp -a wallpapers/2026-10-15-23-44-02-BigSur-wallpaper.jpg ~/.local/share/backgrounds/
```

### Langkah 6 - Setelan dconf (semua setting GNOME)

Jika username Anda **bukan** `adhiwibowo`, ganti dulu path di file dump:

```bash
sed -i "s|/home/adhiwibowo|$HOME|g" dconf/org.gnome.ini dconf/full.ini
```

Lalu muat setelannya:

```bash
dconf load /org/gnome/ < dconf/org.gnome.ini
```

Alternatif (menimpa seluruh dconf): `dconf load / < dconf/full.ini`.

### Langkah 7 - Restart & login ulang

```bash
nautilus -q        # restart Files agar CSS GTK4 baru termuat
```

**Logout lalu login kembali** - tema shell, ekstensi user-level (AppMenu, LogoMenu, dll), dan service baru aktif setelah login ulang.

### Verifikasi

```bash
gnome-extensions list --enabled | sort
gsettings get org.gnome.shell.extensions.user-theme name      # harus: 'MacTahoe-Light'
gsettings get org.gnome.desktop.interface gtk-theme           # harus: 'MacTahoe-Light'
gsettings get org.gnome.desktop.interface icon-theme          # harus: 'MacTahoe-light'
gsettings get org.gnome.desktop.interface cursor-theme        # harus: 'MacTahoe-light'
gsettings get org.gnome.desktop.wm.preferences button-layout  # harus: 'close,minimize,maximize:'
```

---

## 5. Catatan

- Semua berkas bersifat user-level; tidak perlu sudo untuk restore (sudo hanya untuk install paket dnf).
- Folder `theme-source/` adalah salinan sumber tema MacTahoe (dari upstream) untuk referensi. **Jangan jalankan `install.sh` di dalamnya** kecuali ingin mereset ke versi upstream - folder `themes/` sudah berisi versi yang dipatch.
- Backup internal (`.bak-*`) disertakan di `config/gtk-4.0/` dan `themes/` agar riwayat patch dapat dilacak.
- Ukuran repo didominasi tema ikon (3 varian, lebih dari 20 ribu berkas). Jika ingin repo lebih ringan, folder `icons/MacTahoe` dan `icons/MacTahoe-dark` boleh dihapus (yang aktif hanya `MacTahoe-light`).
- Jika wallpaper tampil polos setelah restore, set ulang manual:
  ```bash
  gsettings set org.gnome.desktop.background picture-uri "file://$HOME/.local/share/backgrounds/2026-10-15-23-44-02-BigSur-wallpaper.jpg"
  gsettings set org.gnome.desktop.background picture-uri-dark "file://$HOME/.local/share/backgrounds/2026-10-15-23-44-02-BigSur-wallpaper.jpg"
  gsettings set org.gnome.desktop.screensaver picture-uri "file://$HOME/.local/share/backgrounds/2026-10-15-23-44-02-BigSur-wallpaper.jpg"
  ```

---

## 6. Kredit / Sumber Upstream

| Komponen | Sumber |
|---|---|
| Tema GTK/Shell MacTahoe | github.com/vinceliuice/MacTahoe-gtk-theme |
| Tema ikon & kursor MacTahoe | github.com/vinceliuice/MacTahoe-icon-theme |
| AppMenu | github.com/ChathurangaBW/AppMenu |
| LogoMenu | extensions.gnome.org (uuid `logomenu@aryan_k`) |
| Liquid Glass | extensions.gnome.org (uuid `liquid-glass@thinkingcoding1231.gmail.com`) |
| Magnific Launcher | extensions.gnome.org (uuid `magnific-launcher@gilsonf`) |
| Moveclock | extensions.gnome.org (uuid `moveclock@kuvaus.org`) |
| Compiz-alike Magic Lamp | extensions.gnome.org (uuid `compiz-alike-magic-lamp-effect@hermes83.github.com`) |
| Blur My Shell | github.com/aunetx/blur-my-shell (paket Fedora) |
| Dash to Dock | github.com/micheleg/dash-to-dock (paket Fedora) |
| Desktop Icons NG (DING) | extensions.gnome.org (uuid `ding@rastersoft.com`) - gitlab.com/rastersoft/desktop-icons-ng |

---

## 7. Riwayat Patch (Changelog)

| Tanggal | Perubahan |
|---|---|
| 15 Okt 2026 | Pemasangan tema MacTahoe (GTK3/GTK4/Shell), ikon, kursor, dock, jam, tombol jendela kiri |
| 15 Okt 2026 | Patch anti-transparansi pada CSS GTK4 |
| 15 Okt 2026 | Wallpaper Big Sur + skrip sinkronisasi light/dark + systemd service |
| 16 Okt 2026 | Pemasangan AppMenu v5.7.1 (menu bar macOS di top bar) |
| 16 Okt 2026 | Patch LogoMenu (klik membuka menu) |
| 16 Okt 2026 | Top bar 28 px + teks putih + ikon action center gelap |
| 16 Okt 2026 | Fix sintaks `color-mix()` (6 error parser GTK4) |
| 16 Okt 2026 | Fix dialog Files/Nautilus di GNOME 50 (dialog overlay transparan, popup jadi kartu melayang) |
| 16 Okt 2026 | Top bar tampil di semua monitor (ekstensi Top Bar All Monitors) |
| 16 Okt 2026 | Patch Top Bar All Monitors: gaya tema (#panel) ikut berlaku di bar monitor sekunder |
| 16 Okt 2026 | Bar monitor sekunder: patch Moveclock (jam ke kanan), LogoMenu (ikon apel), AppMenu (menu bar) |
| 16 Okt 2026 | Bar monitor sekunder rev2: geometri paritas penuh (panel full-bleed 34px, tombol 28px + margin 3, padding sisi 10px) + pemicu blur Blur My Shell |
| 16 Okt 2026 | Patch Liquid Glass: action center bar monitor sekunder di-clone identik dari bar utama (`QuickSettingsManager` satu instance per menu) + menu lain via pemindaian semua panel (aktif setelah logout/login) |
| 16 Okt 2026 | Bar monitor sekunder rev3 (fix): pemicu clone Liquid Glass mengikuti PanelMenuManager + 5 percobaan berjeda — panel sekunder baru dinamai `panelBox` setelah alokasi pertama, sehingga percobaan tunggal awal startup selalu meleset; kalender sekunder kini di-clone resep `menu-*`; QS + kalender dikecualikan dari jalur menu ekstra di semua panel; status attach ditulis ke journal (aktif setelah logout/login) |
| 16 Okt 2026 | Dock: intelligent autohide — tampil di desktop, sembunyi hanya saat jendela aplikasi menutupi area dock (`intellihide=true`, mode `FOCUS_APPLICATION_WINDOWS`) |
| 16 Okt 2026 | Tema & tombol Flatpak seragam: izin berbagi tema/ikon/dconf (`override --user`), modul dconf sandbox di `~/.local/share/flatpak-dconf` (salinan bundel Brave + fallback host), symlink dconf/ikon per aplikasi - aplikasi GTK Flatpak ikut MacTahoe (verbatim dconf host). Catatan: suite Storyteller (egui) menggambar tombol sendiri; Brave perlu "Use system title bar and borders" |
| 17 Okt 2026 | Ikon desktop ala Windows: DING v99 (GNOME 50) aktif - file ekstensi apa pun tampil & terbuka dari desktop, shortcut aplikasi (Brave/Files/Terminal) via `buat-shortcut-desktop.sh` + trust `metadata::trusted`; catatan: shell GNOME 50 tidak memindai folder ekstensi baru saat sesi berjalan (perlu `InstallRemoteExtension` via D-Bus, terbukti berhasil, atau logout) |
| 17 Okt 2026 | Stabilitas & mitigasi beku (17 Okt 03:10 - layar diam tapi kursor masih bisa bergerak): RustDesk `disable --now` (sumber 1.789 error `nouveau fifo: PBDMA0` pada boot tersebut; laptop ini bukan target remote), blur Blur My Shell jalur berat OFF (`overview` = latar App Grid/Overview + `appfolder`; top bar/lockscreen/alt-tab tetap ON), SysRq `kernel.sysrq=1` via `config/sysctl.d/99-sysrq-reisub.conf` (REISUB darurat pengganti power button) - semua idempoten lewat `scripts/stabilitas-setup.sh` |
| 17 Okt 2026 | Fix flicker ikon desktop (DING) saat pointer masuk dock (v2): patch dash-to-dock v105 `_updateVisibleDesktop()` - hover-gate + nilai "diam" 300 ms (timer reset-able) + `Math.round` + guard try/catch; DING tidak disentuh. Skrip idempoten `scripts/fix-ding-dock-flicker.sh` (backup `docking.js.d2d-orig`, ada `--revert`; jalankan ulang setelah `dnf update` dash-to-dock). **Wajib logout/login** - Shell 50 meng-cache modul JS selama sesi berjalan (disable/enable tidak memuat ulang; patch v1 sempat tidak aktif karena jebakan ini). Verifikasi final di sesi baru: uji hover ~79 dtk -> 0 sinyal D-Bus & 0 rebuild grid (sebelumnya 9 sinyal + 9 rebuild dalam ~23 dtk) |
| 17 Okt 2026 | Verifikasi pasca-mitigasi beku: App Grid via F4 dibuka ulang -> aman (tidak beku lagi); jurnal boot bersih dari penanda hang (0 `libinput too slow`, 0 SIGSEGV, 0 OOM, 0 soft lockup) & banjir `nouveau fifo: PBDMA0` berhenti total sejak RustDesk dinonaktifkan (1.789 error semuanya dalam 1 menit saat RustDesk masih hidup) |
# macos-fedora44

**© 2026 Adhiwibowo** - Portofolio: [adhiwibowo.my.id](https://adhiwibowo.my.id)

Lisensi: [GPL-3.0](LICENSE). Komponen pihak ketiga yang ikut disalin (ekstensi GNOME, tema, ikon) tetap mengikuti lisensi aslinya masing-masing.
