import QtQuick
import QtMultimedia
import IslandBackend

Item {
    id: root

    property bool isRunning: false
    property string textFontFamily: "Sans Serif"
    property string iconFontFamily: "Sans Serif"

    readonly property bool hasCamera: mediaDevices.videoInputs.length > 0

    MediaDevices {
        id: mediaDevices
    }

    CaptureSession {
        id: session
        camera: Camera {
            id: cam
            active: root.isRunning && root.hasCamera
        }
        videoOutput: videoOut
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#1c1c1e"
        border.width: 1
        border.color: "#2c2c2e"
        clip: true

        // Live Camera Feed (Mirrored horizontally)
        VideoOutput {
            id: videoOut
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            visible: root.isRunning && root.hasCamera
            transform: Scale {
                origin.x: videoOut.width / 2
                xScale: -1 // Mirror effect
            }
        }

        // Placeholder / Tap-to-Start View (Matching Boring Notch WebcamView)
        Column {
            anchors.centerIn: parent
            spacing: 6
            visible: !root.isRunning || !root.hasCamera

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰄀"
                color: root.hasCamera ? (mouseArea.containsMouse ? "white" : "#8e8e93") : "#48484a"
                font.family: root.iconFontFamily
                font.pixelSize: 22
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !root.hasCamera ? "No Camera" : (root.isRunning ? "Stop Mirror" : "Mirror")
                color: root.hasCamera ? "#8e8e93" : "#48484a"
                font.family: root.textFontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }

        // Click to toggle mirror session
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.hasCamera ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (root.hasCamera) {
                    root.isRunning = !root.isRunning;
                }
            }
        }
    }
}
