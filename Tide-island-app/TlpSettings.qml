import QtQuick
import QtQuick.Controls
import TideIsland 1.0

Rectangle {
    id: root

    property int revision: 0
    readonly property var permissionOptions: [
        { "label": "Disabled", "value": "skip" },
        { "label": "Polkit", "value": "polkit" }
    ]

    color: Theme.cardBgColor
    radius: 16
    border.width: 1
    border.color: Theme.splitLineColor
    implicitHeight: tlpColumn.implicitHeight + 36

    function textValue(key, fallback) {
        return String(ConfigStore.value(key, fallback))
    }

    function permissionMode() {
        revision
        const mode = textValue("tlpPermissionMode", "skip").trim()
        if (mode === "skip" || mode === "")
            return "skip"
        return "polkit"
    }

    function savePermissionMode(mode) {
        ConfigStore.setValue("tlpPermissionMode", mode)
        ConfigStore.remove("tlpSudoPassword")
        ConfigStore.save()
        revision += 1
    }

    Column {
        id: tlpColumn

        anchors.top: parent.top
        anchors.topMargin: 18
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 18
        spacing: 16

        PermissionModeRow {
            width: parent.width
        }
    }

    component PermissionModeRow: Item {
        id: row

        height: 49

        Text {
            id: rowTitle

            text: "TLP Permission"
            anchors.left: parent.left
            anchors.top: parent.top
            color: Theme.textColor
            font.family: Theme.textFontFamily
            font.pixelSize: 18
        }

        Text {
            text: root.permissionMode() === "skip"
                ? "Hide TLP power profile controls"
                : "Authenticate using system Polkit dialog when switching profiles"
            anchors.left: rowTitle.left
            anchors.top: rowTitle.bottom
            anchors.topMargin: 5
            width: Math.max(80, parent.width - permissionGroup.width - 28)
            color: Theme.subtleTextColor
            elide: Text.ElideRight
            font.family: Theme.textFontFamily
            font.pixelSize: 14
        }

        ButtonGroup {
            id: permissionGroup

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            options: root.permissionOptions
            selectedValue: root.permissionMode()

            onSelected: function(value) {
                root.savePermissionMode(value)
            }
        }
    }

    component ButtonGroup: Row {
        id: group

        signal selected(string value)

        property var options: []
        property string selectedValue: ""

        width: implicitWidth
        height: implicitHeight
        spacing: 6

        Repeater {
            model: group.options

            Rectangle {
                id: option

                property bool selectedState: group.selectedValue === modelData.value

                width: Math.max(74, optionText.implicitWidth + 24)
                height: 36
                radius: 7
                color: selectedState ? Theme.cardBgColor
                                     : optionMouse.pressed ? Theme.controlPressedColor
                                                           : Theme.componentBgColor
                border.width: 1
                border.color: Theme.inputBorderColor

                Behavior on color {
                    ColorAnimation { duration: Theme.animationDuration }
                }

                Behavior on border.color {
                    ColorAnimation { duration: Theme.animationDuration }
                }

                Text {
                    id: optionText

                    anchors.centerIn: parent
                    text: modelData.label
                    color: option.selectedState ? Theme.textColor : Theme.secondaryTextColor
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                    font.weight: option.selectedState ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    id: optionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: group.selected(modelData.value)
                }
            }
        }
    }
}
