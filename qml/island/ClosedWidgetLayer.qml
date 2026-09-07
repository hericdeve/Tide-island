import QtQuick
import IslandBackend
import "../widgets"

// Closed notch (pill/notch mode) widget layer.
// Reads widgetLayouts.minimum and renders Minimum-size widgets.
// Replaces the hardcoded SwipeCustomInfoLayer for the default idle state.
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

    // Current page index — wheel/swipe advances through minimum pages
    property int currentPageIndex: 0

    readonly property var minimumLayouts: (userConfig && userConfig.widgetLayouts && userConfig.widgetLayouts.minimum)
        ? userConfig.widgetLayouts.minimum : null
    readonly property var minimumPages: minimumLayouts ? (minimumLayouts.pages || []) : []
    readonly property int pageCount: Math.max(1, minimumPages.length)

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

    // Wheel handler for cycling between minimum pages
    WheelHandler {
        id: closedWheelHandler
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real accumulated: 0

        onWheel: function(event) {
            if (root.pageCount <= 1) return;
            const dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x : (event.angleDelta.x / 5);
            const dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : (event.angleDelta.y / 5);
            const delta = Math.abs(dx) >= Math.abs(dy) ? dx : dy;
            accumulated += delta;
            if (accumulated < -16) {
                root.currentPageIndex = Math.min(root.pageCount - 1, root.currentPageIndex + 1);
                accumulated = 0;
                event.accepted = true;
            } else if (accumulated > 16) {
                root.currentPageIndex = Math.max(0, root.currentPageIndex - 1);
                accumulated = 0;
                event.accepted = true;
            }
        }
    }

    // Page strip: slide current page in from the side
    Item {
        id: pageStrip
        anchors.fill: parent
        clip: true

        Repeater {
            model: root.pageCount

            Item {
                readonly property int pIdx: index
                readonly property var pageData: root.minimumPages[pIdx] || null
                readonly property int slotCount: Math.max(1, Math.min(6, (pageData && pageData.slots !== undefined) ? pageData.slots : 1))
                readonly property var items: (pageData && pageData.items) ? pageData.items : []

                width: pageStrip.width
                height: pageStrip.height
                x: (pIdx - root.currentPageIndex) * pageStrip.width
                opacity: pIdx === root.currentPageIndex ? 1.0 : 0.0
                visible: Math.abs(pIdx - root.currentPageIndex) <= 1

                Behavior on x {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
                }

                // Horizontal row of Minimum slots for this page
                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    Repeater {
                        model: parent.parent.slotCount

                        Item {
                            readonly property int sIdx: index
                            readonly property var placedItem: {
                                const its = parent.parent.parent.items;
                                for (let i = 0; i < its.length; ++i) {
                                    if (its[i].slotIndex === sIdx)
                                        return its[i];
                                }
                                return null;
                            }
                            readonly property string widgetId: placedItem ? (placedItem.widgetId || "") : ""

                            width: closedSlotWidth
                            height: pageStrip.height

                            readonly property real closedSlotWidth: {
                                const totalSpacing = (parent.parent.parent.slotCount - 1) * 10;
                                return Math.max(60, (pageStrip.width - totalSpacing) / parent.parent.parent.slotCount);
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

    // Page indicator dots (only visible when > 1 page)
    Row {
        visible: root.pageCount > 1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        Repeater {
            model: root.pageCount

            Rectangle {
                width: index === root.currentPageIndex ? 12 : 4
                height: 4
                radius: 2
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
