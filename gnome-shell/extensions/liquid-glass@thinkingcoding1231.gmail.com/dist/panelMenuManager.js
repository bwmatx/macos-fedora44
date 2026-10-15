import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import GLib from 'gi://GLib';
import { UIManager } from './uiManager.js';
// Settings prefix for every detected panel menu, separate from the calendar's
// `menu-*` keys (see UIManager._keyPrefix).
const PANEL_MENU_PREFIX = 'panel-menu';
// Menus that had their own switch before the generic detection existed.
const LEGACY_KEYS = {
    keyboard: 'enable-keyboard-menu-glass',
    vitalsMenu: 'enable-vitals-menu-glass',
};
// The popup menus a status area entry opens, with the names they are listed
// under. ArcMenu destroys the button's own menu and opens two of its own.
function menusOf(name, button) {
    if (button.arcMenu)
        return [[name, button.arcMenu], [`${name}ContextMenu`, button.arcMenuContextMenu]];
    return [[name, button.menu]];
}
export class PanelMenuManager {
    _path;
    _settings;
    _logger;
    _signals = [];
    _buttons = new Map();
    // Menu actor -> its glass, with the indicator name for the logs.
    _menus = new Map();
    _idleId = 0;
    constructor(_path, _settings, _logger) {
        this._path = _path;
        this._settings = _settings;
        this._logger = _logger;
    }
    setup() {
        const schedule = () => this._scheduleScan();
        const watch = (target, signal) => {
            this._signals.push({ target, id: target.connect(signal, schedule) });
        };
        // Defer until addToStatusArea() has finished registering the indicator.
        const panel = Main.panel;
        for (const box of [panel._leftBox, panel._centerBox, panel._rightBox]) {
            watch(box, 'child-added');
            watch(box, 'child-removed');
        }
        watch(Main.extensionManager, 'extension-state-changed');
        // PATCH LOKAL (2026-10-16, bwmatx/macos-fedora44): bar top monitor
        // sekunder dibangun ulang saat startup selesai & saat monitor berubah;
        // jadwalkan pemindaian ulang pada kedua momen itu.
        watch(Main.layoutManager, 'startup-complete');
        watch(Main.layoutManager, 'monitors-changed');
        for (const key of ['enable-extra-menu-glass', 'disabled-extra-menus', ...Object.values(LEGACY_KEYS)])
            watch(this._settings, `changed::${key}`);
        this._scheduleScan();
    }
    _scheduleScan() {
        if (this._idleId)
            return;
        this._idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._idleId = 0;
            this._scan();
            return GLib.SOURCE_REMOVE;
        });
    }
    _scan() {
        const buttons = new Set();
        const wanted = new Map();
        const detected = [];
        // PATCH LOKAL (2026-10-16, bwmatx/macos-fedora44): ikut pindai menu
        // dari bar top monitor sekunder (Top Bar All Monitors). Menu clone di
        // sana tidak punya manajer khusus LG, jadi diperlakukan sebagai menu
        // ekstra supaya mendapat kaca yang sama seperti menu bar utama.
        for (const panel of [Main.panel, ...this._findSecondaryPanels()]) {
            const result = this._discover(panel);
            for (const button of result.buttons)
                buttons.add(button);
            for (const [menu, entry] of result.wanted)
                wanted.set(menu, entry);
            detected.push(...result.detected);
        }
        this._forgetButtons(buttons);
        this._detachUnwanted(wanted);
        this._attachWanted(wanted);
        detected.sort();
        if (JSON.stringify(detected) !== JSON.stringify(this._settings.get_strv('detected-extra-menus')))
            this._settings.set_strv('detected-extra-menus', detected);
    }
    // PATCH LOKAL (2026-10-16, bwmatx/macos-fedora44): panel sekunder = anak
    // "panelBox" di uiGroup yang bukan panel utama (pola sama dengan ekstensi
    // Moveclock).
    _findSecondaryPanels() {
        const panels = [];
        for (const actor of Main.layoutManager.uiGroup.get_children()) {
            if (actor.get_name() !== 'panelBox')
                continue;
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
    _discover(panel) {
        const buttons = new Set();
        const wanted = new Map();
        const detected = [];
        const disabled = new Set(this._settings.get_strv('disabled-extra-menus'));
        const enabled = this._settings.get_boolean('enable-extra-menu-glass');
        // PATCH LOKAL (2026-10-16, bwmatx/macos-fedora44): menu quick settings
        // SEMUA panel kini ditangani QuickSettingsManager (primary + clone di
        // bar sekunder via SecondaryQuickSettingsSync), begitu pula kalender
        // (bar utama via UIManager root, bar sekunder via clone UIManager
        // resep menu-*), jadi keduanya selalu dikecualikan di sini. Menu lain
        // di bar sekunder tetap lewat jalur "menu ekstra" ini.
        const reserved = new Set([panel.statusArea.quickSettings?.menu]);
        reserved.add(panel.statusArea.dateMenu?.menu);
        for (const [name, button] of Object.entries(panel.statusArea)) {
            if (!button || !panel.contains(button.container ?? button))
                continue;
            buttons.add(button);
            this._watchButton(button);
            for (const [menuName, menu] of menusOf(name, button)) {
                // Dummy menus and custom non-popup actors cannot use UIManager.
                // Calendar and Quick Settings already have their own managers.
                if (!(menu instanceof PopupMenu.PopupMenu) || reserved.has(menu) || !menu.actor || !menu.box)
                    continue;
                detected.push(menuName);
                const allowed = LEGACY_KEYS[menuName]
                    ? this._settings.get_boolean(LEGACY_KEYS[menuName]) : !disabled.has(menuName);
                if (enabled && allowed)
                    wanted.set(menu, { name: menuName });
            }
        }
        return { buttons, wanted, detected };
    }
    _watchButton(button) {
        if (this._buttons.has(button))
            return;
        this._buttons.set(button, [
            button.connect('menu-set', () => this._scheduleScan()),
            button.connect('destroy', () => {
                this._buttons.delete(button);
                this._scheduleScan();
            }),
        ]);
    }
    _forgetButtons(present) {
        for (const [button, ids] of this._buttons) {
            if (present.has(button))
                continue;
            for (const id of ids)
                button.disconnect(id);
            this._buttons.delete(button);
        }
    }
    _detachUnwanted(wanted) {
        // Keep existing instances: a new indicator must not close another menu.
        for (const [menu, entry] of this._menus) {
            if (wanted.has(menu))
                continue;
            this._menus.delete(menu);
            entry.manager.cleanup();
        }
    }
    // Most of these menus belong to other extensions and may not be built the
    // way UIManager expects; such a menu is skipped instead of stopping the scan.
    _attachWanted(wanted) {
        for (const [menu, { name }] of wanted) {
            if (this._menus.has(menu))
                continue;
            const manager = new UIManager(this._path, this._settings, this._logger, { menu }, false, 'enable-extra-menu-glass', PANEL_MENU_PREFIX, `menu:${name}`, false);
            try {
                manager.setup();
                this._menus.set(menu, { name, manager });
            }
            catch (e) {
                manager.cleanup();
                this._logger.log(`[Liquid Glass] Could not attach panel menu glass to "${name}": ${e}`);
            }
        }
    }
    cleanup() {
        if (this._idleId) {
            GLib.Source.remove(this._idleId);
            this._idleId = 0;
        }
        for (const { target, id } of this._signals)
            target.disconnect(id);
        this._signals = [];
        for (const [button, ids] of this._buttons) {
            for (const id of ids)
                button.disconnect(id);
        }
        this._buttons.clear();
        for (const { manager } of this._menus.values())
            manager.cleanup();
        this._menus.clear();
        this._settings.set_strv('detected-extra-menus', []);
    }
}
