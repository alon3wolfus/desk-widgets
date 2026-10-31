import QtQuick
import "pack.js" as Pack

// packs Slot children onto the widget grid on their own, without the desktop's zones.
// Used for previews; the desktop itself lays out in Desktop.qml.
Item {
    id: root
    property real maxHeight: 1000
    property bool mirror: false

    function relayout() { Qt.callLater(layout); }

    function layout() {
        const slots = [];
        for (const c of children) if (c.isSlot && c.item && c.visible && c.item.width > 0) slots.push(c);
        slots.sort((a, b) => a.order - b.order);
        const r = Pack.pack(slots.map(s => ({ w: s.item.width, h: s.item.height })), Theme.unit, Theme.gap, maxHeight, mirror);
        slots.forEach((s, i) => { s.x = r.pos[i].x; s.y = r.pos[i].y; });
        implicitWidth = r.width;
        implicitHeight = r.height;
    }

    onChildrenChanged: relayout()
    onMaxHeightChanged: relayout()
    onMirrorChanged: relayout()
}
