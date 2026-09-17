import QtQuick
import IslandBackend

Item {
    id: root

    property bool open: false
    property string iconFontFamily: "Sans Serif"
    property string textFontFamily: "Sans Serif"
    property real topOffset: (userConfig && userConfig.notchExpandedPaddingVertical !== undefined ? userConfig.notchExpandedPaddingVertical : 6) + 24 + 4
    property real rightOffset: (userConfig && userConfig.notchExpandedPaddingHorizontal !== undefined ? userConfig.notchExpandedPaddingHorizontal : 8) + 12

    signal closeRequested()
    signal openSettingsRequested()

    readonly property var userConfig: UserConfig

    anchors.fill: parent
    visible: opacity > 0.001
    opacity: root.open ? 1.0 : 0.0
    z: 200

    readonly property bool isOpen: root.open
    onIsOpenChanged: {
        if (isOpen) {
            submenuFlickable.contentY = 0;
        }
    }

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

    // Agent submenu styled floating popover card
    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: root.topOffset
        anchors.right: parent.right
        anchors.rightMargin: root.rightOffset
        width: Math.min(parent.width - 24, 250)

        readonly property real maxAvailableHeight: parent ? Math.max(60, parent.height - card.y - 8) : 160
        readonly property real desiredHeight: submenuHeader.height + headerDivider.height + submenuLayout.implicitHeight + 16
        height: Math.min(280, Math.min(maxAvailableHeight, desiredHeight))

        radius: StyleTokens.radiusModule
        color: StyleTokens.panel
        border.width: 1
        border.color: StyleTokens.inputBorder
        clip: true

        transformOrigin: Item.TopRight
        scale: root.open ? 1.0 : 0.94

        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        // Prevent backdrop click through
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {}
        }

        // Header (Pinned at top of popover)
        Item {
            id: submenuHeader
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.right: parent.right
            anchors.rightMargin: 6
            height: 20

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: "DYNAMIC RESIZING"
                font.family: root.textFontFamily
                font.pixelSize: 10
                font.weight: Font.Bold
                color: StyleTokens.textTertiary
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: closeSubmenuMouse.containsMouse ? StyleTokens.moduleHover : "transparent"

                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: root.iconFontFamily
                    font.pixelSize: 9
                    color: StyleTokens.textSecondary
                }

                MouseArea {
                    id: closeSubmenuMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // Divider
        Rectangle {
            id: headerDivider
            anchors.top: submenuHeader.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: StyleTokens.inputBorder
        }

        // Scrollable content viewport
        Flickable {
            id: submenuFlickable
            anchors.top: headerDivider.bottom
            anchors.topMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.right: parent.right
            anchors.rightMargin: submenuScrollTrack.visible ? 8 : 4
            contentWidth: width
            contentHeight: submenuLayout.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: submenuLayout
                width: submenuFlickable.width
                spacing: 3

                // Section Header
                Item {
                    width: parent.width
                    height: 16

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: "VIEW EXPANSION"
                        font.family: root.textFontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: StyleTokens.textTertiary
                    }
                }

                // Mode Rows
                Repeater {
                    model: [
                        {
                            id: "full",
                            name: "Full View (Expanded)",
                            icon: "󰍹",
                            maxPct: root.userConfig ? root.userConfig.dynamicResizeMaxPctFull : 40,
                            isEnabled: (root.userConfig && root.userConfig.dynamicResizeEnabledFull) ? true : false,
                            toggle: function() {
                                if (root.userConfig)
                                    root.userConfig.setDynamicResizeEnabledFull(!root.userConfig.dynamicResizeEnabledFull);
                            }
                        },
                        {
                            id: "minimum",
                            name: "Minimum View (Pill)",
                            icon: "󰝤",
                            maxPct: root.userConfig ? root.userConfig.dynamicResizeMaxPctMinimum : 50,
                            isEnabled: (root.userConfig && root.userConfig.dynamicResizeEnabledMinimum) ? true : false,
                            toggle: function() {
                                if (root.userConfig)
                                    root.userConfig.setDynamicResizeEnabledMinimum(!root.userConfig.dynamicResizeEnabledMinimum);
                            }
                        },
                        {
                            id: "circle",
                            name: "Circle View",
                            icon: "󰪥",
                            maxPct: root.userConfig ? root.userConfig.dynamicResizeMaxPctCircle : 60,
                            isEnabled: (root.userConfig && root.userConfig.dynamicResizeEnabledCircle) ? true : false,
                            toggle: function() {
                                if (root.userConfig)
                                    root.userConfig.setDynamicResizeEnabledCircle(!root.userConfig.dynamicResizeEnabledCircle);
                            }
                        }
                    ]

                    delegate: Rectangle {
                        id: submenuItem
                        readonly property bool isSelected: modelData.isEnabled
                        width: submenuLayout.width
                        height: 34
                        radius: StyleTokens.radiusButton
                        color: itemMouse.containsMouse
                            ? StyleTokens.moduleHover
                            : (submenuItem.isSelected ? StyleTokens.module : "transparent")

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 8
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20
                                height: 20
                                radius: 10
                                color: submenuItem.isSelected ? Qt.rgba(StyleTokens.accent.r, StyleTokens.accent.g, StyleTokens.accent.b, 0.2) : StyleTokens.module

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.family: root.iconFontFamily
                                    font.pixelSize: 11
                                    color: submenuItem.isSelected ? StyleTokens.accent : StyleTokens.textSecondary
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 20 - 6 - switchContainer.width - 10
                                spacing: 1

                                Text {
                                    text: modelData.name
                                    font.family: root.textFontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: submenuItem.isSelected ? StyleTokens.textPrimary : StyleTokens.textSecondary
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Row {
                                    spacing: 3
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: submenuItem.isSelected ? StyleTokens.success : StyleTokens.textDisabled
                                    }
                                    Text {
                                        text: submenuItem.isSelected ? ("+" + modelData.maxPct + "% max") : "Disabled"
                                        font.family: root.textFontFamily
                                        font.pixelSize: 9
                                        color: submenuItem.isSelected ? StyleTokens.textSecondary : StyleTokens.textDisabled
                                    }
                                }
                            }

                            Item {
                                id: switchContainer
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 16

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: submenuItem.isSelected ? StyleTokens.accent : (StyleTokens.isDark ? "#38383a" : "#c7c7cc")

                                    Behavior on color { ColorAnimation { duration: 160 } }

                                    Rectangle {
                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: "#ffffff"
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: submenuItem.isSelected ? parent.width - width - 2 : 2

                                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.toggle()
                        }
                    }
                }

                // Section Divider
                Rectangle {
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 1
                    color: StyleTokens.inputBorder
                }

                // Footer: Settings Link
                Rectangle {
                    id: settingsItem
                    width: submenuLayout.width
                    height: 28
                    radius: StyleTokens.radiusButton
                    color: settingsItemMouse.containsMouse ? StyleTokens.moduleHover : "transparent"

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰒓"
                            font.family: root.iconFontFamily
                            font.pixelSize: 11
                            color: settingsItemMouse.containsMouse ? StyleTokens.accent : StyleTokens.textSecondary
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Configure in Settings"
                            font.family: root.textFontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: settingsItemMouse.containsMouse ? StyleTokens.textPrimary : StyleTokens.textSecondary
                            width: parent.width - 11 - 6 - 12
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰅂"
                            font.family: root.iconFontFamily
                            font.pixelSize: 10
                            color: settingsItemMouse.containsMouse ? StyleTokens.accent : StyleTokens.textTertiary
                        }
                    }

                    MouseArea {
                        id: settingsItemMouse
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

        // Scrollbar track & thumb
        Item {
            id: submenuScrollTrack
            visible: submenuFlickable.contentHeight > submenuFlickable.height
            anchors.top: submenuFlickable.top
            anchors.bottom: submenuFlickable.bottom
            anchors.right: parent.right
            anchors.rightMargin: 2
            width: 6

            Rectangle {
                id: submenuScrollThumb
                anchors.horizontalCenter: parent.horizontalCenter
                width: 3
                radius: 1.5
                color: thumbMouse.containsMouse || thumbMouse.pressed ? "#80ffffff" : "#40ffffff"
                height: Math.max(10, submenuFlickable.height * (submenuFlickable.height / Math.max(1, submenuFlickable.contentHeight)))
                y: (submenuFlickable.contentY / Math.max(1, (submenuFlickable.contentHeight - submenuFlickable.height))) * (submenuFlickable.height - height)
            }

            MouseArea {
                id: thumbMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                property real dragStartY: 0
                property real startContentY: 0

                onPressed: (mouse) => {
                    dragStartY = mouse.y;
                    startContentY = submenuFlickable.contentY;
                    const trackH = submenuScrollTrack.height - submenuScrollThumb.height;
                    if (trackH > 0 && (mouse.y < submenuScrollThumb.y || mouse.y > submenuScrollThumb.y + submenuScrollThumb.height)) {
                        const ratio = Math.max(0, Math.min(1.0, (mouse.y - submenuScrollThumb.height / 2) / trackH));
                        submenuFlickable.contentY = ratio * (submenuFlickable.contentHeight - submenuFlickable.height);
                    }
                }

                onPositionChanged: (mouse) => {
                    if (!pressed) return;
                    const trackH = submenuScrollTrack.height - submenuScrollThumb.height;
                    if (trackH > 0) {
                        const ratio = Math.max(0, Math.min(1.0, (mouse.y - submenuScrollThumb.height / 2) / trackH));
                        submenuFlickable.contentY = ratio * (submenuFlickable.contentHeight - submenuFlickable.height);
                    }
                }
            }
        }

        // Mouse wheel scrolling support
        WheelHandler {
            target: submenuFlickable
            orientation: Qt.Vertical
            onWheel: (event) => {
                const delta = event.angleDelta.y;
                const maxScroll = Math.max(0, submenuFlickable.contentHeight - submenuFlickable.height);
                submenuFlickable.contentY = Math.max(0, Math.min(maxScroll, submenuFlickable.contentY - delta));
                event.accepted = true;
            }
        }
    }
}
