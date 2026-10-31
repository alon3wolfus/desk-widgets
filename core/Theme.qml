pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// All colours and fonts live here. The palette comes from themes/<name>.json, picked with
// "theme" in settings.json. Widgets ask for colours by role (text, accent, surface...), never by hex.
Singleton {
    id: root

    property var themeData: ({})
    property var scheme: null       // caelestia's generated colours, only read by the "caelestia" theme
    property bool systemDark: true

    readonly property bool wantDark: Settings.mode === "dark" || (Settings.mode !== "light" && systemDark)

    // Catppuccin Frappé, the old look. Fills in anything a theme leaves out and shows while loading.
    readonly property var fallback: ({
        dark: true,
        surface: "#303446", surfaceOpacity: 0.85,
        raised: "#51576d", raisedOpacity: 0.4, raisedHotOpacity: 0.6,
        edge: "#737994", edgeOpacity: 0.35, sheen: 0,
        text: "#c6d0f5", textDim: "#a5adce", textFaint: "#838ba7",
        accent: "#ca9ee6", accent2: "#f4b8e4", onAccent: "#232634",
        red: "#e78284", orange: "#ef9f76", yellow: "#e5c890", green: "#a6d189",
        blue: "#8caaee", purple: "#ca9ee6", pink: "#f4b8e4", teal: "#81c8be",
        sans: "Adwaita Sans", mono: "CaskaydiaCove NF", radius: 22
    })

    // themes with only one palette use it in both modes (Latte is always light, Mocha always dark)
    readonly property var p: {
        let pal = null, dark = true;
        if (themeData.source === "caelestia") {
            pal = scheme ? fromScheme(scheme) : null;
            dark = !scheme || scheme.mode !== "light";
        } else {
            dark = !!themeData.dark && (wantDark || !themeData.light);
            pal = dark ? themeData.dark : themeData.light;
        }
        return Object.assign({}, fallback, pal || {}, pal ? { dark: dark } : {});
    }

    function fromScheme(s) {
        const c = (k, alt) => s.colours && s.colours[k] ? "#" + s.colours[k] : alt;
        return {
            surface: c("surfaceContainer"), surfaceOpacity: 0.85,
            raised: c("surfaceContainerHighest"), raisedOpacity: 0.6,
            raisedHot: c("surfaceBright"), raisedHotOpacity: 0.8,
            edge: c("outlineVariant"), edgeOpacity: 0.6,
            text: c("onSurface"), textDim: c("onSurfaceVariant"), textFaint: c("outline"),
            accent: c("primary"), accent2: c("tertiary"), onAccent: c("onPrimary"),
            red: c("error"), orange: c("term11", c("term3")), yellow: c("term3"), green: c("term2"),
            blue: c("term4"), purple: c("term5"), pink: c("tertiary"), teal: c("term6")
        };
    }

    readonly property bool isDark: p.dark

    readonly property color surface:   Qt.alpha(p.surface, Math.min(1, p.surfaceOpacity * Settings.opacity))
    readonly property color raised:    Qt.alpha(p.raised, p.raisedOpacity)
    readonly property color raisedHot: Qt.alpha(p.raisedHot || p.raised, p.raisedHotOpacity)
    readonly property color edge:      Qt.alpha(p.edge, p.edgeOpacity)
    // strength of the white sheen across the top of each card, 0 for none
    readonly property real sheen: p.sheen

    readonly property color text:      p.text
    readonly property color textDim:   p.textDim
    readonly property color textFaint: p.textFaint
    readonly property color accent:    p.accent
    readonly property color accent2:   p.accent2
    readonly property color onAccent:  p.onAccent

    readonly property color red:    p.red
    readonly property color orange: p.orange
    readonly property color yellow: p.yellow
    readonly property color green:  p.green
    readonly property color blue:   p.blue
    readonly property color purple: p.purple
    readonly property color pink:   p.pink
    readonly property color teal:   p.teal

    readonly property string sans: Settings.font || p.sans
    readonly property string mono: p.mono
    readonly property string icons: "Material Symbols Rounded"
    readonly property int radius: p.radius

    // widget grid, like macOS: small is unit x unit, medium 2 units wide, large 2 x 2
    readonly property int unit: 170
    readonly property int gap: 16
    readonly property int wide: unit * 2 + gap

    FileView {
        path: Quickshell.shellPath("themes/" + Settings.theme + ".json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.themeData = JSON.parse(text()); }
            catch (e) { console.warn("desk-widgets: themes/" + Settings.theme + ".json is not valid JSON"); }
        }
        onLoadFailed: {
            console.warn("desk-widgets: no theme named \"" + Settings.theme + "\" in themes/, using the fallback");
            root.themeData = {};
        }
    }

    FileView {
        path: root.themeData.source === "caelestia"
            ? (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/caelestia/scheme.json"
            : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.scheme = JSON.parse(text()); } catch (e) {} }
    }

    // desktop light / dark preference, live. Without gsettings it stays dark.
    Process {
        running: Settings.mode === "auto"
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface color-scheme && exec gsettings monitor org.gnome.desktop.interface color-scheme"]
        stdout: SplitParser { onRead: line => root.systemDark = line.indexOf("dark") >= 0 }
    }
}
