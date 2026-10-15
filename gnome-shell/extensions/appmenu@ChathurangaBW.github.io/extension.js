import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import { MenuManager } from './menuManager.js';
import { UserSwitcherController } from './userSwitcher.js';
import { setLoggerSettings, debug } from './logger.js';
import { disposeViewActions } from './actions/viewActions.js';
import { WorkspaceIndicatorController } from './workspaceIndicator.js';
import { toggleSearchDialog, destroySearchDialog } from './searchDialog.js';
import { initI18n } from './i18n.js';

const FOCUS_DEBOUNCE_MS = 50;

export default class AppMenuExtension extends Extension {
    constructor(metadata) {
        super(metadata);
        this._menuManager = null;
        this._settings = null;
        this._focusTimeoutId = 0;
        this._focusedWindow = null;
        this._hasMenuFocusState = false;
        this._userSwitcherController = null;
        this._workspaceIndicatorController = null;
        this._searchShortcutInstalled = false;
        this._overviewHidden = false;
        this._overviewWasVisible = false;
        // PATCH LOKAL (2026-10-16): pengelola menu AppMenu untuk bar monitor sekunder.
        this._uuid = 'appmenu@ChathurangaBW.github.io';
        this._secondaryManagers = new Map();
        this._secondarySyncId = 0;
    }

    enable() {
        this._settings = this.getSettings('org.gnome.shell.extensions.appmenu');
        initI18n(this);
        setLoggerSettings(this._settings);
        debug('Enabling extension.');

        this._focusedWindow = null;
        this._hasMenuFocusState = false;

        const uuid = this.metadata.uuid || 'appmenu@ChathurangaBW.github.io';
        this._uuid = uuid;
        this._removeStalePanelButtons(uuid);
        this._menuManager = new MenuManager(uuid, this._settings, this.metadata.version);

        const initialWindow = global.display.get_focus_window();
        this._updateMenu(initialWindow);

        // PATCH LOKAL (2026-10-16): ikutkan bar monitor sekunder; panelnya
        // dibuat ekstensi lain setelah startup, jadi sinkronkan via idle.
        Main.layoutManager.connectObject(
            'startup-complete', () => this._scheduleSecondarySync(),
            'monitors-changed', () => this._scheduleSecondarySync(),
            this
        );
        this._scheduleSecondarySync();

        global.display.connectObject('notify::focus-window', () => {
            this._scheduleMenuUpdate();
        }, this);

        this._syncOverviewButton();

        this._settingsChangedId = this._settings.connect('changed', (_s, key) => {
            if (key === 'hide-overview-button') {
                this._syncOverviewButton();
            }
        });

        this._userSwitcherController = new UserSwitcherController(this, this._settings);
        this._workspaceIndicatorController = new WorkspaceIndicatorController(this._settings);
        this._addSearchKeybinding();
    }

    _removeStalePanelButtons(uuid) {
        // PATCH LOKAL (2026-10-16): bersihkan juga di bar monitor sekunder.
        for (const panel of [Main.panel, ...this._findSecondaryPanels()])
            this._removeStalePanelButtonsForPanel(panel, uuid);
    }

    _removeStalePanelButtonsForPanel(panel, uuid) {
        const statusArea = panel?.statusArea;
        if (!statusArea) return;

        for (const name of Object.keys(statusArea)) {
            if (!name.startsWith(`${uuid}-`))
                continue;

            try {
                statusArea[name]?.destroy();
            } catch (e) {
                debug(`Could not remove stale panel button ${name}: ${e}`);
            }
        }
    }

