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
    property bool dotsVisible: true
    property bool isEditMode: false

    Timer {
        id: dotsFadeTimer
        interval: 2500
        repeat: false
        running: true
        onTriggered: root.dotsVisible = false
    }

    onCurrentPageIndexChanged: {
        root.dotsVisible = true;
        dotsFadeTimer.restart();
    }

    onIsEditModeChanged: {
        root.dotsVisible = true;
        if (isEditMode) {
            dotsFadeTimer.stop();
        } else {
            dotsFadeTimer.restart();
            if (currentPageIndex >= realPageCount) {
                currentPageIndex = Math.max(0, realPageCount - 1);
            }
        }
    }

    // Hold-to-add-page progress (0.0 to 1.0)
    property real holdProgress: 0.0

    readonly property real circleDiameter: Math.min(width, height)
    readonly property real faceScale: Math.max(0.5, Math.min(1.0, 0.62 + (circleDiameter - 44.0) * 0.008))

    readonly property var circleLayouts: (userConfig && userConfig.widgetLayouts && userConfig.widgetLayouts.circle)
        ? userConfig.widgetLayouts.circle : null
    readonly property var circlePages: circleLayouts ? (circleLayouts.pages || []) : []
    readonly property int realPageCount: Math.max(1, circlePages.length)
    readonly property int totalPageCount: realPageCount + (isEditMode ? 1 : 0)
    readonly property int pageCount: totalPageCount

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
        isEditMode: root.isEditMode
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
        interval: 200
        repeat: false
        onTriggered: {
            circleWheelHandler.accumulated = 0;
            circleWheelHandler.gestureLocked = false;
        }
    }

    WheelHandler {
        id: circleWheelHandler
        target: null
        orientation: Qt.Horizontal | Qt.Vertical
        acceptedDevices: PointerDevice.AllDevices
        property real accumulated: 0
        property bool gestureLocked: false

        onWheel: function(event) {
            if (event.phase === Qt.ScrollMomentum) {
                event.accepted = true;
                return;
            }
            if (event.phase === Qt.ScrollEnd) {
                circleWheelHandler.accumulated = 0;
                circleWheelHandler.gestureLocked = false;
                event.accepted = true;
                return;
            }
            if (circleWheelHandler.gestureLocked) {
                wheelResetTimer.restart();
                event.accepted = true;
                return;
            }

            const px = (event.pixelDelta && event.pixelDelta.x !== undefined) ? event.pixelDelta.x : 0;
            const py = (event.pixelDelta && event.pixelDelta.y !== undefined) ? event.pixelDelta.y : 0;
            const ax = (event.angleDelta && event.angleDelta.x !== undefined) ? (event.angleDelta.x / 5) : 0;
            const ay = (event.angleDelta && event.angleDelta.y !== undefined) ? (event.angleDelta.y / 5) : 0;

            const dx = Math.abs(px) > 0.001 ? px : ax;
            const dy = Math.abs(py) > 0.001 ? py : ay;
            const delta = Math.abs(dx) >= Math.abs(dy) ? dx : dy;

            if (Math.abs(delta) < 0.5) return;

            root.dotsVisible = true;
            dotsFadeTimer.restart();

            wheelResetTimer.restart();
            accumulated += delta;

            if (accumulated < -12) {
                root.currentPageIndex = Math.min(root.pageCount - 1, root.currentPageIndex + 1);
                accumulated = 0;
                gestureLocked = true;
                event.accepted = true;
            } else if (accumulated > 12) {
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
                    if (!root.isEditMode) {
                        root.isEditMode = true;
                        root.currentPageIndex = root.realPageCount;
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
                    root.dotsVisible = true;
                    dotsFadeTimer.restart();
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
                root.widgetLibraryRequested("circle", Math.min(root.realPageCount - 1, root.currentPageIndex), 0);
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
                if (root.isEditMode) {
                    root.isEditMode = false;
                    if (root.currentPageIndex >= root.realPageCount)
                        root.currentPageIndex = Math.max(0, root.realPageCount - 1);
                } else {
                    root.expandRequested();
                }
            }
            moved = false;
        }
    }

    // Done button in edit mode
    Rectangle {
        id: circleDoneBtn
        visible: root.isEditMode
        anchors.top: parent.top
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: 32
        height: 13
        radius: 6.5
        color: circleDoneMouse.containsMouse ? "#50ffffff" : "#30ffffff"
        border.width: 1
        border.color: "#55ffffff"
        z: 100

        Text {
            anchors.centerIn: parent
            text: "Done"
            font.family: root.textFontFamily
            font.pixelSize: 8
            font.weight: Font.Bold
            color: "white"
        }

        MouseArea {
            id: circleDoneMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.isEditMode = false;
                if (root.currentPageIndex >= root.realPageCount)
                    root.currentPageIndex = Math.max(0, root.realPageCount - 1);
            }
        }
    }

    // Widget faces — each page renders its widget filling the circle (or Add Widget, or Offer Page)
    Repeater {
        model: root.pageCount

        Item {
            id: pageItem
            readonly property int pIdx: index
            readonly property bool isOfferPage: root.isEditMode && pIdx === root.realPageCount
            readonly property var pageData: !isOfferPage ? (root.circlePages[pIdx] || null) : null
            readonly property var items: (pageData && pageData.items) ? pageData.items : []
            readonly property var firstItem: items.length > 0 ? items[0] : null
            readonly property string widgetId: firstItem ? (firstItem.widgetId || "") : ""
            readonly property bool hasWidget: !isOfferPage && widgetId !== ""

            anchors.fill: parent
            opacity: pIdx === root.currentPageIndex ? 1.0 : 0.0
            scale: pIdx === root.currentPageIndex ? 1.0 : 0.88
            visible: Math.abs(pIdx - root.currentPageIndex) <= 1

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            // 1. Populated widget container with iOS home screen editing wiggle effect
            Item {
                id: circleJiggleContainer
                anchors.fill: parent
                visible: pageItem.hasWidget

                readonly property real angleAmplitude: 1.2 * (pageItem.pIdx % 2 === 0 ? 1.0 : -1.0)
                readonly property int rotDuration: 145 + ((pageItem.pIdx * 33) % 25)
                readonly property int transDuration: 170 + ((pageItem.pIdx * 41) % 30)

                property real currentRotation: 0
                property real xOffset: 0
                property real yOffset: 0

                transformOrigin: Item.Center
                rotation: root.isEditMode ? currentRotation : 0

                transform: Translate {
                    x: root.isEditMode ? circleJiggleContainer.xOffset : 0
                    y: root.isEditMode ? circleJiggleContainer.yOffset : 0
                }

                Loader {
                    anchors.fill: parent
                    active: pageItem.hasWidget
                    source: active ? WidgetRegistry.getComponentUrl(pageItem.widgetId, "circle") : ""

                    onLoaded: {
                        if (item) {
                            item.widgetContext = root.sharedWidgetContext;
                            item.slotSpan = 1;
                            item.isEditMode = root.isEditMode;
                        }
                    }
                    onStatusChanged: {
                        if (status === Loader.Ready && item) {
                            item.widgetContext = root.sharedWidgetContext;
                            item.slotSpan = 1;
                            item.isEditMode = root.isEditMode;
                        }
                    }
                }

                // Remove widget button in edit mode
                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 2
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    width: 14
                    height: 14
                    radius: 7
                    color: removeCircleMouse.containsMouse ? "#ff453a" : "#40000000"
                    border.width: 1
                    border.color: "#55ffffff"
                    visible: root.isEditMode
                    z: 99

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: root.iconFontFamily
                        font.pixelSize: 8
                        color: "white"
                    }

                    MouseArea {
                        id: removeCircleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (userConfig) {
                                userConfig.removeSlotWidget("circle", pageItem.pIdx, 0);
                            }
                        }
                    }
                }

                // Rotation wiggle animation
                SequentialAnimation {
                    running: root.isEditMode && pageItem.hasWidget
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: circleJiggleContainer
                        property: "currentRotation"
                        from: -circleJiggleContainer.angleAmplitude
                        to: circleJiggleContainer.angleAmplitude
                        duration: circleJiggleContainer.rotDuration
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: circleJiggleContainer
                        property: "currentRotation"
                        from: circleJiggleContainer.angleAmplitude
                        to: -circleJiggleContainer.angleAmplitude
                        duration: circleJiggleContainer.rotDuration
                        easing.type: Easing.InOutSine
                    }
                }

                // Translation wiggle animation
                SequentialAnimation {
                    running: root.isEditMode && pageItem.hasWidget
                    loops: Animation.Infinite

                    ParallelAnimation {
                        NumberAnimation {
                            target: circleJiggleContainer
                            property: "xOffset"
                            from: -(pageItem.pIdx % 2 === 0 ? 0.4 : -0.4)
                            to: (pageItem.pIdx % 2 === 0 ? 0.4 : -0.4)
                            duration: circleJiggleContainer.transDuration
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: circleJiggleContainer
                            property: "yOffset"
                            from: -0.5
                            to: 0.5
                            duration: Math.round(circleJiggleContainer.transDuration * 1.08)
                            easing.type: Easing.InOutQuad
                        }
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: circleJiggleContainer
                            property: "xOffset"
                            from: (pageItem.pIdx % 2 === 0 ? 0.4 : -0.4)
                            to: -(pageItem.pIdx % 2 === 0 ? 0.4 : -0.4)
                            duration: circleJiggleContainer.transDuration
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            target: circleJiggleContainer
                            property: "yOffset"
                            from: 0.5
                            to: -0.5
                            duration: Math.round(circleJiggleContainer.transDuration * 1.08)
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }

            // 2. Fallback clock face on Home page when NOT in edit mode and no widget
            Item {
                anchors.fill: parent
                visible: !pageItem.hasWidget && !pageItem.isOfferPage && pageItem.pIdx === 0 && !root.isEditMode

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

            // 3. Empty page state (Home page in edit mode with no widget, or any custom page without a widget)
            Item {
                id: customEmptyPage
                readonly property int pageIndex: pageItem.pIdx
                anchors.fill: parent
                visible: !pageItem.hasWidget && !pageItem.isOfferPage && (root.isEditMode || pageItem.pIdx > 0)

                // Centered prominent Add Widget button
                Rectangle {
                    id: addBtnRect
                    anchors.centerIn: parent
                    width: Math.min(42, parent.width - 10)
                    height: width
                    radius: width / 2
                    color: addCircleWidgetMouse.containsMouse ? "#30ffffff" : "#18ffffff"
                    border.width: 1
                    border.color: addCircleWidgetMouse.containsMouse ? "#55ffffff" : "#30ffffff"
                    z: 20

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰐕"
                            font.family: root.iconFontFamily
                            font.pixelSize: 13
                            color: "#ffffff"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Add"
                            font.family: root.textFontFamily
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            color: addCircleWidgetMouse.containsMouse ? "#ffffff" : "#c4c4c8"
                        }
                    }

                    MouseArea {
                        id: addCircleWidgetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.widgetLibraryRequested("circle", pageItem.pIdx, 0);
                        }
                    }
                }

                // Delete custom page button at bottom (only for page > 0, Home cannot be deleted)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 14
                    height: 14
                    radius: 7
                    color: delCircleMouse.containsMouse ? "#ff453a" : "#382a2a2e"
                    border.width: 1
                    border.color: "#33ffffff"
                    visible: pageItem.pIdx > 0
                    z: 50

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: root.iconFontFamily
                        font.pixelSize: 8
                        color: "white"
                    }

                    MouseArea {
                        id: delCircleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (userConfig) {
                                const targetIdx = pageItem.pIdx;
                                userConfig.removePage("circle", targetIdx);
                                root.currentPageIndex = Math.max(0, targetIdx - 1);
                            }
                        }
                    }
                }
            }

            // 4. Offer Page at the end (shown in edit mode to offer adding that last page)
            Item {
                id: offerPageItem
                anchors.fill: parent
                visible: pageItem.isOfferPage

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(42, parent.width - 10)
                    height: width
                    radius: width / 2
                    color: addCirclePageMouse.containsMouse ? "#38ffffff" : "#20ffffff"
                    border.width: 1.5
                    border.color: addCirclePageMouse.containsMouse ? "#77ffffff" : "#44ffffff"
                    z: 30

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰐕"
                            font.family: root.iconFontFamily
                            font.pixelSize: 13
                            color: "#ffffff"
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Add Page"
                            font.family: root.textFontFamily
                            font.pixelSize: 7
                            font.weight: Font.Bold
                            color: "white"
                        }
                    }

                    MouseArea {
                        id: addCirclePageMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (userConfig) {
                                const newPageIndex = root.realPageCount;
                                const nextTitle = "Page " + (newPageIndex + 1);
                                userConfig.addPage("circle", nextTitle, 1);
                                root.currentPageIndex = newPageIndex;
                            }
                        }
                    }
                }
            }
        }
    }

    // Page indicator dots (only when > 1 page, fades out after 2.5s)
    Row {
        id: pageDotsRow
        visible: root.pageCount > 1
        opacity: (root.dotsVisible || root.isEditMode) ? 1.0 : 0.0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 3
        z: 90

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
        }

        Repeater {
            model: root.pageCount

            Rectangle {
                readonly property int dotIndex: index
                readonly property bool isOfferDot: root.isEditMode && dotIndex === root.realPageCount
                readonly property bool isActive: dotIndex === root.currentPageIndex
                width: isActive ? 10 : 3
                height: 3
                radius: 1.5
                color: isActive ? "white" : (isOfferDot ? "#66ffffff" : "#48484a")
                border.width: isOfferDot && !isActive ? 0.5 : 0
                border.color: "#88ffffff"

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: 180 }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentPageIndex = parent.dotIndex
                }
            }
        }
    }
}
