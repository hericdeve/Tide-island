import QtQuick
import IslandBackend
import "../../island"

Item {
    id: root

    property var widgetContext: null
    property int slotSpan: 1
    property bool isEditMode: false

    readonly property var userConfig: UserConfig

    anchors.fill: parent

    BoringCalendarTile {
        anchors.fill: parent
        textFontFamily: root.widgetContext ? root.widgetContext.textFontFamily : (userConfig ? userConfig.textFontFamily : "Sans Serif")
        iconFontFamily: root.widgetContext ? root.widgetContext.iconFontFamily : (userConfig ? userConfig.iconFontFamily : "Sans Serif")
    }
}
