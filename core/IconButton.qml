import QtQuick

// round button with a drawn glyph: play, pause, next, prev
Rectangle {
    id: root
    property string kind: "play"
    property color fill: Theme.raised
    property color ink: Theme.text
    property int size: 32
    signal clicked()

    width: size; height: size; radius: size / 2
    color: mouse.containsMouse ? Qt.lighter(fill, 1.15) : fill
    Behavior on color { ColorAnimation { duration: 100 } }

    Canvas {
        id: glyph
        anchors.centerIn: parent
        width: root.size * 0.38; height: width
        property string kind: root.kind
        property color ink: root.ink
        onKindChanged: requestPaint()
        onInkChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"), w = width, h = height;
            c.clearRect(0, 0, w, h);
            c.fillStyle = ink;
            const tri = (x0, x1) => {
                c.beginPath(); c.moveTo(x0, 0); c.lineTo(x1, h / 2); c.lineTo(x0, h); c.closePath(); c.fill();
            };
            if (kind === "play") tri(w * 0.12, w);
            else if (kind === "pause") { c.fillRect(w * 0.1, 0, w * 0.28, h); c.fillRect(w * 0.62, 0, w * 0.28, h); }
            else if (kind === "next") { tri(0, w * 0.8); c.fillRect(w * 0.86, 0, w * 0.14, h); }
            else if (kind === "prev") {
                c.fillRect(0, 0, w * 0.14, h);
                c.beginPath(); c.moveTo(w, 0); c.lineTo(w * 0.2, h / 2); c.lineTo(w, h); c.closePath(); c.fill();
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
