import TideIsland 1.0
import QtQuick.Controls
import QtQuick
import QtQuick.Layouts

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
        width: parent.width
        implicitHeight: calColumn.implicitHeight + 10
        height: implicitHeight

        readonly property var calendarList: {
            const map = ConfigStore.map
            const raw = (map && map.calendars) ? map.calendars : []
            return Array.isArray(raw) ? raw : []
        }

        readonly property var googleAuthData: {
            const map = ConfigStore.map
            const raw = (map && map.googleAuth) ? map.googleAuth : {}
            return (raw && typeof raw === "object") ? raw : {}
        }

        readonly property var googleCalendarsList: {
            const map = ConfigStore.map
            const raw = (map && map.googleCalendars) ? map.googleCalendars : []
            if (Array.isArray(raw)) return raw
            if (raw && raw.length !== undefined) {
                const list = []
                for (let i = 0; i < raw.length; ++i) list.push(raw[i])
                return list
            }
            return []
        }

        readonly property bool isGoogleSignedIn: {
            if (backend.isGoogleSignedIn()) return true
            return !!(googleAuthData && (googleAuthData.signedIn === true || googleAuthData.isSignedIn === true || (googleAuthData.refreshToken && googleAuthData.refreshToken !== "")))
        }

        readonly property string googleEmail: {
            const bEmail = backend.googleAccountEmail()
            if (bEmail && bEmail !== "") return bEmail
            return (googleAuthData && googleAuthData.email) ? googleAuthData.email : ""
        }

        readonly property string googleError: {
            const bErr = backend.googleAuthError()
            if (bErr && bErr !== "") return bErr
            return (googleAuthData && googleAuthData.lastError) ? googleAuthData.lastError : ""
        }

        property string selectedColor: "#007aff"
        property bool showCustomFeedForm: false
        property bool showCustomCredentials: false
        property bool showSecret: false
        property string credentialsFeedback: ""
        property bool authWaitingNotice: false

        Timer {
            id: feedbackTimer
            interval: 3500
            onTriggered: calRow.credentialsFeedback = ""
        }

        Timer {
            id: pollConfigTimer
            interval: 1500
            repeat: true
            running: calRow.authWaitingNotice
            onTriggered: {
                backend.reloadUserConfig()
                if (calRow.isGoogleSignedIn || calRow.googleError !== "") {
                    calRow.authWaitingNotice = false
                }
            }
        }

        function triggerGoogleSignIn() {
            calRow.authWaitingNotice = true
            backend.startGoogleCalendarAuth()
        }

        function triggerGoogleSignOut() {
            backend.signOutGoogle()
        }

        function toggleGoogleCalendar(index) {
            const current = googleCalendarsList.map(item => Object.assign({}, item))
            if (index >= 0 && index < current.length) {
                current[index].enabled = !current[index].enabled
                ConfigStore.setValue("googleCalendars", current)
                ConfigStore.save()
            }
        }

        function addCalendar(name, url) {
            const trimmedUrl = String(url || "").trim()
            if (trimmedUrl === "") return
            const trimmedName = String(name || "").trim() || "Calendar Feed"

            let normalizedUrl = trimmedUrl
            if (normalizedUrl.toLowerCase().startsWith("webcal://")) {
                normalizedUrl = "https://" + normalizedUrl.substring(9)
            }

            const current = calendarList.map(item => Object.assign({}, item))
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
        }

        function removeCalendar(index) {
            const current = calendarList.map(item => Object.assign({}, item))
            if (index >= 0 && index < current.length) {
                current.splice(index, 1)
                ConfigStore.setValue("calendars", current)
                ConfigStore.save()
            }
        }

        function toggleCalendar(index) {
            const current = calendarList.map(item => Object.assign({}, item))
            if (index >= 0 && index < current.length) {
                current[index].enabled = !current[index].enabled
                ConfigStore.setValue("calendars", current)
                ConfigStore.save()
            }
        }

        Column {
            id: calColumn
            width: parent.width
            spacing: 16

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
                    text: "Sign in with Google to choose which calendars to display in your notch schedule, or connect custom iCal feeds."
                    font.family: Theme.textFontFamily
                    font.pixelSize: 14
                    color: Theme.subtleTextColor
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
            }

            // Google Account Connection Card
            Rectangle {
                width: parent.width
                implicitHeight: googleCardCol.implicitHeight + 28
                height: implicitHeight
                radius: 10
                color: Theme.componentBgColor
                border.width: 1
                border.color: Theme.inputBorderColor

                Column {
                    id: googleCardCol
                    width: parent.width - 28
                    x: 14
                    y: 14
                    spacing: 12

                    // Top row: Google branding & Sign In / Account status
                    Item {
                        width: parent.width
                        implicitHeight: Math.max(38, googleBrandRow.implicitHeight)
                        height: implicitHeight

                        Row {
                            id: googleBrandRow
                            anchors.left: parent.left
                            anchors.right: actionBtnContainer.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            Rectangle {
                                width: 38
                                height: 38
                                radius: 19
                                color: Theme.totalBgColor
                                border.width: 1
                                border.color: Theme.inputBorderColor
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "G"
                                    color: "#4285f4"
                                    font.family: Theme.textFontFamily
                                    font.pixelSize: 20
                                    font.weight: Font.Bold
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 50
                                spacing: 2

                                Text {
                                    text: calRow.isGoogleSignedIn ? "Google Account Connected" : "Google Calendar"
                                    color: Theme.textColor
                                    font.family: Theme.textFontFamily
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: {
                                        if (calRow.authWaitingNotice) {
                                            return "Waiting for authentication in your browser..."
                                        }
                                        if (calRow.isGoogleSignedIn) {
                                            return calRow.googleEmail !== "" ? calRow.googleEmail : "Signed In"
                                        }
                                        if (calRow.googleError !== "") {
                                            return calRow.googleError
                                        }
                                        return "Click to authenticate in your browser and sync your calendars."
                                    }
                                    color: {
                                        if (calRow.authWaitingNotice) return Theme.accentColor
                                        if (calRow.googleError !== "" && !calRow.isGoogleSignedIn) return "#ff453a"
                                        return Theme.subtleTextColor
                                    }
                                    font.family: Theme.textFontFamily
                                    font.pixelSize: 12
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Item {
                            id: actionBtnContainer
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: calRow.isGoogleSignedIn ? signOutBtn.width : signInBtn.width
                            height: 36

                            // Sign In Button
                            Rectangle {
                                id: signInBtn
                                visible: !calRow.isGoogleSignedIn
                                width: 150
                                height: 36
                                radius: 7
                                color: signInMouse.pressed ? Theme.buttonPressedColor : (signInMouse.containsMouse ? Theme.buttonHoverColor : Theme.buttonColor)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰊫"
                                        color: Theme.buttonTextColor
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: calRow.authWaitingNotice ? "Authenticating..." : "Sign in with Google"
                                        color: Theme.buttonTextColor
                                        font.family: Theme.textFontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: signInMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calRow.triggerGoogleSignIn()
                                }
                            }

                            // Sign Out Button
                            Rectangle {
                                id: signOutBtn
                                visible: calRow.isGoogleSignedIn
                                width: 90
                                height: 36
                                radius: 7
                                color: signOutMouse.pressed ? Theme.controlPressedColor : Theme.totalBgColor
                                border.width: 1
                                border.color: Theme.inputBorderColor

                                Text {
                                    anchors.centerIn: parent
                                    text: "Sign Out"
                                    color: Theme.textColor
                                    font.family: Theme.textFontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: signOutMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calRow.triggerGoogleSignOut()
                                }
                            }
                        }
                    }

                    // Custom Google OAuth Credentials Section
                    Rectangle {
                        width: parent.width
                        implicitHeight: credCol.implicitHeight + (calRow.showCustomCredentials ? 24 : 16)
                        height: implicitHeight
                        radius: 8
                        color: Theme.totalBgColor
                        border.width: 1
                        border.color: calRow.showCustomCredentials ? Theme.focusBorderColor : Theme.inputBorderColor

                        Column {
                            id: credCol
                            width: parent.width - 24
                            x: 12
                            y: calRow.showCustomCredentials ? 12 : 8
                            spacing: 12

                            // Header row with toggle and Keyring status badge
                            Item {
                                width: parent.width
                                height: Math.max(26, headerRow.implicitHeight)

                                Row {
                                    id: headerRow
                                    anchors.left: parent.left
                                    anchors.right: badgeItem.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Text {
                                        text: calRow.showCustomCredentials ? "󰅃" : "󰅀"
                                        color: Theme.textColor
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "Custom Google OAuth Credentials (Optional)"
                                        color: Theme.textColor
                                        font.family: Theme.textFontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Status Badge
                                Rectangle {
                                    id: badgeItem
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: badgeRow.implicitWidth + 14
                                    height: 22
                                    radius: 11
                                    color: backend.hasCustomGoogleCredentials() ? "#193524" : Theme.componentBgColor
                                    border.width: 1
                                    border.color: backend.hasCustomGoogleCredentials() ? "#2e7d32" : Theme.inputBorderColor

                                    Row {
                                        id: badgeRow
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Text {
                                            text: backend.hasCustomGoogleCredentials() ? "󰌾" : "󰌿"
                                            color: backend.hasCustomGoogleCredentials() ? "#81c784" : Theme.subtleTextColor
                                            font.pixelSize: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: backend.hasCustomGoogleCredentials()
                                                ? ("Stored in " + backend.googleCredentialStorageStatus())
                                                : "Default Public ID"
                                            color: backend.hasCustomGoogleCredentials() ? "#81c784" : Theme.subtleTextColor
                                            font.family: Theme.textFontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        calRow.showCustomCredentials = !calRow.showCustomCredentials
                                        if (calRow.showCustomCredentials) {
                                            customClientIdInput.text = backend.googleClientId()
                                            customClientSecretInput.text = backend.googleClientSecret()
                                        }
                                    }
                                }
                            }

                            // Expanded Credentials Form
                            Column {
                                width: parent.width
                                spacing: 10
                                visible: calRow.showCustomCredentials

                                Text {
                                    width: parent.width
                                    text: "Provide your Google Cloud OAuth 2.0 desktop credentials. The client secret is stored securely in " + backend.googleCredentialStorageStatus() + " and is never saved in plaintext."
                                    color: Theme.subtleTextColor
                                    font.family: Theme.textFontFamily
                                    font.pixelSize: 12
                                    wrapMode: Text.WordWrap
                                }

                                // Client ID Field
                                Column {
                                    width: parent.width
                                    spacing: 4

                                    Text {
                                        text: "Client ID"
                                        color: Theme.textColor
                                        font.family: Theme.textFontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }

                                    ConfigTextField {
                                        id: customClientIdInput
                                        width: parent.width
                                        height: 36
                                        placeholderText: "e.g. 889758287515-...apps.googleusercontent.com"
                                        text: backend.googleClientId()
                                    }
                                }

                                // Client Secret Field with Eye Toggle
                                Column {
                                    width: parent.width
                                    spacing: 4

                                    Text {
                                        text: "Client Secret (Key)"
                                        color: Theme.textColor
                                        font.family: Theme.textFontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }

                                    Item {
                                        width: parent.width
                                        height: 36

                                        ConfigTextField {
                                            id: customClientSecretInput
                                            anchors.fill: parent
                                            echoMode: calRow.showSecret ? TextInput.Normal : TextInput.Password
                                            rightPadding: 42
                                            placeholderText: "Enter Google OAuth 2.0 Client Secret (leave blank if none)"
                                            text: backend.googleClientSecret()
                                        }

                                        Rectangle {
                                            id: eyeToggleBtn
                                            anchors.right: parent.right
                                            anchors.rightMargin: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 32
                                            height: 28
                                            radius: 4
                                            color: eyeMouse.containsMouse ? Theme.inputHoverBgColor : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: calRow.showSecret ? "󰈈" : "󰈉"
                                                color: eyeMouse.containsMouse ? Theme.textColor : Theme.subtleTextColor
                                                font.pixelSize: 15
                                            }

                                            MouseArea {
                                                id: eyeMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: calRow.showSecret = !calRow.showSecret
                                            }
                                        }
                                    }
                                }

                                // Actions row: Save, Clear, Status
                                Row {
                                    width: parent.width
                                    spacing: 10

                                    Rectangle {
                                        id: saveCredBtn
                                        width: 135
                                        height: 32
                                        radius: 6
                                        color: saveMouse.pressed ? Theme.buttonPressedColor : (saveMouse.containsMouse ? Theme.buttonHoverColor : Theme.buttonColor)

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: "󰄲"
                                                color: Theme.buttonTextColor
                                                font.pixelSize: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: "Save Credentials"
                                                color: Theme.buttonTextColor
                                                font.family: Theme.textFontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: saveMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const saved = backend.saveGoogleCredentials(customClientIdInput.text, customClientSecretInput.text)
                                                if (saved) {
                                                    calRow.credentialsFeedback = "Saved securely in " + backend.googleCredentialStorageStatus()
                                                } else {
                                                    calRow.credentialsFeedback = "Error saving credentials"
                                                }
                                                feedbackTimer.restart()
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: clearCredBtn
                                        width: 80
                                        height: 32
                                        radius: 6
                                        visible: backend.hasCustomGoogleCredentials() || customClientIdInput.text !== "" || customClientSecretInput.text !== ""
                                        color: clearMouse.pressed ? Theme.controlPressedColor : Theme.componentBgColor
                                        border.width: 1
                                        border.color: Theme.inputBorderColor

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Clear"
                                            color: Theme.textColor
                                            font.family: Theme.textFontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                        }

                                        MouseArea {
                                            id: clearMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                backend.clearGoogleCredentials()
                                                customClientIdInput.text = ""
                                                customClientSecretInput.text = ""
                                                calRow.credentialsFeedback = "Custom credentials cleared"
                                                feedbackTimer.restart()
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: calRow.credentialsFeedback
                                        color: "#81c784"
                                        font.family: Theme.textFontFamily
                                        font.pixelSize: 12
                                        visible: calRow.credentialsFeedback !== ""
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Google Calendars Selection List
            Column {
                width: parent.width
                spacing: 8
                visible: calRow.isGoogleSignedIn

                Item {
                    width: parent.width
                    height: 28

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Choose Calendars to Display (" + calRow.googleCalendarsList.length + "):"
                        color: Theme.textColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 80
                        height: 28
                        radius: 6
                        color: Theme.componentBgColor
                        border.width: 1
                        border.color: Theme.inputBorderColor

                        Text {
                            anchors.centerIn: parent
                            text: "↻ Refresh"
                            color: Theme.subtleTextColor
                            font.family: Theme.textFontFamily
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                backend.refreshGoogleCalendars()
                            }
                        }
                    }
                }

                Text {
                    visible: calRow.isGoogleSignedIn && calRow.googleCalendarsList.length === 0
                    text: calRow.googleError !== ""
                        ? calRow.googleError
                        : "No calendars fetched yet. Click Refresh or check your Google Cloud Console."
                    color: calRow.googleError !== "" ? "#ff453a" : Theme.subtleTextColor
                    font.family: Theme.textFontFamily
                    font.pixelSize: 13
                    width: parent.width
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: calRow.googleCalendarsList

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
                            anchors.right: parent.right
                            anchors.rightMargin: 12
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
                                    onClicked: calRow.toggleGoogleCalendar(index)
                                }
                            }

                            // Color dot
                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: modelData.color || "#4285f4"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Name & Primary badge
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                width: parent.width - 60

                                Row {
                                    spacing: 6

                                    Text {
                                        text: modelData.name || "Calendar"
                                        color: modelData.enabled ? Theme.textColor : Theme.subtleTextColor
                                        font.family: Theme.textFontFamily
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        visible: !!modelData.isPrimary
                                        height: 16
                                        width: primaryLabel.implicitWidth + 8
                                        radius: 4
                                        color: Theme.totalBgColor
                                        border.width: 1
                                        border.color: Theme.inputBorderColor
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            id: primaryLabel
                                            anchors.centerIn: parent
                                            text: "Primary"
                                            color: Theme.subtleTextColor
                                            font.pixelSize: 10
                                        }
                                    }
                                }

                                Text {
                                    visible: !!modelData.description
                                    text: modelData.description || ""
                                    color: Theme.subtleTextColor
                                    font.family: Theme.textFontFamily
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }
                        }
                    }
                }
            }

            // Custom iCal Feeds Section (Collapsible)
            Column {
                width: parent.width
                spacing: 10

                Row {
                    spacing: 6

                    Text {
                        text: calRow.showCustomFeedForm ? "󰅃 Custom iCal / WebCal Feeds" : "󰅀 Custom iCal / WebCal Feeds"
                        color: Theme.accentColor
                        font.family: Theme.textFontFamily
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calRow.showCustomFeedForm = !calRow.showCustomFeedForm
                    }
                }

                // Input form: Name + URL + Color + Add
                Column {
                    width: parent.width
                    spacing: 8
                    visible: calRow.showCustomFeedForm

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
                            placeholderText: "https://.../basic.ics or webcal://..."
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

                    // Configured custom iCal list
                    Column {
                        width: parent.width
                        spacing: 8

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

                                    Rectangle {
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: modelData.color || "#007aff"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

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
    }
}

