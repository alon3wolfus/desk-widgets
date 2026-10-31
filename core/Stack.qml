import QtQuick

// packs Slot children onto the widget grid: columns two units wide, filled top to bottom.
// Two small widgets in a row share a line. A full column wraps into a new one beside it.
Item {
    id: root
    property real maxHeight: 1000
    property bool mirror: false     // fill columns right to left, for zones on the right edge

    function relayout() { Qt.callLater(layout); }

    function layout() {
        const slots = [];
        for (const c of children) if (c.item && c.visible && c.item.width > 0) slots.push(c);
        slots.sort((a, b) => a.order - b.order);

        const colW = Theme.wide, gap = Theme.gap, placed = [];
        let col = 0, y = 0, tallest = 0, half = null;
        const fits = h => y === 0 || y + h <= maxHeight;

        for (const s of slots) {
            const w = s.item.width, h = s.item.height;
            if (w <= Theme.unit && half && half.col === col) {
                placed.push({ s: s, x: col * (colW + gap) + Theme.unit + gap, y: half.y });
                half = null;
                continue;
            }
            if (!fits(h)) { col++; y = 0; }
            placed.push({ s: s, x: col * (colW + gap), y: y });
            half = w <= Theme.unit ? { col: col, y: y } : null;
            y += h + gap;
            tallest = Math.max(tallest, y - gap);
        }

        const total = placed.length ? (col + 1) * colW + col * gap : 0;
        for (const p of placed) {
            p.s.x = mirror ? total - p.x - p.s.item.width : p.x;
            p.s.y = p.y;
        }
        implicitWidth = total;
        implicitHeight = tallest;
    }

    onChildrenChanged: relayout()
    onMaxHeightChanged: relayout()
    onMirrorChanged: relayout()
}
