import QtQuick
import IslandBackend

Item {
    id: root

    property string textFontFamily: "Sans Serif"
    property string iconFontFamily: "Sans Serif"
    property var selectedDate: new Date()
    property var today: new Date()

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
        anchors.fill: parent
        anchors.margins: 4
        spacing: 12

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
                    color: "white"
                    font.pixelSize: 13
                    font.family: root.textFontFamily
                    font.weight: Font.Bold
                }

                Text {
                    text: String(root.today.getFullYear())
                    color: "#8e8e93"
                    font.pixelSize: 11
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
                            color: isToday || isSelected ? "#142850" : "transparent"

                            Column {
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.dayShortNames[dateObj.getDay()]
                                    color: isToday || isSelected ? "#8ec5fc" : "#8e8e93"
                                    font.pixelSize: 9
                                    font.family: root.textFontFamily
                                    font.weight: isToday || isSelected ? Font.Bold : Font.Normal
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 17
                                    height: 17
                                    radius: 8.5
                                    color: isToday ? "#007aff" : (isSelected ? "#2a4d8c" : "transparent")

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.padZero(dateObj.getDate())
                                        color: isToday ? "white" : (isSelected ? "white" : "#c7c7cc")
                                        font.pixelSize: 10
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

        // Bottom: Event preview row with vertical magenta/purple accent bar (Exact Image #5)
        Item {
            width: parent.width
            height: 24

            Rectangle {
                id: magentaBar
                width: 3
                height: 14
                radius: 1.5
                color: "#af52de"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: eventTitleText
                anchors.left: magentaBar.right
                anchors.leftMargin: 6
                anchors.right: timeStatusText.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.isSameDay(root.selectedDate, root.today) ? "Today's Schedule" : (root.dayShortNames[root.selectedDate.getDay()] + " " + root.padZero(root.selectedDate.getDate()))
                color: "white"
                font.pixelSize: 12
                font.family: root.textFontFamily
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                id: timeStatusText
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                text: "All-day"
                color: "#8e8e93"
                font.pixelSize: 11
                font.family: root.textFontFamily
                font.weight: Font.Medium
            }
        }
    }
}
