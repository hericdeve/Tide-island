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

    // Left: Mini Album Art (18x18, rounded 4px)
    Item {
        id: miniAlbumArt
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18

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
                sourceSize: Qt.size(36, 36)
                smooth: true
            }

            Text {
                anchors.centerIn: parent
                text: "󰎆"
                color: "#8e8e93"
                font.family: root.iconFontFamily
                font.pixelSize: 11
                visible: !root.currentArtUrl || root.currentArtUrl === ""
            }
        }
    }

    // Right: Mini 4-bar Spectrogram (16x12)
    Item {
        id: miniVisualizer
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 12

        Row {
            anchors.centerIn: parent
            height: parent.height
            spacing: 2

            Repeater {
                model: 4

                Rectangle {
                    width: 2.5
                    height: Math.max(2.5, parent.height * root.barLevel(index))
                    radius: 1.2
                    color: root.isPlaying ? "#b56cff" : "#5f4b72"
                    anchors.bottom: parent.bottom

                    Behavior on height {
                        NumberAnimation { duration: 100; easing.type: Easing.InOutQuad }
                    }
                }
            }
        }
    }

    // Center: Track Title & Artist strictly anchored BETWEEN miniAlbumArt and miniVisualizer
    Text {
        id: trackText
        anchors.left: miniAlbumArt.right
        anchors.leftMargin: 8
        anchors.right: miniVisualizer.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: {
            if (root.currentTrack === "") return "Not Playing";
            if (root.currentArtist !== "" && parent.width >= 240)
                return root.currentTrack + " • " + root.currentArtist;
            return root.currentTrack;
        }
        color: "white"
        font.pixelSize: 11
        font.family: root.textFontFamily
        font.weight: Font.DemiBold
        font.letterSpacing: -0.15
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        maximumLineCount: 1
        clip: true
    }
}
