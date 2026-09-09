import QtQuick
import IslandBackend

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property string iconFontFamily: widgetContext ? widgetContext.iconFontFamily : "Sans Serif"
    readonly property string textFontFamily: widgetContext ? widgetContext.textFontFamily : "Sans Serif"
    readonly property int bodyFontSize: widgetContext ? widgetContext.bodyFontSize : 16
    readonly property int iconFontSize: widgetContext ? widgetContext.iconFontSize : 18

    property real currentVolume: 0.65
    property real currentBrightness: 0.7

    Component.onCompleted: {
        SystemServices.requestVolume();
        SystemServices.requestBrightness();
    }

    Connections {
        target: SystemServices
        function onVolumeSnapshotReady(value, muted, errorString) {
            root.currentVolume = Math.max(0, Math.min(1, value));
        }
        function onBrightnessSnapshotReady(value, errorString) {
            root.currentBrightness = Math.max(0, Math.min(1, value));
        }
    }

    anchors.fill: parent

    Column {
        anchors.fill: parent
        anchors.margins: 2
        spacing: 8

        // Volume Slider
        Item {
            width: parent.width
            height: 28

            Row {
                anchors.fill: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.currentVolume === 0 ? "󰖁" : (root.currentVolume < 0.5 ? "󰕿" : "󰕾")
                    font.family: root.iconFontFamily
                    font.pixelSize: Math.round(15 * root.iconFontSize / 18.0)
                    color: "white"
                    width: 20
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 28
                    height: 18
                    radius: 9
                    color: "#2c2c2e"

                    Rectangle {
                        height: parent.height
                        radius: 9
                        color: "#0a84ff"
                        width: parent.width * root.currentVolume
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (mouse) => applyVolume(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) applyVolume(mouse.x); }

                        function applyVolume(mouseX) {
                            const val = Math.max(0, Math.min(1, mouseX / width));
                            root.currentVolume = val;
                            SystemServices.setVolume(val);
                        }
                    }
                }
            }
        }

        // Brightness Slider
        Item {
            width: parent.width
            height: 28

            Row {
                anchors.fill: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰃟"
                    font.family: root.iconFontFamily
                    font.pixelSize: Math.round(15 * root.iconFontSize / 18.0)
                    color: "white"
                    width: 20
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 28
                    height: 18
                    radius: 9
                    color: "#2c2c2e"

                    Rectangle {
                        height: parent.height
                        radius: 9
                        color: "#ffd60a"
                        width: parent.width * root.currentBrightness
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (mouse) => applyBrightness(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) applyBrightness(mouse.x); }

                        function applyBrightness(mouseX) {
                            const val = Math.max(0.05, Math.min(1, mouseX / width));
                            root.currentBrightness = val;
                            SystemServices.setBrightness(val);
                        }
                    }
                }
            }
        }

        // Status Row (Settings & System)
        Row {
            width: parent.width
            spacing: 8
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: (parent.width - 8) / 2
                height: 26
                radius: 8
                color: cfgMouse.containsMouse ? "#3a3a3c" : "#2c2c2e"

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "󰒓"
                        font.family: root.iconFontFamily
                        font.pixelSize: Math.round(12 * root.iconFontSize / 18.0)
                        color: "white"
                    }
                    Text {
                        text: "Settings"
                        font.family: root.textFontFamily
                        font.pixelSize: Math.round(11 * root.bodyFontSize / 16.0)
                        color: "white"
                    }
                }

                MouseArea {
                    id: cfgMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SystemServices.openConfigApp()
                }
            }

            Rectangle {
                width: (parent.width - 8) / 2
                height: 26
                radius: 8
                color: termMouse.containsMouse ? "#3a3a3c" : "#2c2c2e"

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: "󰄛"
                        font.family: root.iconFontFamily
                        font.pixelSize: Math.round(12 * root.iconFontSize / 18.0)
                        color: "white"
                    }
                    Text {
                        text: "System"
                        font.family: root.textFontFamily
                        font.pixelSize: Math.round(11 * root.bodyFontSize / 16.0)
                        color: "white"
                    }
                }

                MouseArea {
                    id: termMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SystemServices.openSettings()
                }
            }
        }
    }
}
