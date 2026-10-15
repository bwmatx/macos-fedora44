#!/usr/bin/env bash
# gnome-appearance-sync.sh
# Applies a full light/dark appearance profile whenever the GNOME
# colour scheme changes (e.g. the Dark Mode toggle in Quick Settings).
#
# Profiles cover everything that does not follow color-scheme by itself:
#   - GTK3 theme, shell theme (user-theme), icon theme, cursor theme,
#     GTK4 css symlinks
#   - Liquid Glass tints (action center, notifications, panel menus,
#     top bar, dock) - LG only has one tint per component, not per mode
#   - Blur-My-Shell panel brightness (neutral in light, darkened in dark)

LG_SCHEMA_DIR="$HOME/.local/share/gnome-shell/extensions/liquid-glass@thinkingcoding1231.gmail.com/schemas"
LG="org.gnome.shell.extensions.liquid-glass@thinkingcoding1231.gmail.com"
GTK4_DIR="$HOME/.config/gtk-4.0"
BMS_PANEL="org.gnome.shell.extensions.blur-my-shell.panel"

lg() { gsettings --schemadir "$LG_SCHEMA_DIR" set "$LG" "$@"; }

set_light() {
    gsettings set org.gnome.desktop.interface gtk-theme 'MacTahoe-Light'
    gsettings set org.gnome.desktop.interface icon-theme 'MacTahoe-light'
    gsettings set org.gnome.desktop.interface cursor-theme 'MacTahoe-light'
    gsettings set org.gnome.shell.extensions.user-theme name 'MacTahoe-Light'
    ln -sfn "$GTK4_DIR/gtk-Light.css" "$GTK4_DIR/gtk.css"
    ln -sfn "$GTK4_DIR/gtk-Light.css" "$GTK4_DIR/gtk-dark.css"

    lg quick-settings-tint-color "'#ffffff'"
    lg quick-settings-tint-strength 0.45
    lg notification-tint-color "'#ffffff'"
    lg notification-tint-strength 0.40
    lg panel-menu-tint-color "'#ffffff'"
    lg panel-menu-tint-strength 0.40
    lg top-bar-tint-color "'#ffffff'"
    lg top-bar-tint-strength 0.45
    # Milky dock so it reads as light glass, not the dark wallpaper behind it
    lg dock-tint-color "'#ffffff'"
    lg dock-tint-strength 0.45

    for k in quick-settings notification panel-menu top-bar; do
        lg "$k-adaptive-text-preference" "'dark'"
    done

    gsettings set "$BMS_PANEL" brightness 1.0
}

set_dark() {
    gsettings set org.gnome.desktop.interface gtk-theme 'MacTahoe-Dark'
    gsettings set org.gnome.desktop.interface icon-theme 'MacTahoe-dark'
    gsettings set org.gnome.desktop.interface cursor-theme 'MacTahoe-dark'
    gsettings set org.gnome.shell.extensions.user-theme name 'MacTahoe-Dark'
    ln -sfn "$GTK4_DIR/gtk-Dark.css" "$GTK4_DIR/gtk.css"
    ln -sfn "$GTK4_DIR/gtk-Dark.css" "$GTK4_DIR/gtk-dark.css"

    lg quick-settings-tint-color "'#0d0d14'"
    lg quick-settings-tint-strength 0.45
    lg notification-tint-color "'#0d0d14'"
    lg notification-tint-strength 0.40
    lg panel-menu-tint-color "'#0d0d14'"
    lg panel-menu-tint-strength 0.40
    lg top-bar-tint-color "'#0d0d14'"
    lg top-bar-tint-strength 0.35
    lg dock-tint-color "'#0d0d14'"
    lg dock-tint-strength 0.40

    for k in quick-settings notification panel-menu top-bar; do
        lg "$k-adaptive-text-preference" "'light'"
    done

    gsettings set "$BMS_PANEL" brightness 0.6
}

apply() {
    local scheme
    scheme=$(gsettings get org.gnome.desktop.interface color-scheme | tr -d "'")
    if [ "$scheme" = "prefer-dark" ]; then
        set_dark
    else
        set_light   # 'default' and 'prefer-light' are both light
    fi
}

# Apply once at startup, then re-apply on every change.
apply
gsettings monitor org.gnome.desktop.interface color-scheme | while read -r _; do
    apply
done
