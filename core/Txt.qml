import QtQuick

// body text. Numbers are tabular so clocks and counters don't jitter
Text {
    color: Theme.text
    font.family: Theme.sans
    font.pixelSize: 13
    font.features: ({ "tnum": 1 })
}
