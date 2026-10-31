pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// where widgets go. Saved to ~/.config/desk-widgets/layout.json.
// mode "zones": widgets stack in the zone named by their folder (active/top-left, ...).
// mode "grid": every widget sits on its own cell of a screen-wide grid, set by dragging.
// Edit mode is on while an Edit Widgets widget is shown.
Singleton {
    id: root

    // DESK_WIDGETS_LAYOUT points somewhere else, for previews
    readonly property string file: Quickshell.env("DESK_WIDGETS_LAYOUT")
        || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/desk-widgets/layout.json"
    readonly property string activeDir: Quickshell.shellPath("active")
    readonly property string inactiveDir: Quickshell.shellPath("inactive")

    property string mode: "zones"
    property var positions: ({})     // grid mode, by file name: { col, row }
    property int editors: 0
    property real savedAt: 0
    readonly property bool editing: editors > 0

    function save() {
        savedAt = Date.now();
        view.setText(JSON.stringify({ mode: mode, positions: positions }, null, 2) + "\n");
    }

    function setMode(m) {
        if (m === mode) return;
        mode = m;
        save();
    }

    function place(updates) {
        positions = Object.assign({}, positions, updates);
        save();
    }

    function resetGrid() {
        positions = {};
        save();
    }

    // moves a widget file into a folder, never overwriting one with the same name
    function moveTo(path, dir) {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$2\" && mv -n \"$1\" \"$2\"/", "sh", path, dir]);
    }
    function deactivate(path) { moveTo(path, inactiveDir); }
    function activate(path) { moveTo(path, activeDir); }
    function toZone(path, zone) { moveTo(path, activeDir + "/" + zone); }

    FileView {
        id: view
        path: root.file
        watchChanges: true
        printErrors: false
        // our own saves land here too, a moment later; reading them back could undo a newer change
        onFileChanged: if (Date.now() - root.savedAt > 1500) reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.mode = d.mode === "grid" ? "grid" : "zones";
                root.positions = d.positions || {};
            } catch (e) {
                console.warn("desk-widgets: layout.json is not valid JSON, ignoring it");
            }
        }
    }
}
