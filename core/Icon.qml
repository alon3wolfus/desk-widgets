import QtQuick

// Material Symbols Rounded glyph by name, e.g. "partly_cloudy_day". Outline by default: Qt draws the
// filled style wrong for glyphs with cutouts (laptop, memory), so only fill simple shapes
Text {
    property string name: ""
    property bool filled: false
    property int size: 18

    text: name
    color: Theme.text
    font.family: Theme.icons
    font.pixelSize: size
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": 500, "opsz": Math.min(48, Math.max(20, size)) })
    renderType: Text.QtRendering
}
