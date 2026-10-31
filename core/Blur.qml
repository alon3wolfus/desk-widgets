import Quickshell
import Quickshell.Hyprland
import QtQuick

// On Hyprland, adds a layer rule at runtime so the compositor blurs behind the cards.
// Nothing is written to your Hyprland config: the rule lives until Hyprland reloads its
// config, and is added again right after. Turn it off with "blur": false in settings.json.
Scope {
    id: root

    readonly property bool hyprland: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") !== ""
    readonly property bool on: hyprland && Settings.blur

    // named, so applying it again replaces the old one instead of piling up
    function apply() {
        if (!hyprland) return;
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.layer_rule({ name = \"desk-widgets-blur\", match = { namespace = \"desk-widgets\" }, "
            + "blur = " + (Settings.blur ? "true" : "false") + ", ignore_alpha = 0.05 })"]);
    }

    onOnChanged: apply()
    Component.onCompleted: apply()

    Connections {
        target: root.hyprland ? Hyprland : null
        function onRawEvent(event) { if (event.name === "configreloaded") root.apply(); }
    }
}
