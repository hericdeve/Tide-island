import TideIsland 1.0
import QtQuick.Controls
import QtQuick

PagePanel {
    id: root

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
            height: claudePanel.y + claudePanel.height + 40

            Text {
                id: title
                font.family: Theme.titleFontFamily
                text: "Widgets"
                color: Theme.textColor
                font.pixelSize: 30
                x: 60
                y: 50
            }

            // 1. Clock Widget
            Text {
                id: clockTitle
                text: "Clock"
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
                id: clockPanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: clockTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: clockColumn.implicitHeight + 36

                Column {
                    id: clockColumn
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    ClockFormatRow {
                        width: parent.width
                    }
                }
            }

            // 2. Media Player Widget
            Text {
                id: mediaTitle
                text: "Media Player"
                anchors.top: clockPanel.bottom
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
                        description: "Expand island into full media player when media track changes"
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

            // 3. Calendar Widget
            Text {
                id: calendarTitle
                text: "Calendar"
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

            // 4. Claude Code Widget
            Text {
                id: claudeTitle
                text: "Claude Code"
                anchors.top: calendarPanel.bottom
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
                id: claudePanel
                color: Theme.cardBgColor
                radius: 16
                border.width: 1
                border.color: Theme.splitLineColor
                anchors.top: claudeTitle.bottom
                anchors.topMargin: 15
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 40
                height: claudeColumn.implicitHeight + 36

                Column {
                    id: claudeColumn
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    spacing: 16

                    ToggleRow {
                        title: "Minimum View Shows Last Message"
                        description: "Display the latest assistant message or command output in the compact minimum view instead of session status"
                        keyName: "claudeMinimumShowsLastMessage"
                        fallbackState: false
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

    component ClockFormatRow: Item {
        id: clockRow

        property string selectedFormat: String(ConfigStore.value("clockFormat", "12")) === "24" ? "24" : "12"

        height: 49

        Text {
            id: clockTitleText
            text: "Clock Format"
            font.family: Theme.textFontFamily
            font.pixelSize: 18
            color: Theme.textColor
            anchors.top: parent.top
            anchors.left: parent.left
        }

        Text {
            text: "Choose 12-hour or 24-hour time format"
            font.family: Theme.textFontFamily
            font.pixelSize: 14
            anchors.top: clockTitleText.bottom
            anchors.topMargin: 5
            anchors.left: clockTitleText.left
            color: Theme.subtleTextColor
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Rectangle {
                width: 58
                height: 32
                radius: 8
                color: clockRow.selectedFormat === "12" ? Theme.selectedColor : Theme.componentBgColor
                border.width: 1
                border.color: clockRow.selectedFormat === "12" ? Theme.selectedColor : Theme.splitLineColor

                Text {
                    anchors.centerIn: parent
                    text: "12h"
                    font.family: Theme.textFontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: clockRow.selectedFormat === "12" ? Theme.buttonTextColor : Theme.textColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ConfigStore.setValue("clockFormat", "12")
                        ConfigStore.save()
                    }
                }
            }

            Rectangle {
                width: 58
                height: 32
                radius: 8
                color: clockRow.selectedFormat === "24" ? Theme.selectedColor : Theme.componentBgColor
                border.width: 1
                border.color: clockRow.selectedFormat === "24" ? Theme.selectedColor : Theme.splitLineColor

                Text {
                    anchors.centerIn: parent
                    text: "24h"
                    font.family: Theme.textFontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: clockRow.selectedFormat === "24" ? Theme.buttonTextColor : Theme.textColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ConfigStore.setValue("clockFormat", "24")
                        ConfigStore.save()
                    }
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
                                border.width: 1.5
                                border.color: modelData.enabled ? Theme.accentColor : Theme.inputBorderColor
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "white"
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
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
                                width: 10
                                height: 10
                                radius: 5
                                color: modelData.color || "#007aff"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Name & URL preview
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    text: modelData.name || "Calendar"
                                    color: modelData.enabled ? Theme.textColor : Theme.subtleTextColor
                                    font.family: Theme.textFontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                Text {
                                    text: modelData.url ? (modelData.url.length > 45 ? modelData.url.substring(0, 45) + "..." : modelData.url) : ""
                                    color: Theme.subtleTextColor
                                    font.family: Theme.textFontFamily
                                    font.pixelSize: 10
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
                            color: "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "🗑"
                                font.pixelSize: 13
                                opacity: 0.6
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onEntered: parent.opacity = 1.0
                                onExited: parent.opacity = 0.6
                                onClicked: calRow.removeCalendar(index)
                            }
                        }
                    }
                }
            }
        }
    }
}
