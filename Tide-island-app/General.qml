import TideIsland 1.0
import QtQuick.Controls
import QtQuick

PagePanel {
    id: root

    function intValue(key, fallback) {
        return String(ConfigStore.value(key, fallback))
    }

    function saveInt(key, value, fallback, minimumValue, maximumValue) {
        if (String(value).trim().length === 0) {
            return fallback
        }

        const parsedValue = Number(value)
        if (isNaN(parsedValue)) {
            return fallback
        }

        const roundedValue = Math.min(maximumValue, Math.max(minimumValue, Math.round(parsedValue)))
        ConfigStore.setValue(key, roundedValue)
        ConfigStore.save()
        return roundedValue
    }

    function boolValue(key, fallback) {
        const val = ConfigStore.value(key, fallback)
        return val === true || val === "true"
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: content.height
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds
        interactive: false

        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: function(event) {
                const rawDelta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 64
                const maxY = Math.max(0, scroller.contentHeight - scroller.height)
                scroller.contentY = Math.max(0, Math.min(maxY, scroller.contentY - rawDelta))
                event.accepted = true
            }
        }

        Item {
            id: content
            width: scroller.width
            height: tlpPanel.y + tlpPanel.height + 40

            Text {
                id: title
                font.family: Theme.titleFontFamily
                text: "General"
                color: Theme.textColor
                font.pixelSize: 30
                x: 60
                y: 50
            }

            // 1. Desktop & Window Layering
            Text {
                id: desktopTitle
                text: "Desktop & Window Layering"
                anchors.top: title.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
                color: Theme.textColor
            }

            Rectangle {
                id: desktopPanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: desktopTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: desktopColumn.implicitHeight + 36

                Column {
                    id: desktopColumn
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    LayerSelectionRow {
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Reserved Screen Space"
                        description: "Screen margin reserved at the edge to prevent windows overlapping the island (px). Set to 0 to overlap an existing bar (e.g. Noctalia/Waybar)."
                        keyName: "islandExclusiveZone"
                        fallbackText: "45"
                        numeric: true
                        minimumValue: 0
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ToggleRow {
                        title: "Hide in Fullscreen"
                        description: "Automatically retract the island when an active window enters fullscreen"
                        keyName: "hideNotchInFullscreen"
                        fallbackState: true
                        width: parent.width
                    }
                }
            }

            // 2. Power Management (TLP)
            Text {
                id: tlpTitle
                text: "Power Management"
                anchors.top: desktopPanel.bottom
                anchors.topMargin: 34
                anchors.left: parent.left
                anchors.leftMargin: 32
                anchors.right: parent.right
                anchors.rightMargin: 40
                font.family: Theme.titleFontFamily
                font.pixelSize: 23
                color: Theme.textColor
            }

            TlpSettings {
                id: tlpPanel
                anchors.top: tlpTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: implicitHeight
            }
        }
    }

    component SplitLine: Rectangle {
        height: 1
        color: Theme.splitLineColor
    }

    component ConfigRow: Item {
        id: row

        property string title: ""
        property string description: ""
        property string keyName: ""
        property string fallbackText: ""
        property bool numeric: false
        property int minimumValue: 1
        property int maximumValue: 1000

        height: 49

        Text {
            id: rowTitle
            text: row.title
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            color: Theme.textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: row.description
            font.family: Theme.textFontFamily
            font.pixelSize: 14
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            anchors.left: rowTitle.left
            width: Math.max(80, parent.width - field.width - 28)
            elide: Text.ElideRight
            color: Theme.subtleTextColor
        }

        ConfigTextField {
            id: field
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: row.numeric ? 100 : 230
            height: 36
            placeholderText: row.fallbackText
            inputMethodHints: row.numeric ? Qt.ImhDigitsOnly : Qt.ImhNone
            validator: row.numeric ? intValidator : null

            Component.onCompleted: {
                text = root.intValue(row.keyName, Number(row.fallbackText))
            }

            onAccepted: row.commit()
            onEditingFinished: row.commit()
        }

        IntValidator {
            id: intValidator
            bottom: row.minimumValue
            top: row.maximumValue
        }

        function commit() {
            if (numeric) {
                field.text = String(root.saveInt(row.keyName, field.text, Number(row.fallbackText), row.minimumValue, row.maximumValue))
            }
        }
    }

    component ToggleRow: Item {
        id: toggleRow

        property string title: ""
        property string description: ""
        property string keyName: ""
        property bool fallbackState: false
        property bool invert: false
        property bool checkedState: {
            const val = root.boolValue(keyName, fallbackState)
            return invert ? !val : val
        }

        height: 49

        Text {
            id: toggleRowTitle
            text: toggleRow.title
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            color: Theme.textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: toggleRow.description
            font.family: Theme.textFontFamily
            font.pixelSize: 14
            anchors.top: toggleRowTitle.bottom
            anchors.topMargin: 5
            anchors.left: toggleRowTitle.left
            width: Math.max(80, parent.width - toggleSwitch.width - 28)
            elide: Text.ElideRight
            color: Theme.subtleTextColor
        }

        Item {
            id: toggleSwitch
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            height: 26

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: 40
                height: 24
                radius: 12
                color: toggleRow.checkedState ? Theme.accentColor : Theme.componentBgColor
                border.width: 1
                border.color: toggleRow.checkedState ? Theme.accentColor : Theme.inputBorderColor

                Behavior on color {
                    ColorAnimation { duration: 180; easing.type: Easing.InOutQuad }
                }
            }

            Rectangle {
                width: 18
                height: 18
                radius: 9
                x: toggleRow.checkedState ? 22 : 6
                y: 4
                color: Theme.cardBgColor

                Behavior on x {
                    NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const next = !toggleRow.checkedState
                    toggleRow.checkedState = next
                    ConfigStore.setValue(toggleRow.keyName, toggleRow.invert ? !next : next)
                    ConfigStore.save()
                }
            }
        }
    }

    component LayerSelectionRow: Item {
        id: layerRow

        property string selectedLayer: String(ConfigStore.value("islandLayer", "top")).toLowerCase() === "overlay" ? "overlay" : "top"

        height: 49

        Text {
            id: layerTitle
            text: "Window Layer"
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            color: Theme.textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: "Render on 'Top' (standard bar) or 'Overlay' (above all windows and lock screens)"
            font.family: Theme.textFontFamily
            font.pixelSize: 14
            anchors.top: layerTitle.bottom
            anchors.topMargin: 5
            anchors.left: layerTitle.left
            width: Math.max(80, parent.width - buttonGroup.width - 28)
            elide: Text.ElideRight
            color: Theme.subtleTextColor
        }

        Row {
            id: buttonGroup
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: [
                    { label: "Top", value: "top" },
                    { label: "Overlay", value: "overlay" }
                ]

                Rectangle {
                    id: btn
                    readonly property bool selected: layerRow.selectedLayer === modelData.value

                    width: Math.max(76, btnText.implicitWidth + 20)
                    height: 36
                    radius: 7
                    color: selected ? Theme.cardBgColor
                                    : btnMouse.pressed ? Theme.controlPressedColor
                                                       : Theme.componentBgColor
                    border.width: 1
                    border.color: Theme.inputBorderColor

                    Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animationDuration } }

                    Text {
                        id: btnText
                        anchors.centerIn: parent
                        text: modelData.label
                        color: btn.selected ? Theme.textColor : Theme.secondaryTextColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 14
                        font.weight: btn.selected ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            layerRow.selectedLayer = modelData.value
                            ConfigStore.setValue("islandLayer", modelData.value)
                            ConfigStore.save()
                        }
                    }
                }
            }
        }
    }
}
