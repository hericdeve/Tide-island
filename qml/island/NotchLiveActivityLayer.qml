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
    readonly property real scaleFactor: parent ? Math.max(0.75, Math.min(2.5, parent.height / 32.0)) : 1.0

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

    // Left: Mini Album Art (Scales with notchClosedHeight)
    Item {
        id: miniAlbumArt
        anchors.left: parent.left
        anchors.leftMargin: Math.round(10 * root.scaleFactor)
        anchors.verticalCenter: parent.verticalCenter
        property real artSize: Math.max(16, Math.min(parent ? parent.height - 8 : 26, Math.round(18 * root.scaleFactor)))
        width: artSize
        height: artSize

        Rectangle {
            anchors.fill: parent
            radius: Math.max(3, Math.round(miniAlbumArt.artSize * 0.22))
            color: "#1c1c1e"
            clip: true

            Image {
                anchors.fill: parent
                source: root.currentArtUrl
                fillMode: Image.PreserveAspectCrop
                visible: source.toString() !== ""
                sourceSize: Qt.size(miniAlbumArt.artSize * 2, miniAlbumArt.artSize * 2)
                smooth: true
            }

            Text {
                anchors.centerIn: parent
                text: "󰎆"
                color: "#8e8e93"
                font.family: root.iconFontFamily
                font.pixelSize: Math.round(11 * root.scaleFactor)
                visible: !root.currentArtUrl || root.currentArtUrl === ""
            }
        }
    }

    // Right: Mini 4-bar Spectrogram (Scales with notchClosedHeight)
    Item {
        id: miniVisualizer
        anchors.right: parent.right
        anchors.rightMargin: Math.round(10 * root.scaleFactor)
        anchors.verticalCenter: parent.verticalCenter
        property real visualizerHeight: Math.max(10, Math.min(parent ? parent.height - 10 : 16, Math.round(12 * root.scaleFactor)))
        property real visualizerWidth: Math.round(16 * root.scaleFactor)
        width: visualizerWidth
        height: visualizerHeight

        Row {
            anchors.centerIn: parent
            height: parent.height
            spacing: Math.max(1.5, Math.round(2 * root.scaleFactor))

            Repeater {
                model: 4

                Rectangle {
                    readonly property real barWidth: Math.max(2, Math.round(2.5 * root.scaleFactor))
                    width: barWidth
                    height: Math.max(barWidth, parent.height * root.barLevel(index))
                    radius: barWidth / 2
                    color: root.isPlaying ? "#ffffff" : "#636366"
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
        anchors.leftMargin: Math.round(8 * root.scaleFactor)
        anchors.right: miniVisualizer.left
        anchors.rightMargin: Math.round(8 * root.scaleFactor)
        anchors.verticalCenter: parent.verticalCenter
        text: {
            if (root.currentTrack === "") return "Not Playing";
            if (root.currentArtist !== "" && parent.width >= 240)
                return root.currentTrack + " • " + root.currentArtist;
            return root.currentTrack;
        }
        color: "white"
        font.pixelSize: Math.round(11 * root.scaleFactor)
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
