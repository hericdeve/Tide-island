import QtQuick
import Quickshell.Widgets
import IslandBackend

Item {
    id: root

    property string currentArtUrl: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property bool isPlaying: false
    property bool showBoringFace: true
    property string iconFontFamily: "Sans Serif"
    property string textFontFamily: "Sans Serif"

    readonly property bool hasMusic: currentTrack !== ""
    readonly property real circleDiameter: Math.min(width, height)
    readonly property real circleRadius: circleDiameter / 2

    // Music active state: Circular Album Art
    Item {
        id: musicCircle
        anchors.fill: parent
        visible: root.hasMusic

        // Subtle pulsing accent ring when music is playing
        Rectangle {
            id: pulseRing
            anchors.centerIn: parent
            width: parent.width - 2
            height: parent.height - 2
            radius: width / 2
            color: "transparent"
            border.width: 1.5
            border.color: root.isPlaying ? "#b56cff" : "#3a3a3c"
            opacity: root.isPlaying ? 0.9 : 0.4

            SequentialAnimation on opacity {
                running: root.hasMusic && root.isPlaying
                loops: Animation.Infinite
                NumberAnimation { from: 0.5; to: 1.0; duration: 1200; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.0; to: 0.5; duration: 1200; easing.type: Easing.InOutQuad }
            }
        }

        ClippingRectangle {
            id: artClip
            anchors.fill: parent
            anchors.margins: 3.5
            radius: width / 2
            color: "#1c1c1e"
            antialiasing: true

            Image {
                anchors.fill: parent
                source: root.currentArtUrl
                fillMode: Image.PreserveAspectCrop
                visible: source.toString() !== ""
                sourceSize: Qt.size(Math.round(parent.width * 2), Math.round(parent.height * 2))
                smooth: true
            }

            Text {
                anchors.centerIn: parent
                text: "󰎆"
                color: "#8e8e93"
                font.family: root.iconFontFamily
                font.pixelSize: Math.max(12, Math.round(parent.height * 0.44))
                visible: !root.currentArtUrl || root.currentArtUrl === ""
            }
        }
    }

    // Idle state: Blinking face or icon
    Item {
        id: idleCircle
        anchors.fill: parent
        visible: !root.hasMusic

        BoringFaceAnimation {
            anchors.centerIn: parent
            visible: root.showBoringFace
        }

        Text {
            anchors.centerIn: parent
            text: "󰋜"
            color: "#8e8e93"
            font.family: root.iconFontFamily
            font.pixelSize: Math.max(14, Math.round(parent.height * 0.45))
            visible: !root.showBoringFace
        }
    }
}
