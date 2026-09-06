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

    Column {
        anchors.fill: parent
        spacing: 8

        // 7-day Horizontal Wheel / Strip (Boring Notch style)
        Item {
            width: parent.width
            height: 48

            Row {
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: 7

                    delegate: Item {
                        readonly property int offset: index - 3
                        readonly property var dateObj: root.getDateForOffset(offset)
                        readonly property bool isToday: root.isSameDay(dateObj, root.today)
                        readonly property bool isSelected: root.isSameDay(dateObj, root.selectedDate)

                        width: 22
                        height: 44

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.dayShortNames[dateObj.getDay()]
                                color: isSelected ? "white" : (isToday ? "#b56cff" : "#8e8e93")
                                font.pixelSize: 10
                                font.family: root.textFontFamily
                                font.weight: isToday || isSelected ? Font.Bold : Font.Normal
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 22
                                height: 22
                                radius: 11
                                color: isToday ? "#b56cff" : (isSelected ? "#3a3a3c" : "transparent")
                                border.width: isSelected && !isToday ? 1 : 0
                                border.color: "#8e8e93"

                                Text {
                                    anchors.centerIn: parent
                                    text: String(dateObj.getDate())
                                    color: isToday ? "white" : (isSelected ? "white" : "#c7c7cc")
                                    font.pixelSize: 11
                                    font.family: root.textFontFamily
                                    font.weight: isToday || isSelected ? Font.Bold : Font.Medium
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

        // Agenda / Schedule Card (Boring Notch style)
        Rectangle {
            width: parent.width
            height: parent.height - 48 - 8
            radius: 12
            color: "#1c1c1e"
            border.width: 1
            border.color: "#2c2c2e"

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                Row {
                    spacing: 6
                    anchors.left: parent.left
                    anchors.right: parent.right

                    Text {
                        text: "󰃭"
                        color: "#b56cff"
                        font.family: root.iconFontFamily
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.isSameDay(root.selectedDate, root.today)
                            ? "Today's Schedule"
                            : (root.dayShortNames[root.selectedDate.getDay()] + ", " + root.monthNames[root.selectedDate.getMonth()] + " " + root.selectedDate.getDate())
                        color: "white"
                        font.pixelSize: 11
                        font.family: root.textFontFamily
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item {
                    width: parent.width
                    height: parent.height - 18
                    anchors.horizontalCenter: parent.horizontalCenter

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "All Clear"
                            color: "#98989f"
                            font.pixelSize: 12
                            font.family: root.textFontFamily
                            font.weight: Font.Medium
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No upcoming events"
                            color: "#636366"
                            font.pixelSize: 10
                            font.family: root.textFontFamily
                        }
                    }
                }
            }
        }
    }
}
