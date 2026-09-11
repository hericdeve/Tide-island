import QtQuick
import IslandBackend

Item {
    id: root

    property bool open: false
    property string iconFontFamily: "Sans Serif"
    property string textFontFamily: "Sans Serif"

    signal closeRequested()
    signal openSettingsRequested()

    readonly property var userConfig: UserConfig

    anchors.fill: parent
    visible: opacity > 0.001
    opacity: root.open ? 1.0 : 0.0
    z: 200

    Behavior on opacity {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    // Dismiss backdrop
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        onClicked: root.closeRequested()
    }

    // Modal Popover Card
    Rectangle {
        id: card
        width: 320
        anchors.centerIn: parent
        height: cardColumn.implicitHeight + 28
        radius: 16
        color: "#f51a1c22"
        border.width: 1
        border.color: "#30ffffff"
        scale: root.open ? 1.0 : 0.94

        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Prevent backdrop click through
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {}
        }

        Column {
            id: cardColumn
            anchors.top: parent.top
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            spacing: 12

            // Header: Title + Close Button
            Row {
                width: parent.width
                spacing: 8

                Item {
                    width: 24
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: "#200a84ff"
                        border.width: 1
                        border.color: "#400a84ff"

                        Text {
                            anchors.centerIn: parent
                            text: "󰁌"
                            font.family: root.iconFontFamily
                            font.pixelSize: 13
                            color: "#0a84ff"
                        }
                    }
                }

                Column {
                    width: parent.width - 24 - 24 - 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Dynamic Resizing"
                        font.family: root.textFontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }

                    Text {
                        text: "Temporarily expands island for long content"
                        font.family: root.textFontFamily
                        font.pixelSize: 10
                        color: "#8e8e93"
                    }
                }

                // Close Button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: closeMouse.pressed ? "#44ffffff" : (closeMouse.containsMouse ? "#24ffffff" : "#14ffffff")
                    border.width: 1
                    border.color: closeMouse.containsMouse ? "#33ffffff" : "transparent"

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: root.iconFontFamily
                        font.pixelSize: 11
                        color: closeMouse.containsMouse ? StyleTokens.textOnHover : StyleTokens.textTertiary
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

            // Divider
            Rectangle {
                width: parent.width
                height: 1
                color: "#1affffff"
            }

            // Mode Toggle Items
            Column {
                width: parent.width
                spacing: 8

                // 1. Full View (Expanded Mode)
                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 10
                    color: fullRowMouse.containsMouse ? "#14ffffff" : "#0cffffff"
                    border.width: 1
                    border.color: fullRowMouse.containsMouse ? "#24ffffff" : "#14ffffff"

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        width: parent.width - 64

                        Text {
                            text: "󰍹"
                            font.family: root.iconFontFamily
                            font.pixelSize: 15
                            color: (root.userConfig && root.userConfig.dynamicResizeEnabledFull) ? "#0a84ff" : "#636366"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: "Full View (Expanded)"
                                font.family: root.textFontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: "#ffffff"
                            }

                            Text {
                                text: "Max expansion: +" + (root.userConfig ? root.userConfig.dynamicResizeMaxPctFull : 40) + "%"
                                font.family: root.textFontFamily
                                font.pixelSize: 10
                                color: "#8e8e93"
                            }
                        }
                    }

                    // iOS-style Switch
                    Rectangle {
                        id: fullSwitch
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        height: 22
                        radius: 11
                        color: (root.userConfig && root.userConfig.dynamicResizeEnabledFull) ? "#30d158" : "#38383a"

                        Behavior on color { ColorAnimation { duration: 160 } }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: (root.userConfig && root.userConfig.dynamicResizeEnabledFull) ? parent.width - width - 2 : 2

                            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                    }

                    MouseArea {
                        id: fullRowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.userConfig)
                                root.userConfig.setDynamicResizeEnabledFull(!root.userConfig.dynamicResizeEnabledFull);
                        }
                    }
                }

                // 2. Minimum View (Pill Mode)
                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 10
                    color: minRowMouse.containsMouse ? "#14ffffff" : "#0cffffff"
                    border.width: 1
                    border.color: minRowMouse.containsMouse ? "#24ffffff" : "#14ffffff"

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        width: parent.width - 64

                        Text {
                            text: "󰝤"
                            font.family: root.iconFontFamily
                            font.pixelSize: 15
                            color: (root.userConfig && root.userConfig.dynamicResizeEnabledMinimum) ? "#0a84ff" : "#636366"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: "Minimum View (Pill)"
                                font.family: root.textFontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: "#ffffff"
                            }

                            Text {
                                text: "Max expansion: +" + (root.userConfig ? root.userConfig.dynamicResizeMaxPctMinimum : 50) + "%"
                                font.family: root.textFontFamily
                                font.pixelSize: 10
                                color: "#8e8e93"
                            }
                        }
                    }

                    // Switch
                    Rectangle {
                        id: minSwitch
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        height: 22
                        radius: 11
                        color: (root.userConfig && root.userConfig.dynamicResizeEnabledMinimum) ? "#30d158" : "#38383a"

                        Behavior on color { ColorAnimation { duration: 160 } }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: (root.userConfig && root.userConfig.dynamicResizeEnabledMinimum) ? parent.width - width - 2 : 2

                            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                    }

                    MouseArea {
                        id: minRowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.userConfig)
                                root.userConfig.setDynamicResizeEnabledMinimum(!root.userConfig.dynamicResizeEnabledMinimum);
                        }
                    }
                }

                // 3. Circle View Mode
                Rectangle {
                    width: parent.width
                    height: 44
                    radius: 10
                    color: circleRowMouse.containsMouse ? "#14ffffff" : "#0cffffff"
                    border.width: 1
                    border.color: circleRowMouse.containsMouse ? "#24ffffff" : "#14ffffff"

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        width: parent.width - 64

                        Text {
                            text: "󰪥"
                            font.family: root.iconFontFamily
                            font.pixelSize: 15
                            color: (root.userConfig && root.userConfig.dynamicResizeEnabledCircle) ? "#0a84ff" : "#636366"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: "Circle View"
                                font.family: root.textFontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: "#ffffff"
                            }

                            Text {
                                text: "Max expansion: +" + (root.userConfig ? root.userConfig.dynamicResizeMaxPctCircle : 60) + "%"
                                font.family: root.textFontFamily
                                font.pixelSize: 10
                                color: "#8e8e93"
                            }
                        }
                    }

                    // Switch
                    Rectangle {
                        id: circleSwitch
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        height: 22
                        radius: 11
                        color: (root.userConfig && root.userConfig.dynamicResizeEnabledCircle) ? "#30d158" : "#38383a"

                        Behavior on color { ColorAnimation { duration: 160 } }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            x: (root.userConfig && root.userConfig.dynamicResizeEnabledCircle) ? parent.width - width - 2 : 2

                            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                    }

                    MouseArea {
                        id: circleRowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.userConfig)
                                root.userConfig.setDynamicResizeEnabledCircle(!root.userConfig.dynamicResizeEnabledCircle);
                        }
                    }
                }
            }

            // Footer Link: Settings button
            Rectangle {
                width: parent.width
                height: 28
                radius: 6
                color: settingsBtnMouse.pressed ? "#20ffffff" : (settingsBtnMouse.containsMouse ? "#12ffffff" : "transparent")

                Behavior on color { ColorAnimation { duration: 100 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "Configure expansion limits in Settings"
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: settingsBtnMouse.containsMouse ? StyleTokens.textOnHover : StyleTokens.accent
                    }

                    Text {
                        text: "󰅂"
                        font.family: root.iconFontFamily
                        font.pixelSize: 10
                        color: settingsBtnMouse.containsMouse ? StyleTokens.textOnHover : StyleTokens.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: settingsBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closeRequested();
                        root.openSettingsRequested();
                    }
                }
            }
        }
    }
}
