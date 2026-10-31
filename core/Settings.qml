pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// user settings from ~/.config/desk-widgets/settings.json, reloaded live when the file changes.
// Written with the defaults on first run so there is something to edit.
Singleton {
    id: root

    readonly property string file: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/desk-widgets/settings.json"
    readonly property var defaults: ({ theme: "glass", mode: "auto", opacity: 1, font: "" })
    property var values: defaults

    readonly property string theme: values.theme || defaults.theme
    // "auto" follows the desktop's light / dark preference, or force "light" / "dark"
    readonly property string mode: values.mode || defaults.mode
    // multiplies card opacity. Raise it if your compositor doesn't blur behind the widgets
    readonly property real opacity: typeof values.opacity === "number" ? values.opacity : 1
    // overrides the theme's font, e.g. "Inter"
    readonly property string font: values.font || ""

    FileView {
        path: root.file
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.values = JSON.parse(text()); }
            catch (e) { console.warn("desk-widgets: settings.json is not valid JSON, keeping the last good one"); }
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) setText(JSON.stringify(root.defaults, null, 2) + "\n");
        }
    }
}
