pragma Singleton
import Quickshell
import QtQuick

// Catppuccin Frappé. All colours and fonts live here.
Singleton {
    readonly property color base:     "#303446"
    readonly property color surface1: "#51576d"
    readonly property color surface2: "#626880"
    readonly property color overlay0: "#737994"
    readonly property color crust:    "#232634"

    readonly property real transparencyBase:   0.85
    readonly property real transparencyLayers: 0.4

    readonly property color card:      Qt.alpha(base, transparencyBase)
    readonly property color cardEdge:  Qt.alpha(overlay0, 0.35)
    readonly property color raised:    Qt.alpha(surface1, transparencyLayers)
    readonly property color raisedHot: Qt.alpha(surface2, Math.min(1, transparencyLayers + 0.2))

    readonly property color purple:   "#ca9ee6"
    readonly property color pink:     "#f4b8e4"
    readonly property color white:    "#c6d0f5"
    readonly property color dim:      "#a5adce"
    readonly property color red:      "#e78284"
    readonly property color onAccent: crust

    readonly property string sans: "Rubik"
    readonly property string mono: "CaskaydiaCove NF"

    readonly property int radius: 22
}
