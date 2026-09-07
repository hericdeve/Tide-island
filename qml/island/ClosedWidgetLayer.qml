import QtQuick
import IslandBackend
import "../widgets"

// Closed notch (pill/notch mode) widget layer.
// Reads widgetLayouts.minimum and renders Minimum-size widgets.
// Features unified horizontal swipe navigation matching expanded notch:
// DragHandler, WheelHandler, and MultiPointTouchArea with velocity and rubber-banding.
Item {
    id: root

    readonly property var userConfig: UserConfig

    property bool showCondition: false
    property int batteryCapacity: -1
    property bool isCharging: false
    property string currentArtUrl: ""
    property string currentTrack: ""
    property string currentArtist: ""
    property bool isPlaying: false
    property real trackProgress: 0
    property string currentTime: "00:00"
    property string iconFontFamily: "Sans Serif"
    property string textFontFamily: "Sans Serif"
    property string heroFontFamily: "Sans Serif"

    // Current page tracking & animation
    property int currentPage: 0
    property alias currentPageIndex: root.currentPage
    property real pageProgress: 0
    property bool isDropTargetActive: false

    signal pageChanged(int newPage)

    readonly property var minimumLayouts: (userConfig && userConfig.widgetLayouts && userConfig.widgetLayouts.minimum)
        ? userConfig.widgetLayouts.minimum : null
    readonly property var minimumPages: minimumLayouts ? (minimumLayouts.pages || []) : []
    readonly property int pageCount: Math.max(1, minimumPages.length)
    readonly property real clampedPageProgress: Math.max(0, Math.min(pageCount - 1, pageProgress))
    readonly property real pageSlideDistance: Math.max(1, width + 16)

    function settlePage(target) {
        const clampedTarget = Math.max(0, Math.min(pageCount - 1, target));
        settleAnimation.stop();
        settleAnimation.from = pageProgress;
        settleAnimation.to = clampedTarget;
        settleAnimation.restart();
    }

    NumberAnimation {
        id: settleAnimation
        target: root
        property: "pageProgress"
        duration: 220
        easing.type: Easing.OutCubic
        onFinished: {
            root.currentPage = Math.round(root.pageProgress);
            root.pageChanged(root.currentPage);
        }
    }

    onCurrentPageChanged: {
        if (!settleAnimation.running) {
            pageProgress = currentPage;
        }
    }

    // Shared context passed down into each Minimum widget
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
        currentTime: root.currentTime,
        iconFontFamily: root.iconFontFamily,
        textFontFamily: root.textFontFamily,
        heroFontFamily: root.heroFontFamily,
        uiScale: 1.0,
        isEditMode: false
    })

    anchors.fill: parent
    clip: true
    opacity: showCondition ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.showCondition ? 200 : 140
            easing.type: Easing.InOutQuad
        }
    }

    // 1. Interactive horizontal swipe/drag gesture handling for page switching (matching expanded notch)
    DragHandler {
        id: swipeDragHandler
        target: null
        enabled: root.pageCount > 1 && !root.isDropTargetActive
        acceptedButtons: Qt.LeftButton
        xAxis.enabled: true
        yAxis.enabled: false
        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.ApprovesTakeOverByAnything

        property real startPageProgress: 0
        property double swipeStartTime: 0

        onActiveChanged: {
            if (active) {
                settleAnimation.stop();
                startPageProgress = root.pageProgress;
                swipeStartTime = Date.now();
            } else {
                const elapsedMs = Math.max(16, Date.now() - swipeStartTime);
                const velocityX = activeTranslation.x / elapsedMs;

                let target = Math.round(root.pageProgress);
                if (velocityX > 0.35) {
                    target = Math.floor(root.pageProgress);
                } else if (velocityX < -0.35) {
                    target = Math.ceil(root.pageProgress);
                }
                root.settlePage(target);
            }
        }

        onActiveTranslationChanged: {
            if (active) {
                const deltaPages = -activeTranslation.x / root.pageSlideDistance;
                let newProgress = startPageProgress + deltaPages;
                if (newProgress < 0) {
                    newProgress = newProgress * 0.25;
                } else if (newProgress > root.pageCount - 1) {
                    newProgress = (root.pageCount - 1) + (newProgress - (root.pageCount - 1)) * 0.25;
                }
                root.pageProgress = newProgress;
            }
        }
    }

    // 2. Direct multi-touch swipe support (when 2 fingers are detected on touch input)
    MultiPointTouchArea {
        id: twoFingerTouchStrip
        anchors.fill: parent
        enabled: root.pageCount > 1 && !root.isDropTargetActive
        mouseEnabled: false
        minimumTouchPoints: 2
        maximumTouchPoints: 2

        property real startTouchX: 0
        property real startPageProgress: 0

        onPressed: (touchPoints) => {
            settleAnimation.stop();
            startTouchX = (touchPoints[0].x + touchPoints[1].x) / 2;
            startPageProgress = root.pageProgress;
        }

        onUpdated: (touchPoints) => {
            const currentTouchX = (touchPoints[0].x + touchPoints[1].x) / 2;
            const deltaPages = -(currentTouchX - startTouchX) / root.pageSlideDistance;
            let newProgress = startPageProgress + deltaPages;
            if (newProgress < 0) {
                newProgress = newProgress * 0.25;
            } else if (newProgress > root.pageCount - 1) {
                newProgress = (root.pageCount - 1) + (newProgress - (root.pageCount - 1)) * 0.25;
            }
            root.pageProgress = newProgress;
        }

        onReleased: (touchPoints) => {
            root.settlePage(Math.round(root.pageProgress));
        }
    }

    // 3. Wheel handler for touchpad / mouse wheel horizontal swipe cycling
    Timer {
        id: closedWheelResetTimer
        interval: 200
        repeat: false
        onTriggered: {
            closedWheelHandler.accumulated = 0;
            closedWheelHandler.gestureLocked = false;
        }
    }

    WheelHandler {
        id: closedWheelHandler
        target: null
        orientation: Qt.Horizontal | Qt.Vertical
        acceptedDevices: PointerDevice.AllDevices
        property real accumulated: 0
        property bool gestureLocked: false

        onWheel: function(event) {
            if (root.pageCount <= 1) return;
            if (event.phase === Qt.ScrollMomentum) {
                event.accepted = true;
                return;
            }
            if (event.phase === Qt.ScrollEnd) {
                closedWheelHandler.accumulated = 0;
                closedWheelHandler.gestureLocked = false;
                event.accepted = true;
                return;
            }
            if (closedWheelHandler.gestureLocked) {
                closedWheelResetTimer.restart();
                event.accepted = true;
                return;
            }

            const px = (event.pixelDelta && event.pixelDelta.x !== undefined) ? event.pixelDelta.x : 0;
            const py = (event.pixelDelta && event.pixelDelta.y !== undefined) ? event.pixelDelta.y : 0;
            const ax = (event.angleDelta && event.angleDelta.x !== undefined) ? (event.angleDelta.x / 5) : 0;
            const ay = (event.angleDelta && event.angleDelta.y !== undefined) ? (event.angleDelta.y / 5) : 0;

            const dx = Math.abs(px) > 0.001 ? px : ax;
            const dy = Math.abs(py) > 0.001 ? py : ay;

            if (Math.abs(dx) < 0.5) return;
            if (Math.abs(dy) > Math.abs(dx) * 1.5) return;

            closedWheelResetTimer.restart();
            closedWheelHandler.accumulated += dx;

            if (closedWheelHandler.accumulated < -12) {
                root.settlePage(root.currentPage + 1);
                closedWheelHandler.accumulated = 0;
                closedWheelHandler.gestureLocked = true;
                event.accepted = true;
            } else if (closedWheelHandler.accumulated > 12) {
                root.settlePage(root.currentPage - 1);
                closedWheelHandler.accumulated = 0;
                closedWheelHandler.gestureLocked = true;
                event.accepted = true;
            }
        }
    }

    // 4. Page strip: slides and fades pages interactively according to clampedPageProgress
    Item {
        id: pageStrip
        anchors.fill: parent
        clip: true

        Repeater {
            model: root.pageCount

            Item {
                id: pageDelegateItem
                readonly property int pIdx: index
                readonly property var pageData: root.minimumPages[pIdx] || null
                readonly property int slotCount: Math.max(1, Math.min(6, (pageData && pageData.slots !== undefined) ? pageData.slots : 1))
                readonly property var items: (pageData && pageData.items) ? pageData.items : []

                readonly property real pageOffset: (pIdx - root.clampedPageProgress) * root.pageSlideDistance
                width: pageStrip.width
                height: pageStrip.height
                x: pageOffset
                opacity: Math.max(0, 1 - Math.abs(pIdx - root.clampedPageProgress))
                visible: opacity > 0.001
                enabled: pIdx === root.currentPage

                // Horizontal row of Minimum slots for this page
                Row {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: root.pageCount > 1 ? -2 : 0
                    spacing: 8

                    Repeater {
                        model: pageDelegateItem.slotCount

                        Item {
                            readonly property int sIdx: index
                            readonly property var placedItem: {
                                const its = pageDelegateItem.items || [];
                                for (let i = 0; i < its.length; ++i) {
                                    if (its[i] && its[i].slotIndex === sIdx)
                                        return its[i];
                                }
                                return null;
                            }
                            readonly property string widgetId: placedItem ? (placedItem.widgetId || "") : ""

                            width: closedSlotWidth
                            height: pageStrip.height

                            readonly property real closedSlotWidth: {
                                const totalSpacing = (pageDelegateItem.slotCount - 1) * 8;
                                return Math.max(50, (pageStrip.width - totalSpacing - 24) / Math.max(1, pageDelegateItem.slotCount));
                            }

                            Loader {
                                anchors.fill: parent
                                active: parent.widgetId !== ""
                                source: active ? WidgetRegistry.getComponentUrl(parent.widgetId, "minimum") : ""

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

                            // Empty slot placeholder in closed mode — subtle dash
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width - 8, 32)
                                height: 2
                                radius: 1
                                color: "#48484a"
                                visible: parent.widgetId === ""
                            }
                        }
                    }
                }
            }
        }
    }

    // 5. Page indicator dots (visible when > 1 page)
    Row {
        visible: root.pageCount > 1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2.5
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4
        z: 10

        Repeater {
            model: root.pageCount

            Rectangle {
                readonly property int dotIndex: index
                readonly property bool isActive: dotIndex === root.currentPage
                width: isActive ? 12 : 4
                height: 3.5
                radius: 1.75
                color: isActive ? "#ffffff" : "#48484a"

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
                    onClicked: root.settlePage(dotIndex)
                }
            }
        }
    }

    // Drop target highlight when dragging a minimum widget over closed pill
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: 1.5
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
}
