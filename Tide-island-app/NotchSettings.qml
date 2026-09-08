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
            height: calendarPanel.y + calendarPanel.height + 60

            Text {
                id: title
                font.family: Theme.titleFontFamily
                text: "Boring Notch"
                color: Theme.textColor
                font.pixelSize: 30
                x: 60
                y: 50
            }

            Text {
                id: sizingTitle
                text: "Notch Sizing & Geometry"
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
                id: sizingPanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: sizingTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: sizingColumn.implicitHeight + 36

                Column {
                    id: sizingColumn
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

                    ToggleRow {
                        title: "Notch Border"
                        description: "Display an outline border around the notch contour"
                        keyName: "notchBorderEnabled"
                        fallbackState: false
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Notch Border Width"
                        description: "Thickness in pixels of the notch outline border (1-10, default 1)"
                        keyName: "notchBorderWidth"
                        fallbackText: "1"
                        numeric: true
                        minimumValue: 1
                        maximumValue: 10
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Closed Notch Width"
                        description: "Width of notch when resting in Notch/Pill mode (default 185)"
                        keyName: "notchClosedWidth"
                        fallbackText: "185"
                        numeric: true
                        minimumValue: 80
                        maximumValue: 1000
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Closed Notch Height"
                        description: "Height of notch when resting (default 32)"
                        keyName: "notchClosedHeight"
                        fallbackText: "32"
                        numeric: true
                        minimumValue: 16
                        maximumValue: 200
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Circle Closed Size"
                        description: "Diameter of circle when resting in Circle mode (default 44)"
                        keyName: "notchCircleClosedSize"
                        fallbackText: "44"
                        numeric: true
                        minimumValue: 24
                        maximumValue: 160
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Open Notch Width"
                        description: "Width of notch when expanded (default 640)"
                        keyName: "notchOpenWidth"
                        fallbackText: "640"
                        numeric: true
                        minimumValue: 240
                        maximumValue: 1600
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Open Notch Height"
                        description: "Height of notch when expanded (default 190)"
                        keyName: "notchOpenHeight"
                        fallbackText: "190"
                        numeric: true
                        minimumValue: 100
                        maximumValue: 900
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Circle Mode Expanded Roundness"
                        description: "Corner radius when expanded in Circle mode (default 48)"
                        keyName: "notchCircleExpandedRadius"
                        fallbackText: "48"
                        numeric: true
                        minimumValue: 14
                        maximumValue: 95
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Top Flared Wing Radius"
                        description: "Curvature of top wings flaring into screen bezel (default 6, 0 = flat)"
                        keyName: "notchTopCornerRadius"
                        fallbackText: "6"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 100
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Bottom Corner Radius"
                        description: "Curvature of bottom notch corners (default 14)"
                        keyName: "notchBottomCornerRadius"
                        fallbackText: "14"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 100
                        width: parent.width
                    }
                }
            }

            Text {
                id: behaviorTitle
                text: "Behavior & Gestures"
                anchors.top: sizingPanel.bottom
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
                id: behaviorPanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: behaviorTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: behaviorColumn.implicitHeight + 36

                Column {
                    id: behaviorColumn
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    ToggleRow {
                        title: "Hide in Fullscreen"
                        description: "Automatically retract notch when an active app enters fullscreen"
                        keyName: "hideNotchInFullscreen"
                        fallbackState: true
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    LayerSelectionRow {
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ToggleRow {
                        title: "Boring Face Animation"
                        description: "Show playful animated blinking eyes in closed notch when idle"
                        keyName: "showBoringFace"
                        fallbackState: false
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Hover Open Delay (ms)"
                        description: "Delay before notch opens on hover (default 300)"
                        keyName: "notchHoverOpenDelayMs"
                        fallbackText: "300"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 3000
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ConfigRow {
                        title: "Hover Close Delay (ms)"
                        description: "Delay before notch closes after pointer leaves (default 100)"
                        keyName: "notchHoverCloseDelayMs"
                        fallbackText: "100"
                        numeric: true
                        minimumValue: 0
                        maximumValue: 3000
                        width: parent.width
                    }
                }
            }

            Text {
                id: mediaTitle
                text: "Media & Player Monitoring"
                anchors.top: behaviorPanel.bottom
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
                id: mediaPanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: mediaTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: mediaColumn.implicitHeight + 36

                Column {
                    id: mediaColumn
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    ToggleRow {
                        title: "Auto-Expand on Track Change"
                        description: "Expand island into full player when media changes (disabled by default)"
                        keyName: "disableAutoExpandOnTrackChange"
                        fallbackState: true
                        invert: true
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ToggleRow {
                        title: "Album Art Glow Effect"
                        description: "Show blurred ambient lighting glow behind album art during playback"
                        keyName: "mediaLightingEffectEnabled"
                        fallbackState: true
                        width: parent.width
                    }

                    SplitLine { width: parent.width }

                    ExcludedPlayersRow {
                        width: parent.width
                    }
                }
            }

            Text {
                id: calendarTitle
                text: "Calendar & Google Calendar"
                anchors.top: mediaPanel.bottom
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
                id: calendarPanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: calendarTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: calendarColumn.implicitHeight + 36

                Column {
                    id: calendarColumn
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    CalendarSourcesRow {
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

    component ExcludedPlayersRow: Item {
        id: row
        height: rowColumn.implicitHeight + 10

        property var playerList: {
            const raw = ConfigStore.value("excludedPlayers", [])
            return Array.isArray(raw) ? raw : []
        }

        function addPlayer(name) {
            const trimmed = String(name || "").trim().toLowerCase()
            if (trimmed === "") return
            const current = playerList.slice()
            if (current.indexOf(trimmed) === -1) {
                current.push(trimmed)
                ConfigStore.setValue("excludedPlayers", current)
                ConfigStore.save()
                row.playerList = current
            }
        }

        function removePlayer(index) {
            const current = playerList.slice()
            if (index >= 0 && index < current.length) {
                current.splice(index, 1)
                ConfigStore.setValue("excludedPlayers", current)
                ConfigStore.save()
                row.playerList = current
            }
        }

        Column {
            id: rowColumn
            width: parent.width
            spacing: 12

            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: "Excluded Media Players"
                    font.family: Theme.textFontFamily
                    font.pixelSize: 18
                    color: Theme.textColor
                }

                Text {
                    text: "Ignore background audio players or browser tabs matching these names"
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                    color: Theme.subtleTextColor
                }
            }

            // Input field + Add button + quick suggestion chips
            Row {
                width: parent.width
                spacing: 8

                ConfigTextField {
                    id: playerInput
                    width: 200
                    height: 36
                    placeholderText: "e.g. firefox, brave, discord"
                    onAccepted: {
                        row.addPlayer(playerInput.text)
                        playerInput.text = ""
                    }
                }

                Rectangle {
                    width: 64
                    height: 36
                    radius: 7
                    color: addMouse.pressed ? Theme.controlPressedColor : Theme.componentBgColor
                    border.width: 1
                    border.color: Theme.inputBorderColor

                    Text {
                        anchors.centerIn: parent
                        text: "Add"
                        color: Theme.textColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: addMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            row.addPlayer(playerInput.text)
                            playerInput.text = ""
                        }
                    }
                }

                // Quick add suggestion chips
                Repeater {
                    model: ["firefox", "chromium", "discord"]

                    delegate: Rectangle {
                        width: chipText.implicitWidth + 14
                        height: 36
                        radius: 7
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.inputBorderColor
                        visible: row.playerList.indexOf(modelData) === -1

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: "+ " + modelData
                            color: Theme.subtleTextColor
                            font.family: Theme.textFontFamily
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: row.addPlayer(modelData)
                        }
                    }
                }
            }

            // Active excluded chips list
            Flow {
                width: parent.width
                spacing: 6
                visible: row.playerList.length > 0

                Repeater {
                    model: row.playerList

                    delegate: Rectangle {
                        width: tagRow.implicitWidth + 16
                        height: 28
                        radius: 6
                        color: Theme.componentBgColor
                        border.width: 1
                        border.color: Theme.inputBorderColor

                        Row {
                            id: tagRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: modelData
                                color: Theme.textColor
                                font.family: Theme.textFontFamily
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "×"
                                color: "#ff453a"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: row.removePlayer(index)
                        }
                    }
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
            text: "Render on 'top' (standard) or 'overlay' (above all windows and lock screens)"
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

    component CalendarSourcesRow: Item {
        id: calRow
        height: calColumn.implicitHeight + 10

        property var calendarList: {
            const raw = ConfigStore.value("calendars", [])
            return Array.isArray(raw) ? raw : []
        }

        property string selectedColor: "#007aff"
        property bool showHelp: false

        function addCalendar(name, url) {
            const trimmedUrl = String(url || "").trim()
            if (trimmedUrl === "") return
            const trimmedName = String(name || "").trim() || "Google Calendar"

            let normalizedUrl = trimmedUrl
            if (normalizedUrl.toLowerCase().startsWith("webcal://")) {
                normalizedUrl = "https://" + normalizedUrl.substring(9)
            }

            const current = calendarList.slice()
            const id = "cal-" + Date.now() + "-" + Math.floor(Math.random() * 1000)
            current.push({
                "id": id,
                "name": trimmedName,
                "url": normalizedUrl,
                "color": calRow.selectedColor,
                "enabled": true
            })
            ConfigStore.setValue("calendars", current)
            ConfigStore.save()
            calRow.calendarList = current
        }

        function removeCalendar(index) {
            const current = calendarList.slice()
            if (index >= 0 && index < current.length) {
                current.splice(index, 1)
                ConfigStore.setValue("calendars", current)
                ConfigStore.save()
                calRow.calendarList = current
            }
        }

        function toggleCalendar(index) {
            const current = calendarList.slice()
            if (index >= 0 && index < current.length) {
                const item = Object.assign({}, current[index])
                item.enabled = !item.enabled
                current[index] = item
                ConfigStore.setValue("calendars", current)
                ConfigStore.save()
                calRow.calendarList = current
            }
        }

        Column {
            id: calColumn
            width: parent.width
            spacing: 14

            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: "Google Calendar & Event Feeds"
                    font.family: Theme.textFontFamily
                    font.pixelSize: 18
                    color: Theme.textColor
                }

                Text {
                    text: "Connect Google Calendar private feeds (or any iCal/ICS link) and toggle which calendars to display in the notch."
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                    color: Theme.subtleTextColor
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
            }

            // Quick instruction guide toggle
            Row {
                spacing: 6

                Text {
                    text: calRow.showHelp ? "󰅃 Hide Google Calendar setup guide" : "󰅀 How to get your Google Calendar secret iCal link"
                    color: Theme.accentColor
                    font.family: Theme.textFontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: calRow.showHelp = !calRow.showHelp
                }
            }

            // Help instructions box
            Rectangle {
                width: parent.width
                height: helpCol.implicitHeight + 24
                radius: 8
                color: Theme.componentBgColor
                border.width: 1
                border.color: Theme.inputBorderColor
                visible: calRow.showHelp

                Column {
                    id: helpCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Text {
                        text: "1. Open Google Calendar in your web browser (calendar.google.com)"
                        color: Theme.textColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 13
                    }
                    Text {
                        text: "2. Under 'My calendars' on the left, click the 3 dots (⋮) next to your calendar -> 'Settings and sharing'"
                        color: Theme.textColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 13
                    }
                    Text {
                        text: "3. Scroll down to 'Integrate calendar' and copy the 'Secret address in iCal format'"
                        color: Theme.textColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 13
                    }
                    Text {
                        text: "4. Paste the URL below and click Add. You can repeat this for each calendar you want to sync!"
                        color: Theme.textColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 13
                    }
                }
            }

            // Input form: Name + URL + Color + Add
            Column {
                width: parent.width
                spacing: 8

                Row {
                    width: parent.width
                    spacing: 8

                    ConfigTextField {
                        id: calNameInput
                        width: 160
                        height: 36
                        placeholderText: "Calendar Name"
                    }

                    ConfigTextField {
                        id: calUrlInput
                        width: Math.max(200, parent.width - calNameInput.width - addBtn.width - 24)
                        height: 36
                        placeholderText: "https://calendar.google.com/calendar/ical/.../basic.ics"
                        onAccepted: {
                            calRow.addCalendar(calNameInput.text, calUrlInput.text)
                            calNameInput.text = ""
                            calUrlInput.text = ""
                        }
                    }

                    Rectangle {
                        id: addBtn
                        width: 72
                        height: 36
                        radius: 7
                        color: addCalMouse.pressed ? Theme.controlPressedColor : Theme.componentBgColor
                        border.width: 1
                        border.color: Theme.inputBorderColor

                        Text {
                            anchors.centerIn: parent
                            text: "+ Add"
                            color: Theme.textColor
                            font.family: Theme.textFontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: addCalMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                calRow.addCalendar(calNameInput.text, calUrlInput.text)
                                calNameInput.text = ""
                                calUrlInput.text = ""
                            }
                        }
                    }
                }

                // Color picker row
                Row {
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Color:"
                        color: Theme.subtleTextColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 13
                    }

                    Repeater {
                        model: [
                            { color: "#007aff", label: "Blue" },
                            { color: "#af52de", label: "Purple" },
                            { color: "#30d158", label: "Green" },
                            { color: "#ff9500", label: "Orange" },
                            { color: "#ff2d55", label: "Red" }
                        ]

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            color: modelData.color
                            border.width: calRow.selectedColor === modelData.color ? 2 : 0
                            border.color: "white"

                            Rectangle {
                                anchors.centerIn: parent
                                width: 8
                                height: 8
                                radius: 4
                                color: "white"
                                visible: calRow.selectedColor === modelData.color
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calRow.selectedColor = modelData.color
                            }
                        }
                    }
                }
            }

            // Configured calendars list
            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: calRow.calendarList.length > 0 ? "Configured Calendars (" + calRow.calendarList.length + "):" : "No calendars added yet."
                    color: Theme.subtleTextColor
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }

                Repeater {
                    model: calRow.calendarList

                    Rectangle {
                        width: calColumn.width
                        height: 44
                        radius: 8
                        color: Theme.componentBgColor
                        border.width: 1
                        border.color: Theme.inputBorderColor

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            // Checkbox toggle
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 5
                                color: modelData.enabled ? Theme.accentColor : "transparent"
                                border.width: 1
                                border.color: modelData.enabled ? Theme.accentColor : Theme.inputBorderColor
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "white"
                                    font.pixelSize: 13
                                    font.bold: true
                                    visible: modelData.enabled
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calRow.toggleCalendar(index)
                                }
                            }

                            // Color dot
                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: modelData.color || "#007aff"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Calendar info
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: modelData.name || "Calendar"
                                    color: modelData.enabled ? Theme.textColor : Theme.subtleTextColor
                                    font.family: Theme.textFontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        // Remove button
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            radius: 14
                            color: delCalMouse.containsMouse ? Theme.controlPressedColor : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                font.pixelSize: 18
                                color: delCalMouse.containsMouse ? "#ff453a" : Theme.subtleTextColor
                            }

                            MouseArea {
                                id: delCalMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calRow.removeCalendar(index)
                            }
                        }
                    }
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
            text: "Notch Style"
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            color: Theme.textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: "Choose between top-anchored Notch, detached floating Pill, or circular Notch"
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

        property string selectedPosition: {
            const raw = String(ConfigStore.value("notchPosition", "top-center")).toLowerCase()
            if (raw === "top-center" || raw === "bottom-center" ||
                raw === "top-left" || raw === "top-right" ||
                raw === "bottom-left" || raw === "bottom-right")
                return raw
            return "top-center"
        }

        height: Math.max(76, buttonCol.implicitHeight)

        Column {
            id: textCol
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(80, parent.width - buttonCol.width - 24)
            spacing: 4

            Text {
                text: "Notch Placement"
                font.family: Theme.textFontFamily
                font.pixelSize: 18
                color: Theme.textColor
            }

            Text {
                text: "Screen position and directional expansion behavior"
                font.family: Theme.textFontFamily
                font.pixelSize: 14
                width: parent.width
                elide: Text.ElideRight
                color: Theme.subtleTextColor
            }
        }

        Column {
            id: buttonCol
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
