.pragma library

// Packs widgets onto the grid: columns two units wide, filled top to bottom. Two small widgets
// in a row share a line, a full column wraps into a new one beside it.
// sizes: [{ w, h }] in order. Returns { pos: [{ x, y }], width, height } relative to the block.
function pack(sizes, unit, gap, maxHeight, mirror) {
    const wide = unit * 2 + gap, placed = [];
    let col = 0, y = 0, tallest = 0, half = null;

    for (const s of sizes) {
        if (s.w <= unit && half && half.col === col) {
            placed.push({ x: col * (wide + gap) + unit + gap, y: half.y, w: s.w });
            half = null;
            continue;
        }
        if (y > 0 && y + s.h > maxHeight) { col++; y = 0; }
        placed.push({ x: col * (wide + gap), y: y, w: s.w });
        half = s.w <= unit ? { col: col, y: y } : null;
        y += s.h + gap;
        tallest = Math.max(tallest, y - gap);
    }

    const width = placed.length ? (col + 1) * wide + col * gap : 0;
    return {
        pos: placed.map(p => ({ x: mirror ? width - p.x - p.w : p.x, y: p.y })),
        width: width,
        height: tallest
    };
}

// cells a widget covers, from its pixel size
function span(w, h, unit, gap) {
    const cell = unit + gap;
    return { w: Math.max(1, Math.round((w + gap) / cell)), h: Math.max(1, Math.round((h + gap) / cell)) };
}

function overlaps(a, b) {
    return a.col < b.col + b.w && b.col < a.col + a.w && a.row < b.row + b.h && b.row < a.row + a.h;
}

// free spot for a widget of span sp nearest to (col, row). taken: [{ col, row, w, h }]
function nearestFree(col, row, sp, taken, cols, rows) {
    let best = null, bestD = Infinity;
    for (let r = 0; r <= rows - sp.h; r++) {
        for (let c = 0; c <= cols - sp.w; c++) {
            const d = (c - col) * (c - col) + (r - row) * (r - row);
            if (d >= bestD) continue;
            const me = { col: c, row: r, w: sp.w, h: sp.h };
            if (taken.some(t => overlaps(me, t))) continue;
            best = { col: c, row: r };
            bestD = d;
        }
    }
    return best || { col: Math.max(0, Math.min(col, cols - sp.w)), row: Math.max(0, Math.min(row, rows - sp.h)) };
}
