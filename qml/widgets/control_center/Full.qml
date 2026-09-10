import QtQuick
import IslandBackend
import "../components"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

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

                WidgetIconGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: root.currentVolume === 0 ? "󰖁" : (root.currentVolume < 0.5 ? "󰕿" : "󰕾")
                    size: 15
                    color: StyleTokens.textPrimary
                    widgetContext: root.widgetContext
                    width: 20
                }

                WidgetScrubberSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 28
                    baseTrackHeight: 14
                    value: root.currentVolume
                    fillColor: StyleTokens.accent
                    trackColor: StyleTokens.track
                    onValueChanged: newVal => {
                        root.currentVolume = newVal;
                        SystemServices.setVolume(newVal);
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

                WidgetIconGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "󰃟"
                    size: 15
                    color: StyleTokens.textPrimary
                    widgetContext: root.widgetContext
                    width: 20
                }

                WidgetScrubberSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 28
                    baseTrackHeight: 14
                    value: root.currentBrightness
                    fillColor: StyleTokens.warning
                    trackColor: StyleTokens.track
                    onValueChanged: newVal => {
                        root.currentBrightness = Math.max(0.05, newVal);
                        SystemServices.setBrightness(root.currentBrightness);
                    }
                }
            }
        }

        // Status Row (Settings & System)
        Row {
            width: parent.width
            spacing: 8
            anchors.horizontalCenter: parent.horizontalCenter

            WidgetActionButton {
                width: (parent.width - 8) / 2
                variant: "capsule"
                buttonStyle: "secondary"
                icon: "󰒓"
                label: "Settings"
                widgetContext: root.widgetContext
                onClicked: SystemServices.openConfigApp()
            }

            WidgetActionButton {
                width: (parent.width - 8) / 2
                variant: "capsule"
                buttonStyle: "secondary"
                icon: "󰄛"
                label: "System"
                widgetContext: root.widgetContext
                onClicked: SystemServices.openSettings()
            }
        }
    }
}
