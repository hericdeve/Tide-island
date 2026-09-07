import QtQuick
import IslandBackend

Item {
    id: root

    property int currentPage: 0
    property var pages: []
    property bool isEditMode: false
    property bool cameraMirrorActive: false
    property int batteryCapacity: -1
    property bool isCharging: false
    property string iconFontFamily: "Sans Serif"
    property string textFontFamily: "Sans Serif"

    signal pageSelected(int pageIndex)
    signal addPageRequested()
    signal shelfRequested()
    signal cameraToggleRequested()
    signal editModeToggleRequested()
    signal settingsRequested()
    signal closeRequested()

    height: 24

    // Left: Page tabs & Shelf
    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // Page tabs repeater
        Repeater {
            model: root.pages ? root.pages.length : 1

            Rectangle {
                id: tabPill
                readonly property bool isActive: root.currentPage === index
                width: tabText.implicitWidth + 16
                height: 22
                radius: 11
                color: isActive ? "#2c2c2e" : "transparent"
                border.width: isActive ? 0 : 1
                border.color: "#3a3a3c"

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: index === 0 ? "󰋜" : "󰐝"
                        color: tabPill.isActive ? "white" : "#8e8e93"
                        font.family: root.iconFontFamily
                        font.pixelSize: 12
                    }

                    Text {
                        id: tabText
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (root.pages && root.pages[index] && root.pages[index].title)
                                return root.pages[index].title;
                            return index === 0 ? "Home" : "Page " + (index + 1);
                        }
                        color: tabPill.isActive ? "white" : "#8e8e93"
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                        font.weight: tabPill.isActive ? Font.DemiBold : Font.Normal
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pageSelected(index)
                }
            }
        }

        // Add Page button in edit mode
        Rectangle {
            visible: root.isEditMode
            width: 26
            height: 22
            radius: 11
            color: addPageMouse.containsMouse ? "#323236" : "transparent"
            border.width: 1
            border.color: "#b56cff"

            Text {
                anchors.centerIn: parent
                text: "󰐕"
                color: "#b56cff"
                font.family: root.iconFontFamily
                font.pixelSize: 13
            }

            MouseArea {
                id: addPageMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.addPageRequested()
            }
        }

        // File Shelf button
        Rectangle {
            width: 28
            height: 22
            radius: 11
            color: shelfMouse.containsMouse ? "#323236" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "󰉋"
                color: shelfMouse.containsMouse ? "white" : "#8e8e93"
                font.family: root.iconFontFamily
                font.pixelSize: 13
            }

            MouseArea {
                id: shelfMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.shelfRequested()
            }
        }
    }

    // Right: Action controls & status
    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Camera Mirror button
        Rectangle {
            width: 22
            height: 22
            radius: 11
            color: root.cameraMirrorActive ? "#b56cff" : (camMouse.containsMouse ? "#323236" : "transparent")

            Text {
                anchors.centerIn: parent
                text: "󰄀"
                color: root.cameraMirrorActive ? "white" : (camMouse.containsMouse ? "white" : "#8e8e93")
                font.family: root.iconFontFamily
                font.pixelSize: 13
            }

            MouseArea {
                id: camMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cameraToggleRequested()
            }
        }

        // Edit Mode Toggle button (pencil icon beside settings)
        Rectangle {
            width: 22
            height: 22
            radius: 11
            color: root.isEditMode ? "#b56cff" : (editMouse.containsMouse ? "#323236" : "transparent")

            Text {
                anchors.centerIn: parent
                text: "󰏫"
                color: root.isEditMode ? "white" : (editMouse.containsMouse ? "white" : "#8e8e93")
                font.family: root.iconFontFamily
                font.pixelSize: 13
            }

            MouseArea {
                id: editMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.editModeToggleRequested()
            }
        }

        // Settings gear icon
        Rectangle {
            width: 22
            height: 22
            radius: 11
            color: settingsMouse.containsMouse ? "#323236" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "󰒓"
                color: settingsMouse.containsMouse ? "white" : "#8e8e93"
                font.family: root.iconFontFamily
                font.pixelSize: 13
            }

            MouseArea {
                id: settingsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingsRequested()
            }
        }

        // Battery indicator
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: root.batteryCapacity >= 0

            Text {
                text: root.batteryCapacity + "%"
                color: "white"
                font.pixelSize: 11
                font.family: root.textFontFamily
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.isCharging ? "󰂄" : "󰁹"
                color: root.isCharging ? "#30d158" : (root.batteryCapacity <= 20 ? "#ff453a" : "#8e8e93")
                font.pixelSize: 14
                font.family: root.iconFontFamily
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Close button
        Rectangle {
            width: 22
            height: 22
            radius: 11
            color: closeMouse.containsMouse ? "#323236" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: closeMouse.containsMouse ? "white" : "#8e8e93"
                font.family: root.iconFontFamily
                font.pixelSize: 12
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }
    }
}
