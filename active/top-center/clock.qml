import QtQuick
import Quickshell
import qs.core

// clock. style "digital" is a medium card with the date, "analog" a small watch face
Card {
    id: root

    property string style: "digital"
    property bool use24h: false
    property bool showSeconds: true

    size: style === "analog" ? "small" : "medium"
    pad: style === "analog" ? 10 : 16

    SystemClock { id: sc; precision: SystemClock.Seconds }

    Loader {
        anchors.fill: parent
        sourceComponent: root.style === "analog" ? analog : digital
    }

    Component {
        id: digital

        Item {
            Label {
                id: day
                text: Qt.formatDate(sc.date, "dddd")
                color: Theme.orange
            }
            Txt {
                anchors.top: day.bottom
                anchors.topMargin: 2
                text: Qt.formatDate(sc.date, "d MMMM")
                color: Theme.textDim
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Txt {
                id: hm
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -10
                // Qt only switches to 12h when the format has AP, so format with it and cut it off
                text: root.use24h ? Qt.formatTime(sc.date, "HH:mm") : Qt.formatTime(sc.date, "h:mm AP").split(" ")[0]
                font.pixelSize: 76
                font.weight: Font.DemiBold
                font.letterSpacing: -3
            }
            Column {
                anchors.left: hm.right
                anchors.leftMargin: 10
                anchors.bottom: hm.baseline
                Txt {
                    visible: !root.use24h
                    text: Qt.formatTime(sc.date, "AP")
                    color: Theme.textDim
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Txt {
                    visible: root.showSeconds
                    text: Qt.formatTime(sc.date, "ss")
                    color: Theme.orange
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    Component {
        id: analog

        Canvas {
            id: face
            property date t: sc.date
            onTChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d"), c = width / 2, r = c - 1;
                ctx.clearRect(0, 0, width, height);
                ctx.fillStyle = Theme.raised;
                ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 2); ctx.fill();

                const at = (turn, len) => [c + Math.sin(turn * Math.PI * 2) * len, c - Math.cos(turn * Math.PI * 2) * len];

                ctx.strokeStyle = Theme.textFaint;
                ctx.lineWidth = 1;
                for (let i = 0; i < 60; i++) {
                    if (i % 5 === 0) continue;
                    const a = at(i / 60, r - 4), b = at(i / 60, r - 7);
                    ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke();
                }
                ctx.fillStyle = Theme.text;
                ctx.font = "600 " + Math.round(r * 0.2) + "px '" + Theme.sans + "'";
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                for (let h = 1; h <= 12; h++) {
                    const p = at(h / 12, r * 0.78);
                    ctx.fillText(String(h), p[0], p[1] + 1);
                }
                ctx.fillStyle = Theme.textDim;
                ctx.font = "600 " + Math.round(r * 0.13) + "px '" + Theme.sans + "'";
                ctx.fillText(Qt.formatDate(t, "ddd").toUpperCase(), c, c + r * 0.36);

                const s = t.getSeconds(), m = t.getMinutes() + s / 60, hr = t.getHours() % 12 + m / 60;
                const hand = (turn, len, w, col, tail) => {
                    const a = at(turn, len), b = at(turn + 0.5, tail || 0);
                    ctx.strokeStyle = col; ctx.lineWidth = w; ctx.lineCap = "round";
                    ctx.beginPath(); ctx.moveTo(b[0], b[1]); ctx.lineTo(a[0], a[1]); ctx.stroke();
                };
                hand(hr / 12, r * 0.5, 4, Theme.text);
                hand(m / 60, r * 0.78, 3, Theme.text);
                hand(s / 60, r * 0.86, 1.5, Theme.orange, r * 0.16);
                ctx.fillStyle = Theme.orange;
                ctx.beginPath(); ctx.arc(c, c, 3.5, 0, Math.PI * 2); ctx.fill();
            }
        }
    }
}
