import QtQuick
import IslandBackend
import "../widgets"

// Circle mode widget layer.
// Reads widgetLayouts.circle and renders Circle-size widgets.
// Replaces the hardcoded CircleClosedLayer.
Item {
    id: root

    signal expandRequested()
    signal widgetLibraryRequested(string mode, int pageIndex, int slotIndex)

    readonly property var userConfig: UserConfig

    property string currentArtUrl: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property bool isPlaying: false
    property real trackProgress: 0
    property int batteryCapacity: -1
    property bool isCharging: false
    property real currentCpuUsage: 0
    property real currentRamUsage: 0
    property string currentTime: "00:00"
    property string currentDateLabel: ""
    property string iconFontFamily: "Sans Serif"
    property string textFontFamily: "Sans Serif"

    property int currentPageIndex: 0
    property bool isDropTargetActive: false

    // Hold-to-add-page progress (0.0 to 1.0)
    property real holdProgress: 0.0

    readonly property real circleDiameter: Math.min(width, height)
    readonly property real faceScale: Math.max(0.5, Math.min(1.0, 0.62 + (circleDiameter - 44.0) * 0.008))

    readonly property var circleLayouts: (userConfig && userConfig.widgetLayouts && userConfig.widgetLayouts.circle)
        ? userConfig.widgetLayouts.circle : null
    readonly property var circlePages: circleLayouts ? (circleLayouts.pages || []) : []
    readonly property int pageCount: Math.max(1, circlePages.length)

    // Shared context passed into each Circle widget
    readonly property var sharedWidgetContext: ({
        activePlayer: null,
        currentTrack: root.currentTrack,
        currentArtist: root.currentArtist,
        currentArtUrl: root.currentArtUrl,
        isPlaying: root.isPlaying,
        trackProgress: root.trackProgress,
        timePlayed: "0:00",
        timeTotal: "0:00",
        batteryCapacity: root.batteryCapacity,
        isCharging: root.isCharging,
        currentCpuUsage: root.currentCpuUsage,
        currentRamUsage: root.currentRamUsage,
        currentTime: root.currentTime,
        currentDateLabel: root.currentDateLabel,
        iconFontFamily: root.iconFontFamily,
        textFontFamily: root.textFontFamily,
        heroFontFamily: root.textFontFamily,
        faceScale: root.faceScale,
        circleDiameter: root.circleDiameter,
        uiScale: root.faceScale,
        isEditMode: false
    })

    anchors.fill: parent
    clip: true

    // Auto-advance to media widget page when music starts (if media_player is on a circle page)
    onCurrentTrackChanged: {
        if (currentTrack !== "") {
            for (let i = 0; i < circlePages.length; ++i) {
                const pg = circlePages[i];
                if (pg && pg.items) {
                    for (let j = 0; j < pg.items.length; ++j) {
                        if (pg.items[j].widgetId === "media_player") {
                            root.currentPageIndex = i;
                            return;
                        }
                    }
                }
            }
        }
    }

    // Gesture navigation
    Timer {
        id: wheelResetTimer
        interval: 160
        repeat: false
        onTriggered: {
            circleWheelHandler.accumulated = 0;
            circleWheelHandler.gestureLocked = false;
        }
    }

    WheelHandler {
        id: circleWheelHandler
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real accumulated: 0
        property bool gestureLocked: false

        onWheel: function(event) {
            if (event.phase === Qt.ScrollMomentum) {
                event.accepted = true;
                return;
            }
            const dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x : (event.angleDelta.x / 5);
            const dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : (event.angleDelta.y / 5);
            const delta = Math.abs(dx) >= Math.abs(dy) ? dx : dy;

            if (circleWheelHandler.gestureLocked) {
                wheelResetTimer.restart();
                event.accepted = true;
                return;
            }

            wheelResetTimer.restart();
            accumulated += delta;

            if (accumulated < -16) {
                root.currentPageIndex = Math.min(root.pageCount - 1, root.currentPageIndex + 1);
                accumulated = 0;
                gestureLocked = true;
                event.accepted = true;
            } else if (accumulated > 16) {
                root.currentPageIndex = Math.max(0, root.currentPageIndex - 1);
                accumulated = 0;
                gestureLocked = true;
                event.accepted = true;
            }
        }
    }

    SequentialAnimation {
        id: holdProgressAnim

        // Delay before radial progress starts filling — prevents progress ring from flashing on quick clicks
        PauseAnimation {
            duration: 250
        }

        NumberAnimation {
            target: root
            property: "holdProgress"
            from: 0.0
            to: 1.0
            duration: 450
            easing.type: Easing.Linear
        }

        ScriptAction {
            script: {
                if (tapArea.pressed && !tapArea.moved) {
                    tapArea.isHoldTriggered = true;
                    root.holdProgress = 0.0;
                    if (userConfig) {
                        const nextTitle = "Page " + (root.pageCount + 1);
                        userConfig.addPage("circle", nextTitle, 1);
                        root.currentPageIndex = Math.max(0, root.pageCount - 1);
                    }
                    popAnim.restart();
                }
            }
        }
    }

    SequentialAnimation {
        id: popAnim
        NumberAnimation {
            target: root
            property: "scale"
            to: 1.08
            duration: 110
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 1.0
            duration: 150
            easing.type: Easing.OutBack
        }
    }

    // Circular hold progress ring canvas
    Canvas {
        id: holdProgressCanvas
        anchors.fill: parent
        z: 90
        visible: root.holdProgress > 0.01

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.holdProgress <= 0.01) return;
            const center = width / 2;
            const radius = Math.max(8, center - 3);
            ctx.beginPath();
            ctx.arc(center, center, radius, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * root.holdProgress, false);
            ctx.lineWidth = 3;
            ctx.strokeStyle = "#d9ffffff";
            ctx.lineCap = "round";
            ctx.stroke();
        }

        Connections {
            target: root
            function onHoldProgressChanged() {
                holdProgressCanvas.requestPaint();
            }
        }
    }

    // Drop target highlight when dragging a circle widget over circle mode
    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: "#66ffffff"
        visible: root.isDropTargetActive
        z: 95

        SequentialAnimation on border.color {
            running: root.isDropTargetActive
            loops: Animation.Infinite
            ColorAnimation { from: "#59ffffff"; to: "#bfffffff"; duration: 600 }
            ColorAnimation { from: "#bfffffff"; to: "#59ffffff"; duration: 600 }
        }
    }

    MouseArea {
        id: tapArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real startX: 0
        property real startY: 0
        property bool moved: false
        property bool isHoldTriggered: false

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                return;
            }
            startX = mouse.x;
            startY = mouse.y;
            moved = false;
            isHoldTriggered = false;
            root.holdProgress = 0.0;
            holdProgressAnim.restart();
        }

        onPositionChanged: (mouse) => {
            if (mouse.buttons & Qt.LeftButton) {
                if (Math.abs(mouse.x - startX) > 8 || Math.abs(mouse.y - startY) > 8) {
                    moved = true;
                    holdProgressAnim.stop();
                    root.holdProgress = 0.0;
                }
            }
        }

        onCanceled: {
            holdProgressAnim.stop();
            root.holdProgress = 0.0;
            moved = false;
            isHoldTriggered = false;
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.widgetLibraryRequested("circle", root.currentPageIndex, 0);
                return;
            }
            holdProgressAnim.stop();
            root.holdProgress = 0.0;
            if (isHoldTriggered) {
                isHoldTriggered = false;
                moved = false;
                return;
            }

            const dx = mouse.x - startX;
            const dy = mouse.y - startY;
            if (moved) {
                if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 12) {
                    if (dx < 0)
                        root.currentPageIndex = Math.min(root.pageCount - 1, root.currentPageIndex + 1);
                    else
                        root.currentPageIndex = Math.max(0, root.currentPageIndex - 1);
                }
            } else {
                root.expandRequested();
            }
            moved = false;
        }
    }

    // Widget faces — each page renders its first widget filling the circle
    Repeater {
        model: root.pageCount

        Item {
            readonly property int pIdx: index
            readonly property var pageData: root.circlePages[pIdx] || null
            readonly property var items: (pageData && pageData.items) ? pageData.items : []
            readonly property var firstItem: items.length > 0 ? items[0] : null
            readonly property string widgetId: firstItem ? (firstItem.widgetId || "") : ""

            anchors.fill: parent
            opacity: pIdx === root.currentPageIndex ? 1.0 : 0.0
            scale: pIdx === root.currentPageIndex ? 1.0 : 0.88
            visible: Math.abs(pIdx - root.currentPageIndex) <= 1

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Loader {
                anchors.fill: parent
                active: parent.widgetId !== ""
                source: active ? WidgetRegistry.getComponentUrl(parent.widgetId, "circle") : ""

                onLoaded: {
                    if (item) {
                        item.widgetContext = root.sharedWidgetContext;
                        item.slotSpan = 1;
                        item.isEditMode = false;
                    }
                }
                onStatusChanged: {
                    if (status === Loader.Ready && item) {
                        item.widgetContext = root.sharedWidgetContext;
                        item.slotSpan = 1;
                        item.isEditMode = false;
                    }
                }
            }

            // Fallback: if Home page has no widget configured, show the original clock face inline
            Item {
                anchors.fill: parent
                visible: parent.widgetId === "" && parent.pIdx === 0

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 2
                    height: parent.height - 2
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: "#2c2c2e"
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.currentTime
                        color: "white"
                        font.family: root.textFontFamily
                        font.pixelSize: Math.max(9, Math.min(14, Math.round(10 + (root.circleDiameter - 44) * 0.08)))
                        font.weight: Font.Bold
                        font.letterSpacing: -0.2
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.currentDateLabel !== "" ? root.currentDateLabel : "Today"
                        color: "#8e8e93"
                        font.family: root.textFontFamily
                        font.pixelSize: Math.max(7, Math.min(10, Math.round(7.5 + (root.circleDiameter - 44) * 0.05)))
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }

            // Custom Page Empty State: Centered icon and Delete button at top
            // Leaving background open so clicks/swipes pass through to expandRequested and wheel navigation
            Item {
                id: customEmptyPage
                readonly property int pageIndex: parent.pIdx
                anchors.fill: parent
                visible: parent.widgetId === "" && parent.pIdx > 0

                // Centered subtle empty state placeholder
                Rectangle {
                    id: addBtnRect
                    anchors.centerIn: parent
                    width: Math.min(44, parent.width - 24)
                    height: width
                    radius: width / 2
                    color: "#14ffffff"
                    border.width: 1
                    border.color: "#2effffff"
                    z: 20

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰐕"
                            font.family: root.iconFontFamily
                            font.pixelSize: 14
                            color: "#ffffff"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Empty"
                            font.family: root.textFontFamily
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: "#8e8e93"
                        }
                    }
                }

                // Delete custom page button at top
                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 18
                    height: 18
                    radius: 9
                    color: delCircleMouse.containsMouse ? "#ff453a" : "#2a2a2e"
                    z: 50

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: root.iconFontFamily
                        font.pixelSize: 9
                        color: "white"
                    }

                    MouseArea {
                        id: delCircleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (userConfig) {
                                const targetIdx = customEmptyPage.pageIndex;
                                userConfig.removePage("circle", targetIdx);
                                root.currentPageIndex = Math.max(0, targetIdx - 1);
                            }
                        }
                    }
                }
            }
        }
    }

    // Page indicator dots (only when > 1 page)
    Row {
        visible: root.pageCount > 1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        Repeater {
            model: root.pageCount

            Rectangle {
                width: index === root.currentPageIndex ? 10 : 3
                height: 3
                radius: 1.5
                color: index === root.currentPageIndex ? "white" : "#48484a"

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: 180 }
                }
            }
        }
    }
}
