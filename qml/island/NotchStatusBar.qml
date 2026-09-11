import QtQuick
import IslandBackend

Item {
    id: root

    property int currentPage: 0
    property var pages: []
    property bool isEditMode: false
    property bool cameraMirrorActive: false
    property bool dynamicResizeToastActive: false
    property int batteryCapacity: -1
    property bool isCharging: false
    property string iconFontFamily: "Sans Serif"
    property string textFontFamily: "Sans Serif"

    readonly property var userConfig: UserConfig

    readonly property var currentPageData: (root.pages && (root.currentPage - 1) >= 0 && (root.currentPage - 1) < root.pages.length) ? root.pages[root.currentPage - 1] : null
    readonly property int currentSlotCount: Math.max(1, Math.min(6, (currentPageData && currentPageData.slots !== undefined) ? currentPageData.slots : 1))
    readonly property bool fileShelfActive: root.currentPage === 0

    signal pageSelected(int pageIndex)
    signal addPageRequested()
    signal setSlotsRequested(int pageIndex, int newSlotCount)
    signal shelfRequested()
    signal cameraToggleRequested()
    signal editModeToggleRequested()
    signal dynamicResizeToggleRequested()
    signal settingsRequested()
    signal closeRequested()
    signal movePageRequested(int fromIndex, int toIndex)

    height: 24

    // Left: Page dots & Shelf
    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Page Dots Switcher (matching Library dot pagination)
        Item {
            id: pageDotsContainer
            height: 24
            readonly property int dotCount: 1 + (root.pages ? root.pages.length : 1)
            width: 14 + (dotCount - 1) * 4 + (dotCount - 1) * 5

            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Row {
                id: pageDotsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Repeater {
                    model: 1 + (root.pages ? root.pages.length : 1)

                    Rectangle {
                        id: pageDot
                        readonly property int dotIndex: index
                        readonly property bool isActive: dotIndex === root.currentPage
                        width: isActive ? 14 : 4
                        height: 4
                        radius: 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: isActive ? "#ffffff" : (dotMouse.containsMouse ? "#636366" : "#38383a")

                        Behavior on width {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 180 }
                        }

                        MouseArea {
                            id: dotMouse
                            anchors.fill: parent
                            anchors.topMargin: -10
                            anchors.bottomMargin: -10
                            anchors.leftMargin: -4
                            anchors.rightMargin: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pageSelected(dotIndex)
                        }
                    }
                }
            }
        }

        // Integrated [+] Add Page button in edit mode
        Item {
            id: addPageBtn
            readonly property bool shouldShow: root.isEditMode
            width: shouldShow ? 20 : 0
            height: 20
            clip: true
            opacity: shouldShow ? 1.0 : 0.0
            scale: shouldShow ? 1.0 : 0.75
            transformOrigin: Item.Center
            visible: width > 0 || opacity > 0.001
            anchors.verticalCenter: parent.verticalCenter

            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale {
                NumberAnimation {
                    duration: 240
                    easing.type: addPageBtn.shouldShow ? Easing.OutBack : Easing.InCubic
                    easing.overshoot: 1.25
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 20
                height: 20
                radius: 10
                color: addPageMouse.pressed
                    ? "#38ffffff"
                    : (addPageMouse.containsMouse ? "#24ffffff" : "#14ffffff")
                border.width: 1
                border.color: addPageMouse.containsMouse ? "#33ffffff" : "#1affffff"

                Behavior on color { ColorAnimation { duration: 100 } }
                Behavior on border.color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰐕"
                    color: addPageMouse.containsMouse ? StyleTokens.textOnHover : StyleTokens.textSecondary
                    font.family: root.iconFontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                MouseArea {
                    id: addPageMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addPageRequested()
                }
            }
        }

        // Slot Manager Stepper (shown in edit mode beside Add Page button on widget pages)
        Rectangle {
            id: slotStepperCapsule
            readonly property bool shouldShow: root.isEditMode && root.currentPage > 0
            readonly property real targetWidth: 76
            width: shouldShow ? targetWidth : 0
            height: 20
            clip: true
            opacity: shouldShow ? 1.0 : 0.0
            scale: shouldShow ? 1.0 : 0.82
            transformOrigin: Item.Center
            visible: width > 0 || opacity > 0.001
            anchors.verticalCenter: parent.verticalCenter
            radius: 10
            color: "#12ffffff"

            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale {
                NumberAnimation {
                    duration: 250
                    easing.type: slotStepperCapsule.shouldShow ? Easing.OutBack : Easing.InCubic
                    easing.overshoot: 1.2
                }
            }

            Item {
                id: stepperRow
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4

                // Decrement slots button (pinned left)
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: decMouse.pressed ? "#38ffffff" : (decMouse.containsMouse ? "#24ffffff" : "transparent")
                    enabled: root.currentSlotCount > 1
                    opacity: enabled ? 1.0 : 0.35

                    Text {
                        anchors.centerIn: parent
                        text: "−"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: StyleTokens.textPrimary
                    }

                    MouseArea {
                        id: decMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.setSlotsRequested(root.currentPage, root.currentSlotCount - 1)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.currentSlotCount + " " + (root.currentSlotCount === 1 ? "Slot" : "Slots")
                    font.family: root.textFontFamily
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                    color: StyleTokens.textSecondary
                }

                // Increment slots button (pinned right)
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: incMouse.pressed ? "#38ffffff" : (incMouse.containsMouse ? "#24ffffff" : "transparent")
                    enabled: root.currentSlotCount < 6
                    opacity: enabled ? 1.0 : 0.35

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: StyleTokens.textPrimary
                    }

                    MouseArea {
                        id: incMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.setSlotsRequested(root.currentPage, root.currentSlotCount + 1)
                    }
                }
            }
        }

        // Page Reorder Stepper (shown in edit mode beside slot stepper on widget pages when multiple pages exist)
        Rectangle {
            id: reorderStepperCapsule
            readonly property bool shouldShow: root.isEditMode && root.currentPage > 0 && root.pages && root.pages.length > 1
            readonly property real targetWidth: 86
            width: shouldShow ? targetWidth : 0
            height: 20
            clip: true
            opacity: shouldShow ? 1.0 : 0.0
            scale: shouldShow ? 1.0 : 0.82
            transformOrigin: Item.Center
            visible: width > 0 || opacity > 0.001
            anchors.verticalCenter: parent.verticalCenter
            radius: 10
            color: "#12ffffff"

            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale {
                NumberAnimation {
                    duration: 260
                    easing.type: reorderStepperCapsule.shouldShow ? Easing.OutBack : Easing.InCubic
                    easing.overshoot: 1.2
                }
            }

            Item {
                id: reorderRow
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4

                // Move Left button (pinned left)
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: moveLeftMouse.pressed ? "#38ffffff" : (moveLeftMouse.containsMouse ? "#24ffffff" : "transparent")
                    enabled: (root.currentPage - 1) > 0
                    opacity: enabled ? 1.0 : 0.35

                    Text {
                        anchors.centerIn: parent
                        text: "󰁍"
                        font.family: root.iconFontFamily
                        font.pixelSize: 10
                        color: StyleTokens.textPrimary
                    }

                    MouseArea {
                        id: moveLeftMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            const fromIdx = root.currentPage - 1;
                            const toIdx = fromIdx - 1;
                            root.movePageRequested(fromIdx, toIdx);
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Page " + root.currentPage + " of " + (root.pages ? root.pages.length : 1)
                    font.family: root.textFontFamily
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                    color: StyleTokens.textSecondary
                }

                // Move Right button (pinned right)
                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: moveRightMouse.pressed ? "#38ffffff" : (moveRightMouse.containsMouse ? "#24ffffff" : "transparent")
                    enabled: (root.currentPage - 1) < (root.pages ? root.pages.length - 1 : 0)
                    opacity: enabled ? 1.0 : 0.35

                    Text {
                        anchors.centerIn: parent
                        text: "󰁔"
                        font.family: root.iconFontFamily
                        font.pixelSize: 10
                        color: StyleTokens.textPrimary
                    }

                    MouseArea {
                        id: moveRightMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            const fromIdx = root.currentPage - 1;
                            const toIdx = fromIdx + 1;
                            root.movePageRequested(fromIdx, toIdx);
                        }
                    }
                }
            }
        }
    }

    // Right: Action controls & status
    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // Camera Mirror button
        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: root.cameraMirrorActive ? "#38ffffff" : (camMouse.pressed ? "#38ffffff" : (camMouse.containsMouse ? "#1fffffff" : "transparent"))
            border.width: 1
            border.color: root.cameraMirrorActive ? "#4dffffff" : (camMouse.containsMouse ? "#2effffff" : "transparent")

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "󰄀"
                color: root.cameraMirrorActive ? StyleTokens.textOnAccent : (camMouse.containsMouse ? StyleTokens.textOnHover : StyleTokens.textSecondary)
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
            id: editBtnRect
            width: 24
            height: 24
            radius: 12
            color: root.isEditMode ? "#38ffffff" : (editMouse.pressed ? "#38ffffff" : (editMouse.containsMouse ? "#1fffffff" : "transparent"))
            border.width: 1
            border.color: root.isEditMode ? "#4dffffff" : (editMouse.containsMouse ? "#2effffff" : "transparent")
            scale: editMouse.pressed ? 0.88 : (root.isEditMode ? 1.05 : 1.0)

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

            Text {
                anchors.centerIn: parent
                text: "󰏫"
                color: root.isEditMode ? StyleTokens.textOnAccent : (editMouse.containsMouse ? StyleTokens.textOnHover : StyleTokens.textSecondary)
                font.family: root.iconFontFamily
                font.pixelSize: 13
                rotation: root.isEditMode ? 15 : 0
                Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            }

            MouseArea {
                id: editMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.editModeToggleRequested()
            }
        }

        // Closed Notch Style Toggle (Notch vs. Pill vs. Circle)
        Rectangle {
            id: notchModeToggleBtn
            width: 24
            height: 24
            radius: 12
            color: modeToggleMouse.pressed ? "#38ffffff" : (modeToggleMouse.containsMouse ? "#1fffffff" : "transparent")
            border.width: 1
            border.color: modeToggleMouse.containsMouse ? "#2effffff" : "transparent"

            readonly property string activeMode: (userConfig && userConfig.notchMode) ? userConfig.notchMode : "notch"

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            // Top screen bezel line (visible in Notch mode, faint in Pill mode, hidden in Circle mode)
            Rectangle {
                id: bezelLine
                anchors.horizontalCenter: parent.horizontalCenter
                y: 3.5
                width: 15
                height: 1.5
                radius: 0.75
                color: modeToggleMouse.containsMouse ? StyleTokens.textOnHover : StyleTokens.textSecondary
                opacity: notchModeToggleBtn.activeMode === "notch" ? 1.0 : (notchModeToggleBtn.activeMode === "pill" ? 0.35 : 0.0)

                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            // Morphing shape representing Notch (attached to bezel), Pill (floating capsule), or Circle (compact dial)
            Rectangle {
                id: modeShape
                anchors.horizontalCenter: parent.horizontalCenter
                y: notchModeToggleBtn.activeMode === "notch" ? 4.5 : (notchModeToggleBtn.activeMode === "pill" ? 9 : 7.25)
                width: notchModeToggleBtn.activeMode === "notch" ? 9 : (notchModeToggleBtn.activeMode === "pill" ? 14 : 9.5)
                height: notchModeToggleBtn.activeMode === "notch" ? 6.5 : (notchModeToggleBtn.activeMode === "pill" ? 6 : 9.5)
                radius: notchModeToggleBtn.activeMode === "notch" ? 2 : (notchModeToggleBtn.activeMode === "pill" ? 3 : 4.75)
                color: "transparent"
                border.width: 1.5
                border.color: modeToggleMouse.containsMouse ? StyleTokens.textOnHover : StyleTokens.textSecondary

                Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on radius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: 120 } }
            }

            // Tooltip badge showing active closed notch style name on hover
            Rectangle {
                id: modeTooltipBadge
                visible: opacity > 0.001
                opacity: modeToggleMouse.containsMouse ? 1.0 : 0.0
                anchors.top: parent.bottom
                anchors.topMargin: 5
                anchors.horizontalCenter: parent.horizontalCenter
                height: 18
                width: modeTooltipText.implicitWidth + 12
                radius: 9
                color: "#f01c1c1e"
                border.width: 1
                border.color: "#33ffffff"
                z: 100

                Behavior on opacity { NumberAnimation { duration: 120 } }

                Text {
                    id: modeTooltipText
                    anchors.centerIn: parent
                    text: {
                        if (notchModeToggleBtn.activeMode === "notch") return "Notch";
                        if (notchModeToggleBtn.activeMode === "pill") return "Pill";
                        if (notchModeToggleBtn.activeMode === "circle") return "Circle";
                        return "Notch";
                    }
                    color: "#ffffff"
                    font.family: root.textFontFamily
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: modeToggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (!userConfig) return;
                    const cur = userConfig.notchMode;
                    if (mouse.button === Qt.RightButton) {
                        if (cur === "notch") userConfig.setNotchMode("circle");
                        else if (cur === "circle") userConfig.setNotchMode("pill");
                        else userConfig.setNotchMode("notch");
                    } else {
                        if (cur === "notch") userConfig.setNotchMode("pill");
                        else if (cur === "pill") userConfig.setNotchMode("circle");
                        else userConfig.setNotchMode("notch");
                    }
                }
            }
        }

        // Dynamic Resize Quick-Access Toggle button
        Rectangle {
            id: resizeToggleBtn
            width: 24
            height: 24
            radius: 12
            color: root.dynamicResizeToastActive ? "#38ffffff" : (resizeMouse.pressed ? "#38ffffff" : (resizeMouse.containsMouse ? "#1fffffff" : "transparent"))
            border.width: 1
            border.color: root.dynamicResizeToastActive ? "#4dffffff" : (resizeMouse.containsMouse ? "#2effffff" : "transparent")

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "󰁌"
                color: root.dynamicResizeToastActive ? StyleTokens.textOnAccent : (resizeMouse.containsMouse ? StyleTokens.textOnHover : StyleTokens.textSecondary)
                font.family: root.iconFontFamily
                font.pixelSize: 13
            }

            // Tooltip badge showing "Dynamic Resizing" on hover
            Rectangle {
                id: resizeTooltipBadge
                visible: opacity > 0.001
                opacity: resizeMouse.containsMouse && !root.dynamicResizeToastActive ? 1.0 : 0.0
                anchors.top: parent.bottom
                anchors.topMargin: 5
                anchors.horizontalCenter: parent.horizontalCenter
                height: 18
                width: resizeTooltipText.implicitWidth + 12
                radius: 9
                color: "#f01c1c1e"
                border.width: 1
                border.color: "#33ffffff"
                z: 100

                Behavior on opacity { NumberAnimation { duration: 120 } }

                Text {
                    id: resizeTooltipText
                    anchors.centerIn: parent
                    text: "Dynamic Resizing"
                    color: StyleTokens.textPrimaryBright
                    font.family: root.textFontFamily
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: resizeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dynamicResizeToggleRequested()
            }
        }

        // Settings gear icon
        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: settingsMouse.pressed ? "#38ffffff" : (settingsMouse.containsMouse ? "#1fffffff" : "transparent")
            border.width: 1
            border.color: settingsMouse.containsMouse ? "#2effffff" : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "󰒓"
                color: settingsMouse.containsMouse ? StyleTokens.textOnHover : StyleTokens.textSecondary
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
                color: StyleTokens.textPrimaryBright
                font.pixelSize: 11
                font.family: root.textFontFamily
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.isCharging ? "󰂄" : "󰁹"
                color: root.isCharging ? StyleTokens.success : (root.batteryCapacity <= 20 ? StyleTokens.danger : StyleTokens.textSecondary)
                font.pixelSize: 14
                font.family: root.iconFontFamily
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Close button
        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: closeMouse.pressed ? StyleTokens.danger : (closeMouse.containsMouse ? Qt.rgba(StyleTokens.danger.r, StyleTokens.danger.g, StyleTokens.danger.b, 0.16) : "transparent")
            border.width: 1
            border.color: closeMouse.containsMouse ? "#2effffff" : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "󰅖"
                color: closeMouse.pressed ? StyleTokens.textOnError : (closeMouse.containsMouse ? StyleTokens.danger : StyleTokens.textSecondary)
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
