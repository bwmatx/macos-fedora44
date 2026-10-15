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
- Memakai **menu asli aplikasi** (dbusmenu / GtkActions) bila tersedia; butuh paket `libdbusmenu`.
- Pintasan pencarian menu: **Ctrl+Space**.
- Konfigurasi: `show-os-icon=false` (ikon OS dimatikan karena sudah pakai LogoMenu), `show-user-switcher=false`, `lock-to-focused-app=true`, `hide-overview-button=false`.

### 3.3 Ikon apel (ekstensi LogoMenu)

- UUID: `logomenu@aryan_k`.
- Ikon apel di paling kiri top bar, membuka menu ala Apple.
- **Sudah dipatch**: klik kiri membuka menu (perbaikan `vfunc_event` pada `extension.js`).

### 3.4 Dock (ekstensi Dash to Dock)

- UUID: `dash-to-dock@micxgx.gmail.com` (paket Fedora `gnome-shell-extension-dash-to-dock`).
- Posisi, ukuran, dan perilaku dock diatur lewat dconf (tersimpan di `dconf/org.gnome.ini`).

### 3.5 Efek kaca (Liquid Glass + Blur My Shell)

- **Liquid Glass** (`liquid-glass@thinkingcoding1231.gmail.com`): tint untuk top bar, action center, notifikasi, panel menu, dan dock.
- **Blur My Shell** (`blur-my-shell@aunetx`, paket Fedora): blur panel/top bar.
- Kombinasi ini menggantikan ekstensi Just Perfection yang sengaja tidak dipakai (RAM mesin hanya 3.7 GB).

### 3.6 Ekstensi lain

| Ekstensi | UUID | Fungsi |
|---|---|---|
| Magnific Launcher | `magnific-launcher@gilsonf` | Launcher gaya Spotlight |
| Compiz-alike Magic Lamp | `compiz-alike-magic-lamp-effect@hermes83.github.com` | Animasi minimize efek lampu |
| Moveclock | `moveclock@kuvaus.org` | Memindah posisi jam |
| Background Logo | `background-logo@fedorahosted.org` | Logo di latar desktop (paket Fedora) |
| User Theme | `user-theme@gnome-shell-extensions.gcampax.github.com` | Memuat tema shell dari `~/.themes` |

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
# macos-fedora44
