import QtQuick

// circular gauge, filled clockwise from the top. value 0..1
Canvas {
    id: root
    property real value: 0
    property color tint: Theme.accent
    property color track: Theme.raised
    property real thickness: 6

    implicitWidth: 56
    height: width

    onValueChanged: requestPaint()
    onTintChanged: requestPaint()
    onTrackChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.lineWidth = thickness;
        ctx.lineCap = "round";
        const c = width / 2, r = c - thickness / 2, top = -Math.PI / 2;
        ctx.strokeStyle = track;
        ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 2); ctx.stroke();
        const v = Math.max(0, Math.min(1, value));
        if (v > 0) {
            ctx.strokeStyle = tint;
            ctx.beginPath(); ctx.arc(c, c, r, top, top + Math.PI * 2 * v); ctx.stroke();
        }
    }
}
