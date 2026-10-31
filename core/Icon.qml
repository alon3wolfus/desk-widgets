import QtQuick

// Material Symbols Rounded glyph by name, e.g. "partly_cloudy_day". filled: solid instead of outline
Text {
    property string name: ""
    property bool filled: true
    property int size: 18

    text: name
    color: Theme.text
    font.family: Theme.icons
    font.pixelSize: size
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": 500, "opsz": Math.min(48, Math.max(20, size)) })
    renderType: Text.QtRendering
}