    _findSecondaryPanels() {
        // PATCH LOKAL (2026-10-16): deteksi bar top monitor sekunder
        // (kotak "panelBox" dari ekstensi Top Bar All Monitors).
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
                if (child.statusArea && child._centerBox) {
                    panels.push(child);
                    break;
                }
            }
        }

        return panels;
    }

    _scheduleSecondarySync() {
        if (this._secondarySyncId)
            return;

        this._secondarySyncId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._secondarySyncId = 0;
            this._syncSecondaryManagers();
            return GLib.SOURCE_REMOVE;
        });
    }

    _syncSecondaryManagers() {
        if (!this._settings || !this._secondaryManagers)
            return;

        const panels = this._findSecondaryPanels();

        // Buang pengelola yang panelnya sudah hilang (mis. monitor dicabut).
        for (const [panel, manager] of [...this._secondaryManagers]) {
            if (panels.includes(panel))
                continue;

            try {
                manager.destroy();
            } catch (e) {
                debug(`Could not destroy secondary menu manager: ${e}`);
            }
            this._secondaryManagers.delete(panel);
        }

        // Buat pengelola untuk tiap panel sekunder yang belum punya.
        for (const panel of panels) {
            if (this._secondaryManagers.has(panel))
                continue;

            this._removeStalePanelButtonsForPanel(panel, this._uuid);

            try {
                const manager = new MenuManager(this._uuid, this._settings,
                    this.metadata.version, panel);
                manager.updateMenuForWindow(global.display.get_focus_window(), true);
                this._secondaryManagers.set(panel, manager);
            } catch (e) {
                debug(`Could not create secondary menu manager: ${e}`);
            }
        }
    }

    _syncOverviewButton() {
        let activities = Main.panel.statusArea['activities'];
        if (!activities) return;
        let shouldHide = this._settings.get_boolean('hide-overview-button');
        if (shouldHide && !this._overviewHidden) {
            this._overviewWasVisible = activities.visible;
            activities.hide();
            this._overviewHidden = true;
        } else if (!shouldHide && this._overviewHidden) {
            if (this._overviewWasVisible)
                activities.show();
            this._overviewHidden = false;
            this._overviewWasVisible = false;
        }
    }

    _addSearchKeybinding() {
        if (!this._settings || this._searchShortcutInstalled)
            return;

        Main.wm.addKeybinding(
            'search-shortcut',
            this._settings,
            Meta.KeyBindingFlags.NONE,
            Shell.ActionMode.NORMAL,
            () => toggleSearchDialog()
        );
        this._searchShortcutInstalled = true;
    }

    _removeSearchKeybinding() {
        if (!this._searchShortcutInstalled)
            return;

        Main.wm.removeKeybinding('search-shortcut');
        this._searchShortcutInstalled = false;
    }

    _updateMenu(window) {
        if (!this._menuManager) return;

        const lockEnabled = this._settings
            ? this._settings.get_boolean('lock-to-focused-app')
            : true;

        if (lockEnabled && this._hasMenuFocusState && window === this._focusedWindow)
            return;

        // Mutter can report no focused window during Wayland focus transitions.
        // Reflect that state as Desktop instead of leaving the previous app menu stale.
        this._focusedWindow = window;
        this._hasMenuFocusState = true;
        debug(`Updating menu for ${window?.get_title?.() || 'Desktop'}.`);
        this._menuManager.updateMenuForWindow(window, true);

        // PATCH LOKAL (2026-10-16): samakan menu di bar monitor sekunder.
        for (const manager of this._secondaryManagers?.values() ?? []) {
            try {
                manager.updateMenuForWindow(window, true);
            } catch (e) {
                debug(`Could not update secondary menu: ${e}`);
            }
        }
    }

    _scheduleMenuUpdate() {
        if (this._focusTimeoutId)
            GLib.source_remove(this._focusTimeoutId);

        this._focusTimeoutId = GLib.timeout_add(
            GLib.PRIORITY_DEFAULT,
            FOCUS_DEBOUNCE_MS,
            () => {
                this._focusTimeoutId = 0;
                const activeWindow = global.display.get_focus_window();
                this._updateMenu(activeWindow);
                return GLib.SOURCE_REMOVE;
            }
        );
    }

    disable() {
        debug('Disabling extension.');

        global.display.disconnectObject(this);
        Main.layoutManager.disconnectObject(this);

        if (this._secondarySyncId) {
            GLib.source_remove(this._secondarySyncId);
            this._secondarySyncId = 0;
        }

        if (this._secondaryManagers) {
            for (const manager of this._secondaryManagers.values()) {
                try {
                    manager.destroy();
                } catch (e) {
                    debug(`Could not destroy secondary menu manager: ${e}`);
                }
            }
            this._secondaryManagers.clear();
        }

        this._removeSearchKeybinding();
        destroySearchDialog();

        if (this._focusTimeoutId) {
            GLib.source_remove(this._focusTimeoutId);
            this._focusTimeoutId = 0;
        }

        this._focusedWindow = null;
        this._hasMenuFocusState = false;

        if (this._menuManager) {
            this._menuManager.destroy();
            this._menuManager = null;
        }

        if (this._userSwitcherController) {
            this._userSwitcherController.destroy();
            this._userSwitcherController = null;
        }

        if (this._workspaceIndicatorController) {
            this._workspaceIndicatorController.destroy();
            this._workspaceIndicatorController = null;
        }

        if (this._settings && this._settingsChangedId) {
            this._settings.disconnect(this._settingsChangedId);
            this._settingsChangedId = null;
        }

        if (this._overviewHidden && this._overviewWasVisible) {
            let activities = Main.panel.statusArea['activities'];
            if (activities) activities.show();
        }
        this._overviewHidden = false;
        this._overviewWasVisible = false;

        disposeViewActions();
        setLoggerSettings(null);
        this._settings = null;
    }
}
