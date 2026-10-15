// Copyright (C) 2024 kuvaus
// Licence: GPLv3
//
// PATCH LOKAL (2026-10-16, bwmatx/macos-fedora44):
// Susunan yang sama (dateMenu/jam & status menu pindah ke kanan) kini
// diterapkan juga ke bar top monitor sekunder buatan ekstensi
// "Top Bar All Monitors". Tambahan: penerapan ulang otomatis saat
// startup selesai / monitor berubah, dan pemulihan untuk semua panel
// saat disable.

import GLib from 'gi://GLib';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class MoveClockAndStatusMenu extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._clockBeforeStatusMenu = this._settings.get_boolean('clock-before-statusmenu');
        this._idleId = 0;

        // Panel sekunder bisa belum ada saat enable(); terapkan lagi setelah
        // sesi selesai start dan setiap kali tata letak monitor berubah.
        Main.layoutManager.connectObject(
            'startup-complete', () => this._scheduleApply(),
            'monitors-changed', () => this._scheduleApply(),
            this
        );

        this._scheduleApply();
    }

    disable() {
        Main.layoutManager.disconnectObject(this);

        if (this._idleId) {
            GLib.Source.remove(this._idleId);
            this._idleId = 0;
        }

        this._restorePanel(Main.panel);

        for (const panel of this._findSecondaryPanels())
            this._restorePanel(panel);

        this._settings = null;
    }

    _scheduleApply() {
        if (this._idleId)
            return;

        // Tunggu satu putaran idle: panel sekunder baru dipublikasikan
        // (nama "panelBox") beberapa idle setelah dibuat.
        this._idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._idleId = 0;

            this._applyPanel(Main.panel);

            for (const panel of this._findSecondaryPanels())
                this._applyPanel(panel);

            return GLib.SOURCE_REMOVE;
        });
    }

    _findSecondaryPanels() {
        const panels = [];

        for (const actor of Main.layoutManager.uiGroup.get_children()) {
            const name = actor.get_name();
            if (name !== 'panelBox' && name !== 'topbarAllMonitorsPanelBox')
                continue;

            // Cari aktor panel di dalam box (setelah di-blur BMS, box berisi
            // 2 anak: grup background blur + panel).
            for (const child of actor.get_children()) {
                if (child === Main.panel)
                    continue;
                if (child.statusArea && child._centerBox && child._rightBox) {
                    panels.push(child);
                    break;
                }
            }
        }

        return panels;
    }

    _applyPanel(panel) {
        const centerBox = panel?._centerBox;
        const rightBox = panel?._rightBox;
        const dateMenu = panel?.statusArea?.['dateMenu'];
        const statusMenu = panel?.statusArea?.['quickSettings'];

        if (!centerBox || !rightBox || !dateMenu || !statusMenu)
            return;

        // Pindahkan dateMenu (jam) dari centerBox ke rightBox.
        if (dateMenu.container.get_parent() === centerBox) {
            centerBox.remove_child(dateMenu.container);

            if (!this._clockBeforeStatusMenu) {
                // Setelah status menu (paling kanan).
                rightBox.add_child(dateMenu.container);
            } else {
                // Tepat sebelum status menu.
                rightBox.insert_child_at_index(dateMenu.container,
                    Math.max(0, rightBox.get_children().length - 1));
            }
        }

        // Pindahkan status menu tepat sebelum jam (bila sebelumnya di centerBox).
        if (!this._clockBeforeStatusMenu && statusMenu.container.get_parent() === centerBox) {
            centerBox.remove_child(statusMenu.container);
            rightBox.insert_child_at_index(statusMenu.container,
                Math.max(0, rightBox.get_children().length - 1));
        }
    }

    _restorePanel(panel) {
        const centerBox = panel?._centerBox;
        const rightBox = panel?._rightBox;
        const dateMenu = panel?.statusArea?.['dateMenu'];
        const statusMenu = panel?.statusArea?.['quickSettings'];

        if (!centerBox || !rightBox || !dateMenu || !statusMenu)
            return;

        // Kembalikan jam ke centerBox.
        if (dateMenu.container.get_parent() === rightBox) {
            rightBox.remove_child(dateMenu.container);
            centerBox.add_child(dateMenu.container);
        }

        // Normalkan kembali posisi status menu di rightBox.
        if (statusMenu.container.get_parent() === rightBox) {
            rightBox.remove_child(statusMenu.container);
            rightBox.add_child(statusMenu.container);
        }
    }
}
