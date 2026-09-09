import QtQuick
import QtQuick.Controls
import TideIsland 1.0

PagePanel {
    id: root

    function boolValue(key, fallback) {
        const val = ConfigStore.value(key, fallback)
        return val === true || val === "true"
    }

    function intValue(key, fallback) {
        return String(ConfigStore.value(key, fallback))
    }

    function saveInt(key, value, fallback, minimumValue, maximumValue) {
        if (String(value).trim().length === 0)
            return fallback

        const parsedValue = Number(value)
        if (isNaN(parsedValue))
            return fallback

        const roundedValue = Math.min(maximumValue, Math.max(minimumValue, Math.round(parsedValue)))
        ConfigStore.setValue(key, roundedValue)
        ConfigStore.save()
        return roundedValue
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
            height: dynamicResizePanel.y + dynamicResizePanel.height + 40

            Text {
                id: title
                font.family: Theme.titleFontFamily
                text: "Island & Notch"
                color: Theme.textColor
                font.pixelSize: 30
                x: 60
                y: 50
            }

            // 1. Layout & Placement
            Text {
                id: layoutTitle
                text: "Layout & Placement"
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
                id: layoutPanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: layoutTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: layoutColumn.implicitHeight + 36

                Column {
                    id: layoutColumn
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    NotchModeSelectionRow {
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    NotchPositionSelectionRow {
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Screen Edge Offset"
                        description: "Distance in pixels between the island and screen edge (default 4)"
                        keyName: "islandTopMargin"
                        fallbackText: "4"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 200
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Horizontal Alignment (%)"
                        description: "Horizontal position percentage along screen edge (50% = center)"
                        keyName: "islandPositionX"
                        fallbackText: "50"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 100
                        width: parent.width
                    }
                }
            }

            // 2. Appearance & Styling
            Text {
                id: appearanceTitle
                text: "Appearance & Styling"
                anchors.top: layoutPanel.bottom
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
                id: appearancePanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: appearanceTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: appearanceColumn.implicitHeight + 36

                Column {
                    id: appearanceColumn
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    ConfigRow {
                        title: "Background Opacity (%)"
                        description: "Opacity of the island background (0% = transparent, 100% = solid)"
                        keyName: "islandBackgroundOpacity"
                        fallbackText: "60"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 100
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ToggleRow {
                        title: "Contour Outline Border"
                        description: "Display an outline border around the notch contour"
                        keyName: "notchBorderEnabled"
                        fallbackState: false
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Border Thickness"
                        description: "Thickness in pixels of the outline border (1-10, default 1)"
                        keyName: "notchBorderWidth"
                        fallbackText: "1"
                        numeric: true
                        minimumValue: 1
                        maximumValue: 10
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ToggleRow {
                        title: "Boring Face Idle Animation"
                        description: "Show playful animated blinking eyes when closed and idle"
                        keyName: "showBoringFace"
                        fallbackState: false
                        width: parent.width
                    }
                }
            }

            // 3. Resting Dimensions
            Text {
                id: restingTitle
                text: "Resting Dimensions"
                anchors.top: appearancePanel.bottom
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
                id: restingPanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: restingTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: restingColumn.implicitHeight + 36

                Column {
                    id: restingColumn
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    ConfigRow {
                        title: "Closed Width (Pill / Notch)"
                        description: "Width in pixels of notch when resting (default 185)"
                        keyName: "notchClosedWidth"
                        fallbackText: "185"
                        numeric: true
                        minimumValue: 80
                        maximumValue: 1000
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Closed Height (Pill / Notch)"
                        description: "Height in pixels of notch when resting (default 32)"
                        keyName: "notchClosedHeight"
                        fallbackText: "32"
                        numeric: true
                        minimumValue: 16
                        maximumValue: 200
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Circle Diameter"
                        description: "Diameter in pixels when resting in Circle mode (default 44)"
                        keyName: "notchCircleClosedSize"
                        fallbackText: "44"
                        numeric: true
                        minimumValue: 24
                        maximumValue: 160
                        width: parent.width
                    }
                }
            }

            // 4. Expanded Dimensions
            Text {
                id: expandedTitle
                text: "Expanded Dimensions"
                anchors.top: restingPanel.bottom
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
                id: expandedPanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: expandedTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: expandedColumn.implicitHeight + 36

                Column {
                    id: expandedColumn
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    ConfigRow {
                        title: "Expanded Width"
                        description: "Width in pixels of island when open (default 640)"
                        keyName: "notchOpenWidth"
                        fallbackText: "640"
                        numeric: true
                        minimumValue: 240
                        maximumValue: 1600
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Expanded Height"
                        description: "Height in pixels of island when open (default 190)"
                        keyName: "notchOpenHeight"
                        fallbackText: "190"
                        numeric: true
                        minimumValue: 100
                        maximumValue: 900
                        width: parent.width
                    }
                }
            }

            // 5. Corner Curvature
            Text {
                id: curvatureTitle
                text: "Corner Curvature"
                anchors.top: expandedPanel.bottom
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
                id: curvaturePanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: curvatureTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: curvatureColumn.implicitHeight + 36

                Column {
                    id: curvatureColumn
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    ConfigRow {
                        title: "Bottom & Expanded Corner Radius"
                        description: "Curvature radius of bottom corners and expanded notch (default 14)"
                        keyName: "notchBottomCornerRadius"
                        fallbackText: "14"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 100
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Top Bezel Flare Radius"
                        description: "Curvature of top wings flaring into screen bezel in Notch mode (default 6, 0 = flat)"
                        keyName: "notchTopCornerRadius"
                        fallbackText: "6"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 100
                        width: parent.width
                    }
                }
            }

            // 6. Dynamic Resizing Limits
            Text {
                id: dynamicResizeTitle
                text: "Dynamic Resizing Limits"
                anchors.top: curvaturePanel.bottom
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
                id: dynamicResizePanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: dynamicResizeTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: dynamicResizeColumn.implicitHeight + 36

                Column {
                    id: dynamicResizeColumn
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    ConfigRow {
                        title: "Expanded View Max Growth (%)"
                        description: "Maximum percentage expanded notch can grow for long content (default 40%)"
                        keyName: "dynamicResizeMaxPctFull"
                        fallbackText: "40"
                        numeric: true
                        minimumValue: 10
                        maximumValue: 200
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Minimum Pill Max Growth (%)"
                        description: "Maximum percentage closed pill can expand horizontally and vertically (default 50%)"
                        keyName: "dynamicResizeMaxPctMinimum"
                        fallbackText: "50"
                        numeric: true
                        minimumValue: 10
                        maximumValue: 200
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Circle View Max Growth (%)"
                        description: "Maximum percentage circle mode can morph horizontally into a pill (default 60%)"
                        keyName: "dynamicResizeMaxPctCircle"
                        fallbackText: "60"
                        numeric: true
                        minimumValue: 10
                        maximumValue: 200
                        width: parent.width
                    }
                }
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

    component NotchModeSelectionRow: Item {
        id: modeRow

        property string selectedMode: {
            const raw = String(ConfigStore.value("notchMode", "")).toLowerCase()
            if (raw === "notch" || raw === "pill" || raw === "circle")
                return raw
            const legacy = ConfigStore.value("boringNotchEnabled", true)
            return (legacy === true || legacy === "true") ? "notch" : "pill"
        }

        height: 49

        Text {
            id: modeTitle
            text: "Island Style"
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            color: Theme.textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: "Choose between top-anchored Notch, detached floating Pill, or compact Circle"
            font.family: Theme.textFontFamily
            font.pixelSize: 14
            anchors.top: modeTitle.bottom
            anchors.topMargin: 5
            anchors.left: modeTitle.left
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
                    { label: "Notch", value: "notch" },
                    { label: "Pill", value: "pill" },
                    { label: "Circle", value: "circle" }
                ]

                Rectangle {
                    id: btn
                    readonly property bool selected: modeRow.selectedMode === modelData.value

                    width: Math.max(68, btnText.implicitWidth + 20)
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
                            modeRow.selectedMode = modelData.value
                            ConfigStore.setValue("notchMode", modelData.value)
                            ConfigStore.setValue("boringNotchEnabled", modelData.value === "notch")
                            ConfigStore.save()
                        }
                    }
                }
            }
        }
    }

    component NotchPositionSelectionRow: Item {
        id: posRow

        property string selectedPosition: String(ConfigStore.value("notchPosition", "top-center")).toLowerCase()

        height: 80

        Text {
            id: posTitle
            text: "Screen Edge Placement"
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            color: Theme.textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: "Screen edge anchoring location"
            font.family: Theme.textFontFamily
            font.pixelSize: 14
            anchors.top: posTitle.bottom
            anchors.topMargin: 5
            anchors.left: posTitle.left
            width: Math.max(80, parent.width - posButtonGroup.width - 28)
            elide: Text.ElideRight
            color: Theme.subtleTextColor
        }

        Column {
            id: posButtonGroup
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Row {
                spacing: 6
                Repeater {
                    model: [
                        { label: "Top Left", value: "top-left" },
                        { label: "Top Center", value: "top-center" },
                        { label: "Top Right", value: "top-right" }
                    ]
                    delegate: positionButtonComponent
                }
            }

            Row {
                spacing: 6
                Repeater {
                    model: [
                        { label: "Bottom Left", value: "bottom-left" },
                        { label: "Bottom Center", value: "bottom-center" },
                        { label: "Bottom Right", value: "bottom-right" }
                    ]
                    delegate: positionButtonComponent
                }
            }
        }

        Component {
            id: positionButtonComponent
            Rectangle {
                id: posBtn
                readonly property bool selected: posRow.selectedPosition === modelData.value

                width: Math.max(92, posBtnText.implicitWidth + 18)
                height: 32
                radius: 6
                color: selected ? Theme.cardBgColor
                                : posBtnMouse.pressed ? Theme.controlPressedColor
                                                      : Theme.componentBgColor
                border.width: 1
                border.color: Theme.inputBorderColor

                Behavior on color { ColorAnimation { duration: Theme.animationDuration } }
                Behavior on border.color { ColorAnimation { duration: Theme.animationDuration } }

                Text {
                    id: posBtnText
                    anchors.centerIn: parent
                    text: modelData.label
                    color: posBtn.selected ? Theme.textColor : Theme.secondaryTextColor
                    font.family: Theme.textFontFamily
                    font.pixelSize: 13
                    font.weight: posBtn.selected ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    id: posBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        posRow.selectedPosition = modelData.value
                        ConfigStore.setValue("notchPosition", modelData.value)
                        ConfigStore.save()
                    }
                }
            }
        }
    }
}
