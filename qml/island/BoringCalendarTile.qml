import QtQuick
import QtQuick.Controls
import IslandBackend
import "../widgets/components"

Item {
    id: root

    property var widgetContext: null
    property string textFontFamily: "Sans Serif"
    property string iconFontFamily: "Sans Serif"
    property var selectedDate: new Date()
    property var today: new Date()
    readonly property var userConfig: UserConfig
    readonly property real fontScale: userConfig ? Math.max(0.85, Math.min(1.3, userConfig.bodyFontSize / 16.0)) : 1.0

    readonly property var dayEvents: CalendarBackend ? CalendarBackend.eventsForDate(root.selectedDate) : []
    readonly property bool hasEvents: dayEvents && dayEvents.length > 0

    onSelectedDateChanged: {
        if (eventsListView) {
            eventsListView.contentY = 0;
        }
    }

    readonly property var dayShortNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var monthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    function isSameDay(d1, d2) {
        return d1.getFullYear() === d2.getFullYear()
            && d1.getMonth() === d2.getMonth()
            && d1.getDate() === d2.getDate();
    }

    function getDateForOffset(offset) {
        const d = new Date(today.getTime());
        d.setDate(today.getDate() + offset);
        return d;
    }

    function padZero(n) {
        return n < 10 ? "0" + n : String(n);
    }

    function formatMinimalTime(date) {
        if (!date || isNaN(date.getTime())) return "";
        const h = date.getHours();
        const m = date.getMinutes();
        if (m === 0) {
            return String(h);
        }
        const pad = (n) => (n < 10 ? "0" + n : String(n));
        return h + ":" + pad(m);
    }

    function formatEventPeriod(ev) {
        if (!ev) return "";
        if (ev.allDay) return "All-day";
        if (ev.startTime) {
            const start = new Date(ev.startTime);
            if (!isNaN(start.getTime())) {
                const startStr = formatMinimalTime(start);
                if (ev.endTime) {
                    const end = new Date(ev.endTime);
                    if (!isNaN(end.getTime()) && (end.getTime() !== start.getTime())) {
                        const endStr = formatMinimalTime(end);
                        return startStr + "-" + endStr;
                    }
                }
                return startStr;
            }
        }
        return ev.timeString || "";
    }

    // Top: Month/Year + Day Strip (Exact Image #5 layout)
    Row {
        id: headerRow
        anchors.top: parent.top
        anchors.topMargin: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        height: 48
        spacing: 6

        // Month & Year stack on left
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            spacing: 1

            Text {
                text: root.monthNames[root.today.getMonth()]
                color: StyleTokens.textPrimary
                font.pixelSize: Math.round(13 * root.fontScale)
                font.family: root.textFontFamily
                font.weight: Font.Bold
            }

            Text {
                text: String(root.today.getFullYear())
                color: StyleTokens.textSecondary
                font.pixelSize: Math.round(11 * root.fontScale)
                font.family: root.textFontFamily
                font.weight: Font.Medium
            }
        }

        // 6-day horizontal strip
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Repeater {
                model: 6

                delegate: Item {
                    readonly property int offset: index - 2
                    readonly property var dateObj: root.getDateForOffset(offset)
                    readonly property bool isToday: root.isSameDay(dateObj, root.today)
                    readonly property bool isSelected: root.isSameDay(dateObj, root.selectedDate)

                    width: isToday || isSelected ? 24 : 20
                    height: 44

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: isToday || isSelected ? StyleTokens.cardFillActive : StyleTokens.transparent

                        Column {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.dayShortNames[dateObj.getDay()]
                                color: isToday || isSelected ? StyleTokens.accentSoft : StyleTokens.textSecondary
                                font.pixelSize: Math.round(9 * root.fontScale)
                                font.family: root.textFontFamily
                                font.weight: isToday || isSelected ? Font.Bold : Font.Normal
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 17
                                height: 17
                                radius: 8.5
                                color: isToday ? StyleTokens.accent : (isSelected ? StyleTokens.accentPressed : StyleTokens.transparent)

                                Text {
                                    anchors.centerIn: parent
                                    text: root.padZero(dateObj.getDate())
                                    color: isToday || isSelected ? StyleTokens.textOnAccent : StyleTokens.textTertiary
                                    font.pixelSize: Math.round(10 * root.fontScale)
                                    font.family: root.textFontFamily
                                    font.weight: isToday || isSelected ? Font.Bold : Font.Medium
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedDate = dateObj
                    }
                }
            }
        }
    }

    // Bottom: Event List or Empty State occupying all available usable space
    Item {
        id: eventListContainer
        anchors.top: headerRow.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        clip: true

        // Empty state when no events on the selected day
        Item {
            anchors.fill: parent
            visible: !root.hasEvents

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    id: emptyIcon
                    text: "󰄬"
                    color: StyleTokens.success
                    font.pixelSize: Math.round(13 * root.fontScale)
                    font.family: root.iconFontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: emptyText
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.isSameDay(root.selectedDate, root.today) ? "No events today" : "No events"
                    color: StyleTokens.textSecondary
                    font.pixelSize: Math.round(12 * root.fontScale)
                    font.family: root.textFontFamily
                    font.weight: Font.Medium
                }
            }
        }

        // Scrollable Event List
        ListView {
            id: eventsListView
            anchors.fill: parent
            visible: root.hasEvents
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: root.dayEvents
            spacing: 4

            delegate: Item {
                id: eventDelegate
                width: eventsListView.width
                implicitHeight: Math.max(20, Math.round(22 * root.fontScale))
                height: implicitHeight

                HoverHandler {
                    id: eventRowHover
                }

                Rectangle {
                    id: accentBar
                    width: 3
                    height: Math.round(14 * root.fontScale)
                    radius: 1.5
                    color: (modelData && modelData.color) ? modelData.color : StyleTokens.accent
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: eventTimeText
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    text: root.formatEventPeriod(modelData)
                    visible: text.length > 0
                    color: StyleTokens.textSecondary
                    font.pixelSize: Math.round(11 * root.fontScale)
                    font.family: root.textFontFamily
                    font.weight: Font.Medium
                }

                WidgetTextView {
                    id: eventTitleText
                    anchors.left: accentBar.right
                    anchors.leftMargin: 6
                    anchors.right: eventTimeText.visible ? eventTimeText.left : parent.right
                    anchors.rightMargin: eventTimeText.visible ? 8 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    text: (modelData && modelData.title) ? modelData.title : ""
                    role: "body"
                    overflowMode: "marquee"
                    maximumLineCount: 1
                    colorOverride: StyleTokens.textPrimary
                    fontFamilyOverride: root.textFontFamily
                    fontSizeOverride: Math.round(12 * root.fontScale)
                    fontWeightOverride: Font.DemiBold
                    hoveredOverride: eventRowHover.hovered
                    widgetContext: root.widgetContext
                }
            }

            WheelHandler {
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    const dy = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y;
                    if (dy !== 0 && eventsListView.contentHeight > eventsListView.height) {
                        const step = dy > 0 ? -26 : 26;
                        eventsListView.contentY = Math.max(0, Math.min(eventsListView.contentHeight - eventsListView.height, eventsListView.contentY + step));
                        event.accepted = true;
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                id: vScroll
                active: eventsListView.moving || eventsListView.dragging
                policy: ScrollBar.AsNeeded
                width: 3
                anchors.right: eventsListView.right

                contentItem: Rectangle {
                    radius: 1.5
                    color: StyleTokens.track
                }
            }
        }
    }
}
