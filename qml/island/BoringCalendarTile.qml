import QtQuick
import IslandBackend

Item {
    id: root

    property string textFontFamily: "Sans Serif"
    property string iconFontFamily: "Sans Serif"
    property var selectedDate: new Date()
    property var today: new Date()
    property int currentEventIndex: 0
    readonly property var userConfig: UserConfig
    readonly property real fontScale: userConfig ? Math.max(0.85, Math.min(1.3, userConfig.bodyFontSize / 16.0)) : 1.0

    readonly property var dayEvents: CalendarBackend ? CalendarBackend.eventsForDate(root.selectedDate) : []
    readonly property bool hasEvents: dayEvents && dayEvents.length > 0
    readonly property var currentEvent: hasEvents ? dayEvents[Math.min(currentEventIndex, dayEvents.length - 1)] : null

    onSelectedDateChanged: currentEventIndex = 0

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

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        spacing: Math.max(8, Math.round((parent.height - 48 - 24 - 8) / 2))

        // Top: Month/Year + Day Strip (Exact Image #5 layout)
        Row {
            width: parent.width
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
                                        color: isToday || isSelected ? StyleTokens.white : StyleTokens.textTertiary
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

        // Bottom: Event preview row with vertical accent bar or empty state
        Item {
            width: parent.width
            height: 24

            Rectangle {
                id: magentaBar
                width: 3
                height: 14
                radius: 1.5
                color: (root.currentEvent && root.currentEvent.color) ? root.currentEvent.color : StyleTokens.accent
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: root.hasEvents
            }

            Text {
                id: emptyIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "󰄬"
                color: StyleTokens.success
                font.pixelSize: Math.round(13 * root.fontScale)
                font.family: root.iconFontFamily
                visible: !root.hasEvents
            }

            Text {
                id: eventTitleText
                anchors.left: root.hasEvents ? magentaBar.right : emptyIcon.right
                anchors.leftMargin: 6
                anchors.right: timeStatusText.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (root.hasEvents && root.currentEvent)
                        return root.currentEvent.title;
                    return root.isSameDay(root.selectedDate, root.today) ? "No events today" : "No events";
                }
                color: root.hasEvents ? StyleTokens.textPrimary : StyleTokens.textSecondary
                font.pixelSize: Math.round(12 * root.fontScale)
                font.family: root.textFontFamily
                font.weight: root.hasEvents ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }

            Text {
                id: timeStatusText
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                text: {
                    if (root.hasEvents && root.currentEvent) {
                        let str = root.currentEvent.timeString || "All-day";
                        if (root.dayEvents.length > 1)
                            str += " (+" + (root.dayEvents.length - 1) + ")";
                        return str;
                    }
                    return "Enjoy your free time!";
                }
                color: root.hasEvents ? StyleTokens.textSecondary : StyleTokens.textTertiary
                font.pixelSize: Math.round(11 * root.fontScale)
                font.family: root.textFontFamily
                font.weight: Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.hasEvents && root.dayEvents.length > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.dayEvents.length > 1)
                        root.currentEventIndex = (root.currentEventIndex + 1) % root.dayEvents.length;
                }
            }
        }
    }
}
