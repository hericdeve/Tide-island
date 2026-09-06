import QtQuick
import IslandBackend

Item {
    id: root

    property string currentArtUrl: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property bool isPlaying: false
    property var cavaLevels: []
    property string iconFontFamily: "Sans Serif"
    property string textFontFamily: "Sans Serif"
    property real visualizerPhase: 0

    function barLevel(index) {
        if (cavaLevels && cavaLevels.length > index) {
            const val = Number(cavaLevels[index]);
            if (!isNaN(val) && val > 0.05)
                return Math.min(1.0, Math.max(0.15, val));
        }

        if (!isPlaying)
            return 0.25;

        const phase = visualizerPhase + index * 0.85;
        const s1 = (Math.sin(phase) + 1) * 0.5;
        const s2 = (Math.sin(phase * 1.7 + index) + 1) * 0.5;
        return 0.2 + s1 * 0.5 + s2 * 0.3;
    }

    Timer {
        interval: 64
        repeat: true
        running: root.visible && root.isPlaying
        onTriggered: {
            visualizerPhase += 0.2;
            if (visualizerPhase > Math.PI * 2)
                visualizerPhase -= Math.PI * 2;
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        // Left: Mini Album Art (Boring Notch style)
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: "#1c1c1e"
                clip: true

                Image {
                    anchors.fill: parent
                    source: root.currentArtUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: source.toString() !== ""
                    sourceSize: Qt.size(40, 40)
                    smooth: true
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰎆"
                    color: "#8e8e93"
                    font.family: root.iconFontFamily
                    font.pixelSize: 12
                    visible: !root.currentArtUrl || root.currentArtUrl === ""
                }
            }
        }

        // Center: Track Title & Artist
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - 20 - 36 - 24)
            height: parent.height
            clip: true

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                spacing: 6

                Text {
                    text: root.currentTrack !== "" ? root.currentTrack : "Not Playing"
                    color: "white"
                    font.pixelSize: 12
                    font.family: root.textFontFamily
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    text: root.currentArtist
                    color: "#8e8e93"
                    font.pixelSize: 11
                    font.family: root.textFontFamily
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: root.currentArtist !== "" && parent.parent.width > 120
                }
            }
        }

        // Right: Live Spectrogram / Visualizer
        Item {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            width: 24
            height: 14

            Row {
                anchors.centerIn: parent
                height: parent.height
                spacing: 2

                Repeater {
                    model: 4

                    Rectangle {
                        width: 3
                        height: Math.max(3, parent.height * root.barLevel(index))
                        radius: 1.5
                        color: root.isPlaying ? "#b56cff" : "#5f4b72"
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on height {
                            NumberAnimation { duration: 100; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }
        }
    }
}
