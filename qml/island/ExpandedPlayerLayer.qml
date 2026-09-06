import QtQuick
import QtQuick.Effects
import IslandBackend
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../controlcenter"

Item {
    id: root

    signal controlPressed()
    signal backgroundClicked()
    signal closeRequested()
    signal keyboardFocusRequested()
    signal keyboardFocusReleased()
    signal previousRequested()
    signal pageChanged(int page)
    signal shelfRequested()
    signal timerToggleRequested(int hours, int minutes)
    signal timerResetRequested()
    signal timerDurationRequested(int hours, int minutes)

    readonly property var userConfig: UserConfig

    property int batteryCapacity: -1
    property bool isCharging: false
    property bool cameraMirrorActive: false

    property int initialPage: 0
    property bool showCondition: false
    property string currentArtUrl: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property string lyricsText: ""
    property string timePlayed: "0:00"
    property string timeTotal: "0:00"
    property real trackProgress: 0
    property var activePlayer: null
    property string iconFontFamily: userConfig.iconFontFamily
    property string textFontFamily: userConfig.textFontFamily
    property int timerSelectedHours: 0
    property int timerSelectedMinutes: 5
    property int timerTotalSeconds: 300
    property int timerRemainingSeconds: 0
    property bool timerRunning: false
    property bool timerActive: false
    property real visualizerPhase: 0
    property int currentPage: 0
    property int pendingPage: -1
    readonly property int pageCount: 2
    property real pageProgress: 0
    readonly property real clampedPageProgress: Math.max(0, Math.min(1, pageProgress))
    readonly property real pageSlideDistance: Math.max(1, viewport.width + 24)

    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

    function visualizerLevel(index) {
        const phase = visualizerPhase + index * 0.78;
        const primary = (Math.sin(phase) + 1) * 0.5;
        const secondary = (Math.sin(phase * 2 + index * 0.95) + 1) * 0.5;
        return 0.22 + primary * 0.42 + secondary * 0.24;
    }

    function pausedVisualizerLevel(index) {
        const levels = [0.34, 0.58, 0.82, 0.58, 0.34];
        return levels[index] || 0.4;
    }

    function togglePlayback() {
        if (!activePlayer || !activePlayer.canControl) return;

        if (activePlayer.canTogglePlaying) {
            activePlayer.togglePlaying();
            return;
        }

        if (activePlayer.playbackState === MprisPlaybackState.Playing) {
            if (activePlayer.canPause) activePlayer.pause();
            return;
        }

        if (activePlayer.canPlay) activePlayer.play();
    }

    function seekOffset(seconds) {
        if (!activePlayer || !activePlayer.canControl) return;
        if (activePlayer.position !== undefined) {
            const nextPos = Math.max(0, activePlayer.position + seconds);
            if (activePlayer.canSeek && typeof activePlayer.seek === "function") {
                activePlayer.seek(seconds * 1000000);
            } else {
                activePlayer.position = nextPos;
            }
        }
    }

    function showPage(page) {
        settlePage(page);
    }

    function settlePage(page) {
        const targetPage = Math.max(0, Math.min(pageCount - 1, page));
        pendingPage = -1;
        pageSettleAnimation.stop();
        pageStrip.interactive = false;
        pendingPage = targetPage;
        pageSettleAnimation.startProgress = clampedPageProgress;
        pageSettleAnimation.endProgress = targetPage;

        if (Math.abs(clampedPageProgress - targetPage) < 0.001) {
            pageProgress = targetPage;
            finishPageSettle();
            return;
        }

        pageSettleAnimation.restart();
    }

    function finishPageSettle() {
        if (pendingPage < 0)
            return;

        currentPage = pendingPage;
        pendingPage = -1;
        pageProgress = currentPage;
        root.pageChanged(currentPage);
        updateKeyboardFocusForPage();
    }

    function updateKeyboardFocusForPage() {
        if (showCondition)
            keyboardFocusRequested();
        else
            keyboardFocusReleased();
    }

    function grabKeyboardFocus() {
        root.focus = true;
        root.forceActiveFocus();
        if (currentPage === 1 && timerPage.grabKeyboardFocus)
            timerPage.grabKeyboardFocus();
    }

    function openTimerPage() {
        showPage(1);
    }

    Component.onCompleted: {
        if (initialPage > 0) {
            currentPage = initialPage;
            pageProgress = initialPage;
        }
    }

    anchors.fill: parent
    focus: showCondition
    opacity: showCondition ? 1 : 0

    Keys.onEscapePressed: event => {
        root.closeRequested();
        event.accepted = true;
    }

    property bool isWheelSwiping: false
    property real wheelAccumulatedDelta: 0
    property real wheelStartProgress: 0
    property real verticalWheelAccumulatedDelta: 0

    Timer {
        id: verticalWheelTimer
        interval: 200
        repeat: false
        onTriggered: root.verticalWheelAccumulatedDelta = 0
    }

    function handleVerticalWheel(deltaY, wheel) {
        verticalWheelAccumulatedDelta += deltaY;
        verticalWheelTimer.restart();

        // Upward scroll / swipe closes the player (Boring Notch swipe up to close)
        if (verticalWheelAccumulatedDelta > 60) {
            verticalWheelAccumulatedDelta = 0;
            root.closeRequested();
        }
        if (wheel && wheel.accepted !== undefined)
            wheel.accepted = true;
    }

    Timer {
        id: wheelSettleTimer
        interval: 160
        repeat: false
        onTriggered: {
            if (!root.isWheelSwiping || viewport.width <= 0)
                return;

            root.isWheelSwiping = false;
            const progress = root.clampedPageProgress;
            let targetPage = root.currentPage;

            if (root.currentPage === 0) {
                if (progress > 0.22 || root.wheelAccumulatedDelta > 120)
                    targetPage = 1;
            } else {
                if (progress < 0.78 || root.wheelAccumulatedDelta < -120)
                    targetPage = 0;
            }

            root.settlePage(targetPage);
        }
    }

    function handleHorizontalWheel(wheel) {
        if (viewport.width <= 0)
            return;

        const pX = wheel.pixelDelta ? wheel.pixelDelta.x : 0;
        const pY = wheel.pixelDelta ? wheel.pixelDelta.y : 0;
        const aX = wheel.angleDelta ? wheel.angleDelta.x : 0;
        const aY = wheel.angleDelta ? wheel.angleDelta.y : 0;

        let deltaX = 0;
        if (pX !== 0) {
            deltaX = pX;
        } else if (aX !== 0) {
            deltaX = aX * 0.75;
        }

        const rawY = pY !== 0 ? pY : aY;
        const effectiveY = Math.abs(rawY);
        if (Math.abs(deltaX) < 1 && effectiveY > 4) {
            handleVerticalWheel(rawY, wheel);
            return;
        }

        if (Math.abs(deltaX) < 0.5)
            return;

        if (!isWheelSwiping) {
            isWheelSwiping = true;
            pageSettleAnimation.stop();
            pendingPage = -1;
            wheelStartProgress = clampedPageProgress;
            wheelAccumulatedDelta = 0;
            pageStrip.interactive = true;
        }

        wheelAccumulatedDelta += deltaX;
        root.pageProgress = Math.max(0, Math.min(1, wheelStartProgress + wheelAccumulatedDelta / root.pageSlideDistance));

        wheelSettleTimer.restart();
        if (wheel.accepted !== undefined)
            wheel.accepted = true;
    }

    onShowConditionChanged: {
        wheelSettleTimer.stop();
        isWheelSwiping = false;
        if (!showCondition) {
            pendingPage = -1;
            pageSettleAnimation.stop();
            if (!userConfig.playerRememberLastPane) {
                currentPage = 0;
                pageProgress = 0;
            }
        }
        updateKeyboardFocusForPage();
    }

    Behavior on opacity {
        NumberAnimation {
            duration: showCondition ? 300 : 100
            easing.type: Easing.InOutQuad
        }
    }

    SequentialAnimation {
        id: pageSettleAnimation

        property real startProgress: 0
        property real endProgress: 0

        NumberAnimation {
            target: root
            property: "pageProgress"
            from: pageSettleAnimation.startProgress
            to: pageSettleAnimation.endProgress
            duration: 220
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: root.finishPageSettle()
        }
    }

    Timer {
        interval: 64
        repeat: true
        running: showCondition && isPlaying && currentPage === 0
        onTriggered: {
            visualizerPhase += 0.18;
            if (visualizerPhase > Math.PI * 2) visualizerPhase -= Math.PI * 2;
        }
    }

    Item {
        id: viewport

        anchors.fill: parent
        clip: true

        WheelHandler {
            id: horizontalWheelHandler
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                root.handleHorizontalWheel(event);
            }
        }

        MouseArea {
            id: pageSwipeArea

            anchors.fill: parent
            z: 0
            acceptedButtons: Qt.LeftButton
            preventStealing: false

            property real startX: 0
            property int startPage: 0
            property real startProgress: 0
            property bool moved: false

            onPressed: (mouse) => {
                wheelSettleTimer.stop();
                root.isWheelSwiping = false;
                root.pendingPage = -1;
                pageSettleAnimation.stop();
                startX = mouse.x;
                startPage = root.currentPage;
                startProgress = root.clampedPageProgress;
                moved = false;
                pageStrip.interactive = true;
                root.pageProgress = startProgress;
                mouse.accepted = true;
            }

            onPositionChanged: (mouse) => {
                if (!pressed || viewport.width <= 0)
                    return;

                const deltaX = mouse.x - startX;
                root.pageProgress = Math.max(0, Math.min(1, startProgress + deltaX / root.pageSlideDistance));
                moved = moved || Math.abs(deltaX) > 8;
            }

            onReleased: {
                if (!moved || viewport.width <= 0) {
                    root.settlePage(startPage);
                    return;
                }

                const progress = root.clampedPageProgress;
                let targetPage = startPage;

                if (startPage === 0 && progress > 0.22)
                    targetPage = 1;
                else if (startPage === 1 && progress < 0.78)
                    targetPage = 0;

                root.settlePage(targetPage);
            }

            onCanceled: root.settlePage(startPage)
            onClicked: if (!moved) root.backgroundClicked()
            onWheel: (wheel) => {
                root.handleHorizontalWheel(wheel);
            }
        }

        Item {
            id: pageStrip

            z: 1
            property bool interactive: false

            width: viewport.width
            height: viewport.height
            x: 0

            onWidthChanged: {
                if (!interactive && !pageSettleAnimation.running)
                    root.pageProgress = root.currentPage;
            }

            // Pane 0: Home (Music player)
            readonly property alias musicPage: homePage

            Item {
                id: homePage

                width: viewport.width
                height: viewport.height
                x: root.clampedPageProgress * root.pageSlideDistance
                opacity: 1 - root.clampedPageProgress
                enabled: opacity > 0.001

                Column {
                    anchors.fill: parent
                    anchors.margins: userConfig.boringNotchEnabled ? 16 : 20
                    spacing: userConfig.boringNotchEnabled ? 10 : 14

                    Item {
                        id: notchHeader
                        width: parent.width
                        height: 24
                        visible: userConfig.boringNotchEnabled

                        // Left tabs: Music / Timer / Shelf
                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Rectangle {
                                width: tabMusicText.implicitWidth + 16
                                height: 22
                                radius: 11
                                color: root.currentPage === 0 ? "#323236" : "transparent"
                                border.width: root.currentPage === 0 ? 0 : 1
                                border.color: "#3a3a3c"

                                Text {
                                    id: tabMusicText
                                    anchors.centerIn: parent
                                    text: "Music"
                                    color: root.currentPage === 0 ? "white" : "#8e8e93"
                                    font.pixelSize: 11
                                    font.family: root.textFontFamily
                                    font.weight: root.currentPage === 0 ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showPage(0)
                                }
                            }

                            Rectangle {
                                width: tabTimerText.implicitWidth + 16
                                height: 22
                                radius: 11
                                color: root.currentPage === 1 ? "#323236" : "transparent"
                                border.width: root.currentPage === 1 ? 0 : 1
                                border.color: "#3a3a3c"

                                Text {
                                    id: tabTimerText
                                    anchors.centerIn: parent
                                    text: "Timer"
                                    color: root.currentPage === 1 ? "white" : "#8e8e93"
                                    font.pixelSize: 11
                                    font.family: root.textFontFamily
                                    font.weight: root.currentPage === 1 ? Font.DemiBold : Font.Normal
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showPage(1)
                                }
                            }

                            Rectangle {
                                width: tabShelfText.implicitWidth + 16
                                height: 22
                                radius: 11
                                color: "transparent"
                                border.width: 1
                                border.color: "#3a3a3c"

                                Text {
                                    id: tabShelfText
                                    anchors.centerIn: parent
                                    text: "Shelf"
                                    color: "#8e8e93"
                                    font.pixelSize: 11
                                    font.family: root.textFontFamily
                                    font.weight: Font.Normal
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.shelfRequested()
                                }
                            }
                        }

                        // Right: Battery & Settings
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                visible: root.batteryCapacity >= 0

                                Text {
                                    text: (root.isCharging ? "󰂄 " : "󰁹 ") + root.batteryCapacity + "%"
                                    color: root.isCharging ? "#30d158" : (root.batteryCapacity <= 20 ? "#ff453a" : "#8e8e93")
                                    font.pixelSize: 11
                                    font.family: root.iconFontFamily
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Item {
                                width: 22
                                height: 22
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
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
                                        onClicked: root.cameraMirrorActive = !root.cameraMirrorActive
                                    }
                                }
                            }

                            Item {
                                width: 22
                                height: 22
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
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
                                        onClicked: SystemServices.ensureUserConfigAvailable()
                                    }
                                }
                            }

                            Item {
                                width: 22
                                height: 22
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
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
                    }

                    Row {
                        width: parent.width
                        height: parent.height - notchHeader.height - parent.spacing
                        spacing: 12

                        Row {
                            id: musicPlayerSection
                            width: (calendarTile.visible || webcamTile.visible)
                                ? parent.width - 190 - parent.spacing * 2
                                : parent.width
                            height: parent.height
                            spacing: userConfig.boringNotchEnabled ? 14 : 14
                            clip: true

                            // Left: Larger Album Art (106x106) with lighting effect
                            Item {
                                id: albumArtWrapper
                                width: userConfig.boringNotchEnabled ? 106 : 60
                                height: userConfig.boringNotchEnabled ? 106 : 60
                                anchors.verticalCenter: parent.verticalCenter

                                MultiEffect {
                                    anchors.centerIn: parent
                                    width: parent.width * 1.45
                                    height: parent.height * 1.45
                                    source: albumArtImage
                                    blurEnabled: true
                                    blur: 0.8
                                    blurMax: 20
                                    opacity: root.isPlaying && currentArtUrl !== "" ? 0.65 : 0.0
                                    visible: opacity > 0.001

                                    Behavior on opacity {
                                        NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
                                    }
                                }

                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: userConfig.boringNotchEnabled ? 15 : 10
                                    color: "#2c2c2e"
                                    antialiasing: true

                                    Image {
                                        id: albumArtImage
                                        anchors.fill: parent
                                        source: currentArtUrl
                                        fillMode: Image.PreserveAspectCrop
                                        visible: source.toString() !== ""
                                        sourceSize: Qt.size(180, 180)
                                        smooth: true
                                        onStatusChanged: {
                                            if (status === Image.Ready)
                                                colorExtractor.requestPaint();
                                        }
                                    }

                                    Canvas {
                                        id: colorExtractor
                                        width: 1
                                        height: 1
                                        visible: false
                                        property color extractedColor: "#b56cff"

                                        onPaint: {
                                            const ctx = getContext("2d");
                                            try {
                                                ctx.drawImage(albumArtImage, 0, 0, 1, 1);
                                                const pixel = ctx.getImageData(0, 0, 1, 1).data;
                                                if (pixel && pixel.length >= 3) {
                                                    let r = pixel[0], g = pixel[1], b = pixel[2];
                                                    const max = Math.max(r, g, b);
                                                    if (max < 140 && max > 0) {
                                                        const factor = 170 / max;
                                                        r = Math.min(255, Math.round(r * factor));
                                                        g = Math.min(255, Math.round(g * factor));
                                                        b = Math.min(255, Math.round(b * factor));
                                                    }
                                                    extractedColor = Qt.rgba(r / 255, g / 255, b / 255, 1.0);
                                                }
                                            } catch (e) {}
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰎆"
                                        color: "#8e8e93"
                                        font.family: root.iconFontFamily
                                        font.pixelSize: userConfig.boringNotchEnabled ? 36 : 24
                                        visible: !root.currentArtUrl || root.currentArtUrl === ""
                                    }
                                }
                            }

                            // Right: Controls column
                            Column {
                                id: musicControlsColumn
                                width: Math.max(0, parent.width - albumArtWrapper.width - parent.spacing)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: userConfig.boringNotchEnabled ? 4 : 8
                                clip: true

                                // Track title, artist, live lyrics & mini visualizer
                                Item {
                                    width: parent.width
                                    height: songInfoCol.implicitHeight

                                    Column {
                                        id: songInfoCol
                                        anchors.left: parent.left
                                        anchors.right: miniVisualizer.left
                                        anchors.rightMargin: 6
                                        spacing: 1

                                        Text {
                                            text: currentTrack !== "" ? currentTrack : "Not Playing"
                                            color: "white"
                                            font.pixelSize: userConfig.boringNotchEnabled ? 13 : userConfig.bodyFontSize
                                            font.family: textFontFamily
                                            font.weight: Font.Bold
                                            font.letterSpacing: -0.2
                                            width: parent.width
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        Text {
                                            text: currentArtist
                                            color: "#8e8e93"
                                            font.pixelSize: userConfig.boringNotchEnabled ? 11 : userConfig.bodyFontSize - 3
                                            font.family: textFontFamily
                                            font.weight: Font.Medium
                                            width: parent.width
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            visible: currentArtist !== ""
                                        }

                                        Text {
                                            text: root.lyricsText
                                            color: userConfig.boringNotchEnabled ? colorExtractor.extractedColor : "#c0a0ff"
                                            font.pixelSize: userConfig.boringNotchEnabled ? 10 : userConfig.bodyFontSize - 4
                                            font.family: textFontFamily
                                            font.weight: Font.Medium
                                            width: parent.width
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                            visible: userConfig.boringNotchEnabled && root.lyricsText !== "" && root.lyricsText !== "No music playing" && root.isPlaying
                                        }
                                    }

                                    // Mini visualizer
                                    Row {
                                        id: miniVisualizer
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.topMargin: 2
                                        height: 12
                                        spacing: 2

                                        Repeater {
                                            model: 4

                                            Rectangle {
                                                width: 2.5
                                                height: isPlaying
                                                    ? 3 + (parent.height - 3) * visualizerLevel(index)
                                                    : (isPlaying ? 3 : 2)
                                                radius: 1.2
                                                color: isPlaying ? (userConfig.boringNotchEnabled ? colorExtractor.extractedColor : "#b56cff") : "#5f4b72"
                                                anchors.bottom: parent.bottom

                                                Behavior on height {
                                                    NumberAnimation {
                                                        duration: isPlaying ? 120 : 260
                                                        easing.type: Easing.InOutQuad
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Scrubber / Progress slider (compact)
                                Item {
                                    width: parent.width
                                    height: 12

                                    Text {
                                        id: timeL
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: timePlayed
                                        color: "#8e8e93"
                                        font.pixelSize: userConfig.boringNotchEnabled ? 9 : userConfig.bodyFontSize - 5
                                        font.family: textFontFamily
                                        font.weight: Font.Medium
                                    }

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: timeL.right
                                        anchors.right: timeR.left
                                        anchors.margins: 6
                                        height: 3
                                        radius: 1.5
                                        color: "#333333"

                                        Rectangle {
                                            height: parent.height
                                            radius: 1.5
                                            color: userConfig.boringNotchEnabled ? colorExtractor.extractedColor : "white"
                                            width: parent.width * trackProgress

                                            Behavior on color {
                                                ColorAnimation { duration: 250; easing.type: Easing.InOutQuad }
                                            }

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 500
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        id: timeR
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: timeTotal
                                        color: "#8e8e93"
                                        font.pixelSize: userConfig.boringNotchEnabled ? 9 : userConfig.bodyFontSize - 5
                                        font.family: textFontFamily
                                        font.weight: Font.Medium
                                    }
                                }

                                // Playback controls toolbar
                                Item {
                                    width: parent.width
                                    height: 24

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: userConfig.boringNotchEnabled ? 8 : 28

                                        Item {
                                            width: 20
                                            height: 20
                                            visible: userConfig.boringNotchEnabled
                                            scale: shuffleArea.pressed ? 0.8 : 1.0

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰒝"
                                                color: (activePlayer && activePlayer.shuffle) ? "#b56cff" : (shuffleArea.pressed ? "#888" : "#8e8e93")
                                                font.family: root.iconFontFamily
                                                font.pixelSize: 13
                                            }

                                            MouseArea {
                                                id: shuffleArea
                                                anchors.fill: parent
                                                anchors.margins: -6
                                                preventStealing: true
                                                onPressed: (mouse) => {
                                                    controlPressed();
                                                    mouse.accepted = true;
                                                }
                                                onClicked: {
                                                    if (activePlayer && activePlayer.shuffle !== undefined) {
                                                        activePlayer.shuffle = !activePlayer.shuffle;
                                                    }
                                                }
                                            }
                                        }

                                        Item {
                                            width: 20
                                            height: 20
                                            visible: userConfig.boringNotchEnabled
                                            scale: seekBackArea.pressed ? 0.8 : 1.0

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰕌"
                                                color: seekBackArea.pressed ? "#888" : "white"
                                                font.family: root.iconFontFamily
                                                font.pixelSize: 13
                                            }

                                            MouseArea {
                                                id: seekBackArea
                                                anchors.fill: parent
                                                anchors.margins: -6
                                                preventStealing: true
                                                onPressed: (mouse) => {
                                                    controlPressed();
                                                    mouse.accepted = true;
                                                }
                                                onClicked: root.seekOffset(-15)
                                            }
                                        }

                                        Item {
                                            width: 20
                                            height: 20
                                            scale: prevArea.pressed ? 0.8 : 1.0

                                            Behavior on scale {
                                                NumberAnimation { duration: 100 }
                                            }

                                            Canvas {
                                                anchors.fill: parent
                                                property color fillColor: prevArea.pressed ? "#888" : "white"

                                                onFillColorChanged: requestPaint()
                                                onPaint: {
                                                    var ctx = getContext("2d");
                                                    ctx.clearRect(0, 0, width, height);
                                                    ctx.fillStyle = fillColor;
                                                    ctx.strokeStyle = fillColor;
                                                    ctx.lineJoin = "round";
                                                    ctx.lineWidth = 1.6;
                                                    ctx.beginPath();
                                                    ctx.rect(2, 3, 2, 14);
                                                    ctx.moveTo(10, 3);
                                                    ctx.lineTo(4, 10);
                                                    ctx.lineTo(10, 17);
                                                    ctx.closePath();
                                                    ctx.moveTo(17, 3);
                                                    ctx.lineTo(11, 10);
                                                    ctx.lineTo(17, 17);
                                                    ctx.closePath();
                                                    ctx.fill();
                                                    ctx.stroke();
                                                }
                                            }

                                            MouseArea {
                                                id: prevArea
                                                anchors.fill: parent
                                                anchors.margins: -8
                                                preventStealing: true
                                                onPressed: (mouse) => {
                                                    controlPressed();
                                                    mouse.accepted = true;
                                                }
                                                onClicked: root.previousRequested()
                                            }
                                        }

                                        Item {
                                            width: 24
                                            height: 24
                                            scale: playArea.pressed ? 0.8 : 1.0

                                            Behavior on scale {
                                                NumberAnimation { duration: 100 }
                                            }

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                visible: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

                                                Rectangle { width: 4; height: 14; radius: 1.5; color: playArea.pressed ? "#888" : "white" }
                                                Rectangle { width: 4; height: 14; radius: 1.5; color: playArea.pressed ? "#888" : "white" }
                                            }

                                            Canvas {
                                                anchors.fill: parent
                                                visible: !activePlayer || activePlayer.playbackState !== MprisPlaybackState.Playing
                                                property color fillColor: playArea.pressed ? "#888" : "white"

                                                onFillColorChanged: requestPaint()
                                                onPaint: {
                                                    var ctx = getContext("2d");
                                                    ctx.clearRect(0, 0, width, height);
                                                    ctx.fillStyle = fillColor;
                                                    ctx.strokeStyle = fillColor;
                                                    ctx.lineJoin = "round";
                                                    ctx.lineWidth = 1.6;
                                                    ctx.beginPath();
                                                    ctx.moveTo(7, 3);
                                                    ctx.lineTo(18, 12);
                                                    ctx.lineTo(7, 21);
                                                    ctx.closePath();
                                                    ctx.fill();
                                                    ctx.stroke();
                                                }
                                            }

                                            MouseArea {
                                                id: playArea
                                                anchors.fill: parent
                                                anchors.margins: -8
                                                preventStealing: true
                                                onPressed: (mouse) => {
                                                    controlPressed();
                                                    mouse.accepted = true;
                                                }
                                                onClicked: togglePlayback()
                                            }
                                        }

                                        Item {
                                            width: 20
                                            height: 20
                                            scale: nextArea.pressed ? 0.8 : 1.0

                                            Behavior on scale {
                                                NumberAnimation { duration: 100 }
                                            }

                                            Canvas {
                                                anchors.fill: parent
                                                property color fillColor: nextArea.pressed ? "#888" : "white"

                                                onFillColorChanged: requestPaint()
                                                onPaint: {
                                                    var ctx = getContext("2d");
                                                    ctx.clearRect(0, 0, width, height);
                                                    ctx.fillStyle = fillColor;
                                                    ctx.strokeStyle = fillColor;
                                                    ctx.lineJoin = "round";
                                                    ctx.lineWidth = 1.6;
                                                    ctx.beginPath();
                                                    ctx.moveTo(3, 3);
                                                    ctx.lineTo(9, 10);
                                                    ctx.lineTo(3, 17);
                                                    ctx.closePath();
                                                    ctx.moveTo(10, 3);
                                                    ctx.lineTo(16, 10);
                                                    ctx.lineTo(10, 17);
                                                    ctx.closePath();
                                                    ctx.rect(16, 3, 2, 14);
                                                    ctx.fill();
                                                    ctx.stroke();
                                                }
                                            }

                                            MouseArea {
                                                id: nextArea
                                                anchors.fill: parent
                                                anchors.margins: -8
                                                preventStealing: true
                                                onPressed: (mouse) => {
                                                    controlPressed();
                                                    mouse.accepted = true;
                                                }
                                                onClicked: if (activePlayer) activePlayer.next()
                                            }
                                        }

                                        Item {
                                            width: 20
                                            height: 20
                                            visible: userConfig.boringNotchEnabled
                                            scale: seekFwdArea.pressed ? 0.8 : 1.0

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰕎"
                                                color: seekFwdArea.pressed ? "#888" : "white"
                                                font.family: root.iconFontFamily
                                                font.pixelSize: 13
                                            }

                                            MouseArea {
                                                id: seekFwdArea
                                                anchors.fill: parent
                                                anchors.margins: -6
                                                preventStealing: true
                                                onPressed: (mouse) => {
                                                    controlPressed();
                                                    mouse.accepted = true;
                                                }
                                                onClicked: root.seekOffset(15)
                                            }
                                        }

                                        Item {
                                            width: 20
                                            height: 20
                                            visible: userConfig.boringNotchEnabled
                                            scale: repeatArea.pressed ? 0.8 : 1.0

                                            Text {
                                                anchors.centerIn: parent
                                                text: (activePlayer && String(activePlayer.loopStatus).toLowerCase().indexOf("track") !== -1) ? "󰑘" : "󰑖"
                                                color: (activePlayer && String(activePlayer.loopStatus).toLowerCase() !== "none") ? "#b56cff" : (repeatArea.pressed ? "#888" : "#8e8e93")
                                                font.family: root.iconFontFamily
                                                font.pixelSize: 13
                                            }

                                            MouseArea {
                                                id: repeatArea
                                                anchors.fill: parent
                                                anchors.margins: -6
                                                preventStealing: true
                                                onPressed: (mouse) => {
                                                    controlPressed();
                                                    mouse.accepted = true;
                                                }
                                                onClicked: {
                                                    if (activePlayer && activePlayer.loopStatus !== undefined) {
                                                        const s = String(activePlayer.loopStatus).toLowerCase();
                                                        if (s === "none") activePlayer.loopStatus = "Playlist";
                                                        else if (s === "playlist") activePlayer.loopStatus = "Track";
                                                        else activePlayer.loopStatus = "None";
                                                    }
                                                }
                                            }
                                        }

                                        Row {
                                            id: volControlRow
                                            spacing: 3
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: userConfig.boringNotchEnabled

                                            Item {
                                                width: 20
                                                height: 20
                                                scale: volArea.pressed ? 0.8 : 1.0

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: (activePlayer && activePlayer.volume === 0) ? "󰖁" : "󰕾"
                                                    color: volArea.pressed ? "#888" : "white"
                                                    font.family: root.iconFontFamily
                                                    font.pixelSize: 13
                                                }

                                                MouseArea {
                                                    id: volArea
                                                    anchors.fill: parent
                                                    anchors.margins: -6
                                                    preventStealing: true
                                                    onPressed: (mouse) => {
                                                        controlPressed();
                                                        mouse.accepted = true;
                                                    }
                                                    onClicked: {
                                                        volSliderWrapper.showSlider = !volSliderWrapper.showSlider;
                                                    }
                                                }
                                            }

                                            Item {
                                                id: volSliderWrapper
                                                property bool showSlider: false
                                                width: showSlider ? 44 : 0
                                                height: 14
                                                clip: true
                                                visible: width > 0
                                                opacity: showSlider ? 1 : 0
                                                anchors.verticalCenter: parent.verticalCenter

                                                Behavior on width {
                                                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                                }
                                                Behavior on opacity {
                                                    NumberAnimation { duration: 140; easing.type: Easing.InOutQuad }
                                                }

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 40
                                                    height: 3.5
                                                    radius: 1.75
                                                    color: "#3a3a3c"

                                                    Rectangle {
                                                        height: parent.height
                                                        radius: 1.75
                                                        color: colorExtractor.extractedColor
                                                        width: parent.width * Math.max(0, Math.min(1, (activePlayer && activePlayer.volume !== undefined) ? Number(activePlayer.volume) : 0.7))
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        anchors.margins: -6
                                                        preventStealing: true
                                                        onPressed: (mouse) => {
                                                            controlPressed();
                                                            const val = Math.max(0, Math.min(1, mouse.x / width));
                                                            if (activePlayer && activePlayer.volume !== undefined)
                                                                activePlayer.volume = val;
                                                        }
                                                        onPositionChanged: (mouse) => {
                                                            if (pressed) {
                                                                const val = Math.max(0, Math.min(1, mouse.x / width));
                                                                if (activePlayer && activePlayer.volume !== undefined)
                                                                    activePlayer.volume = val;
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

                Rectangle {
                    width: 1
                    height: parent.height - 8
                    color: "#2c2c2e"
                    anchors.verticalCenter: parent.verticalCenter
                    visible: calendarTile.visible || webcamTile.visible
                }

                BoringCalendarTile {
                    id: calendarTile
                    width: 190
                    height: parent.height
                    anchors.verticalCenter: parent.verticalCenter
                    visible: userConfig.boringNotchEnabled && homePage.width >= 560 && !root.cameraMirrorActive
                    textFontFamily: root.textFontFamily
                    iconFontFamily: root.iconFontFamily
                }

                WebcamMirrorTile {
                    id: webcamTile
                    width: 190
                    height: parent.height
                    anchors.verticalCenter: parent.verticalCenter
                    visible: userConfig.boringNotchEnabled && homePage.width >= 560 && root.cameraMirrorActive
                    isRunning: root.cameraMirrorActive
                    textFontFamily: root.textFontFamily
                    iconFontFamily: root.iconFontFamily
                }
            }
                }
            }

            TimerPage {
                id: timerPage

                x: -(1 - root.clampedPageProgress) * root.pageSlideDistance
                width: viewport.width
                height: viewport.height
                opacity: root.clampedPageProgress
                enabled: opacity > 0.001
                textFontFamily: root.textFontFamily
                timerSelectedHours: root.timerSelectedHours
                timerSelectedMinutes: root.timerSelectedMinutes
                timerTotalSeconds: root.timerTotalSeconds
                timerRemainingSeconds: root.timerRemainingSeconds
                timerRunning: root.timerRunning
                timerActive: root.timerActive
                onControlPressed: root.controlPressed()
                onKeyboardFocusRequested: root.keyboardFocusRequested()
                onTimerToggleRequested: function(hours, minutes) {
                    root.timerToggleRequested(hours, minutes);
                }
                onTimerResetRequested: root.timerResetRequested()
                onTimerDurationRequested: function(hours, minutes) {
                    root.timerDurationRequested(hours, minutes);
                }
            }
        }
    }

    component TimerPage: Item {
        id: timerRoot

        signal controlPressed()
        signal keyboardFocusRequested()
        signal timerToggleRequested(int hours, int minutes)
        signal timerResetRequested()
        signal timerDurationRequested(int hours, int minutes)

        readonly property var userConfig: UserConfig

        property string textFontFamily: userConfig.textFontFamily
        property int timerSelectedHours: 0
        property int timerSelectedMinutes: 5
        property int timerTotalSeconds: 300
        property int timerRemainingSeconds: 0
        property bool timerRunning: false
        property bool timerActive: false
        property real animatedProgress: 0
        property string focusTarget: "hour"

        readonly property int displaySeconds: timerActive ? timerRemainingSeconds : 0
        readonly property real targetProgress: timerActive && timerTotalSeconds > 0 ? timerRemainingSeconds / timerTotalSeconds : 0
        readonly property bool canStart: inputTotalSeconds() > 0 && (!timerActive || timerRemainingSeconds > 0)
        readonly property string timeText: {
            const hours = Math.floor(displaySeconds / 3600);
            const minutes = Math.floor((displaySeconds % 3600) / 60);
            const seconds = displaySeconds % 60;
            const minuteText = minutes < 10 ? "0" + minutes : "" + minutes;
            const secondText = seconds < 10 ? "0" + seconds : "" + seconds;

            if (hours > 0)
                return hours + ":" + minuteText + ":" + secondText;
            return minuteText + ":" + secondText;
        }

        function clampInt(value, minValue, maxValue) {
            const parsed = parseInt(value, 10);
            if (isNaN(parsed)) return minValue;
            return Math.max(minValue, Math.min(maxValue, parsed));
        }

        function inputHours() {
            return clampInt(hourInput.text, 0, 23);
        }

        function inputMinutes() {
            return clampInt(minuteInput.text, 0, 59);
        }

        function inputTotalSeconds() {
            return inputHours() * 3600 + inputMinutes() * 60;
        }

        function syncDurationFromInputs() {
            timerDurationRequested(inputHours(), inputMinutes());
            progressRing.requestPaint();
        }

        function normalizeInputs() {
            hourInput.text = "" + timerSelectedHours;
            minuteInput.text = timerSelectedMinutes < 10 ? "0" + timerSelectedMinutes : "" + timerSelectedMinutes;
        }

        function resetTimer() {
            timerResetRequested();
            progressRing.requestPaint();
        }

        function toggleTimer() {
            timerToggleRequested(inputHours(), inputMinutes());
        }

        function grabKeyboardFocus() {
            if (focusTarget === "minute")
                minuteInput.grabKeyboardFocus();
            else
                hourInput.grabKeyboardFocus();
        }

        onTargetProgressChanged: animatedProgress = targetProgress
        onAnimatedProgressChanged: progressRing.requestPaint()
        onTimerSelectedHoursChanged: normalizeInputs()
        onTimerSelectedMinutesChanged: normalizeInputs()
        Component.onCompleted: normalizeInputs()

        Behavior on animatedProgress {
            NumberAnimation {
                duration: 700
                easing.type: Easing.InOutCubic
            }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 18

            Item {
                width: 116
                height: parent.height

                Canvas {
                    id: progressRing

                    anchors.centerIn: parent
                    width: 104
                    height: 104

                    onPaint: {
                        const ctx = getContext("2d");
                        const centerX = width / 2;
                        const centerY = height / 2;
                        const lineWidth = 5;
                        const radius = Math.min(width, height) / 2 - lineWidth / 2;
                        const startAngle = -Math.PI / 2;
                        const progress = Math.max(0, Math.min(1, timerRoot.animatedProgress));
                        const endAngle = startAngle - Math.PI * 2 * progress;

                        ctx.clearRect(0, 0, width, height);
                        ctx.lineCap = "round";
                        ctx.lineWidth = lineWidth;

                        ctx.beginPath();
                        ctx.strokeStyle = "#2b2e35";
                        ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
                        ctx.stroke();

                        if (progress > 0) {
                            ctx.beginPath();
                            ctx.strokeStyle = "#ff9f0a";
                            ctx.arc(centerX, centerY, radius, startAngle, endAngle, true);
                            ctx.stroke();
                        }
                    }
                }

                Text {
                    anchors.centerIn: progressRing
                    text: timerRoot.timeText
                    color: "#ffffff"
                    font.pixelSize: timerRoot.displaySeconds >= 3600 ? timerRoot.userConfig.bodyFontSize + 2 : timerRoot.userConfig.bodyFontSize + 8
                    font.family: timerRoot.textFontFamily
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Column {
                width: parent.width - 173
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Row {
                    width: parent.width
                    height: 42
                    spacing: 8

                    TimerInput {
                        id: hourInput

                        width: (parent.width - 8) / 2
                        height: parent.height
                        label: "时"
                        text: "0"
                        textFontFamily: timerRoot.textFontFamily
                        onKeyboardFocusRequested: {
                            timerRoot.focusTarget = "hour";
                            timerRoot.keyboardFocusRequested();
                        }
                        onEditingFinished: {
                            timerRoot.syncDurationFromInputs();
                            timerRoot.normalizeInputs();
                        }
                    }

                    TimerInput {
                        id: minuteInput

                        width: (parent.width - 8) / 2
                        height: parent.height
                        label: "分"
                        text: "05"
                        textFontFamily: timerRoot.textFontFamily
                        onKeyboardFocusRequested: {
                            timerRoot.focusTarget = "minute";
                            timerRoot.keyboardFocusRequested();
                        }
                        onEditingFinished: {
                            timerRoot.syncDurationFromInputs();
                            timerRoot.normalizeInputs();
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 34
                    spacing: 8

                    TimerButton {
                        width: (parent.width - 8) / 2
                        height: parent.height
                        label: timerRoot.timerRunning ? "Stop" : (timerRoot.timerActive && timerRoot.timerRemainingSeconds < timerRoot.timerTotalSeconds && timerRoot.timerRemainingSeconds > 0 ? "Continue" : "Start")
                        enabled: timerRoot.timerRunning || timerRoot.canStart
                        accent: true
                        textFontFamily: timerRoot.textFontFamily
                        onClicked: timerRoot.toggleTimer()
                        onPressed: timerRoot.controlPressed()
                    }

                    TimerButton {
                        width: (parent.width - 8) / 2
                        height: parent.height
                        label: "Reset"
                        textFontFamily: timerRoot.textFontFamily
                        onClicked: timerRoot.resetTimer()
                        onPressed: timerRoot.controlPressed()
                    }
                }
            }
        }
    }

    component TimerInput: Item {
        id: inputRoot

        signal editingFinished()
        signal keyboardFocusRequested()

        property alias text: input.text
        property string label: ""
        property string textFontFamily: ""
        property int focusAttempts: 0

        function grabKeyboardFocus() {
            inputRoot.keyboardFocusRequested();
            focusAttempts = 4;
            input.forceActiveFocus();
            input.selectAll();
            focusRetryTimer.restart();
        }

        Timer {
            id: focusRetryTimer

            interval: 16
            repeat: true
            onTriggered: {
                input.forceActiveFocus();
                input.selectAll();
                inputRoot.focusAttempts -= 1;
                if (inputRoot.focusAttempts <= 0)
                    stop();
            }
        }

        Item {
            anchors.fill: parent

            MatteSurface {
                anchors.fill: parent
                radius: 10
                hovered: input.activeFocus || inputMouseArea.containsMouse
                pressed: inputMouseArea.pressed
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 9
                color: StyleTokens.transparent
                border.width: 1
                border.color: input.activeFocus ? "#ff9f0a" : "#2b2e35"
            }

            MouseArea {
                id: inputMouseArea

                anchors.fill: parent
                z: 2
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                preventStealing: true
                onPressed: (mouse) => {
                    inputRoot.grabKeyboardFocus();
                    mouse.accepted = true;
                }
                onClicked: (mouse) => {
                    mouse.accepted = true;
                }
            }

            Row {
                z: 1
                anchors.centerIn: parent
                spacing: 4

                TextInput {
                    id: input

                    width: 42
                    property bool sanitizing: false
                    color: "#f5f5f7"
                    selectionColor: "#ff9f0a"
                    selectedTextColor: "#111111"
                    font.pixelSize: UserConfig.bodyFontSize + 2
                    font.family: inputRoot.textFontFamily
                    font.weight: Font.DemiBold
                    horizontalAlignment: TextInput.AlignRight
                    validator: IntValidator {
                        bottom: 0
                        top: 99
                    }
                    inputMethodHints: Qt.ImhDigitsOnly
                    cursorVisible: activeFocus
                    onActiveFocusChanged: if (activeFocus) inputRoot.keyboardFocusRequested()
                    onTextChanged: {
                        if (sanitizing)
                            return;

                        const digits = text.replace(/[^0-9]/g, "").slice(0, 2);
                        if (digits !== text) {
                            sanitizing = true;
                            text = digits;
                            sanitizing = false;
                        }
                    }
                    onEditingFinished: inputRoot.editingFinished()
                    Keys.onReturnPressed: inputRoot.editingFinished()
                    Keys.onEnterPressed: inputRoot.editingFinished()
                }

                Text {
                    text: inputRoot.label
                    color: "#9b9da4"
                    font.pixelSize: UserConfig.bodyFontSize - 3
                    font.family: inputRoot.textFontFamily
                    font.weight: Font.Medium
                }
            }
        }
    }

    component TimerButton: Item {
        id: buttonRoot

        signal pressed()
        signal clicked()

        property string label: ""
        property bool accent: false
        property string textFontFamily: ""

        opacity: enabled ? 1.0 : 0.45
        scale: buttonArea.pressed ? 0.96 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 90
                easing.type: Easing.OutCubic
            }
        }

        Item {
            anchors.fill: parent

            MatteSurface {
                anchors.fill: parent
                radius: 10
                hovered: buttonArea.containsMouse
                pressed: buttonArea.pressed
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 9
                color: buttonRoot.accent
                    ? (buttonArea.pressed ? "#d98500" : "#ff9f0a")
                    : StyleTokens.transparent
                border.width: 1
                border.color: buttonRoot.accent ? "#ff9f0a" : "#2b2e35"
            }
        }

        Text {
            anchors.centerIn: parent
            text: buttonRoot.label
            color: buttonRoot.accent ? "#111111" : "#f5f5f7"
            font.pixelSize: UserConfig.bodyFontSize - 2
            font.family: buttonRoot.textFontFamily
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            enabled: buttonRoot.enabled
            hoverEnabled: true
            preventStealing: true
            onPressed: (mouse) => {
                buttonRoot.pressed();
                mouse.accepted = true;
            }
            onClicked: buttonRoot.clicked()
        }
    }
}
