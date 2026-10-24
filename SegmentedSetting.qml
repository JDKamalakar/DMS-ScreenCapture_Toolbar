import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Common
import qs.Widgets

Item {
    id: root

    required property string settingKey
    property var options: []  // [{ title/label, value/val, icon }]
    property var defaultValue: ""
    property var value: defaultValue

    property int columns: 0  // 0 = auto (single row if <= 4, 2 rows if > 4), >0 = explicit columns
    readonly property int effectiveColumns: root.columns > 0 ? root.columns : (root.options.length > 4 ? Math.ceil(root.options.length / 2) : (root.options.length > 0 ? root.options.length : 1))
    readonly property int rowCount: Math.ceil((root.options.length || 1) / effectiveColumns)

    implicitHeight: rowCount > 1 ? (rowCount * 40 + (rowCount - 1) * 2) : 40
    width: parent.width

    signal changed(var newVal)

    property bool isInitialized: false

    function loadValue() {
        const settings = findSettings();
        if (settings) {
            root.value = settings.loadValue(settingKey, defaultValue);
            isInitialized = true;
        } else {
            const svc = (typeof PluginService !== "undefined" && PluginService) ? PluginService : null;
            if (svc && svc.loadPluginData) {
                root.value = svc.loadPluginData("screenCaptureToolbar", settingKey, defaultValue);
                isInitialized = true;
            }
        }
    }

    Component.onCompleted: Qt.callLater(loadValue)

    onValueChanged: {
        if (!isInitialized) return;
        const settings = findSettings();
        if (settings) {
            settings.saveValue(settingKey, root.value);
        } else {
            const svc = (typeof PluginService !== "undefined" && PluginService) ? PluginService : null;
            if (svc && svc.savePluginData) {
                svc.savePluginData("screenCaptureToolbar", settingKey, root.value);
                if (svc.setGlobalVar) svc.setGlobalVar("screenCaptureToolbar", settingKey, root.value);
            }
        }
    }

    function findSettings() {
        let item = parent;
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined) return item;
            item = item.parent;
        }
        return null;
    }

    GridLayout {
        anchors.fill: parent
        columns: root.effectiveColumns
        columnSpacing: 2
        rowSpacing: 2

        Repeater {
            model: root.options

            delegate: Item {
                id: segItem
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 40
                height: 40

                readonly property var optVal: modelData.value !== undefined ? modelData.value : (modelData.val !== undefined ? modelData.val : modelData)
                readonly property string optTitle: modelData.title !== undefined ? modelData.title : (modelData.label !== undefined ? modelData.label : String(modelData))
                readonly property string optIcon: modelData.icon || ""

                readonly property bool isSelected: String(root.value) === String(optVal)
                readonly property bool isHovered: segItemMa.containsMouse

                readonly property int itemRow: Math.floor(index / root.effectiveColumns)
                readonly property int itemCol: index % root.effectiveColumns

                Shape {
                    id: segItemBg
                    anchors.fill: parent

                    property real innerRadius: 4
                    property real outerRadius: Theme.cornerRadius || 12

                    property bool isTopLeft: (root.rowCount > 1) ? (itemRow === 0 && itemCol === 0) : (index === 0)
                    property bool isTopRight: (root.rowCount > 1) ? (itemRow === 0 && itemCol === root.effectiveColumns - 1) : (index === root.options.length - 1)
                    property bool isBottomLeft: (root.rowCount > 1) ? (itemRow === root.rowCount - 1 && itemCol === 0) : (index === 0)
                    property bool isBottomRight: (root.rowCount > 1) ? (itemRow === root.rowCount - 1 && itemCol === root.effectiveColumns - 1) : (index === root.options.length - 1)

                    property real tlr: (isSelected || isHovered) ? (height / 2) : (isTopLeft ? outerRadius : innerRadius)
                    property real blr: (isSelected || isHovered) ? (height / 2) : (isBottomLeft ? outerRadius : innerRadius)
                    property real trr: (isSelected || isHovered) ? (height / 2) : (isTopRight ? outerRadius : innerRadius)
                    property real brr: (isSelected || isHovered) ? (height / 2) : (isBottomRight ? outerRadius : innerRadius)

                    property real tlrAnim: tlr; Behavior on tlrAnim { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }
                    property real trrAnim: trr; Behavior on trrAnim { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }
                    property real blrAnim: blr; Behavior on blrAnim { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }
                    property real brrAnim: brr; Behavior on brrAnim { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }

                    property color paintColor: isSelected
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                            : (isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04))

                    property color paintBorder: isSelected
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5)
                            : (isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.12))

                    ShapePath {
                        fillColor: segItemBg.paintColor
                        strokeColor: segItemBg.paintBorder
                        strokeWidth: 1

                        startX: segItemBg.tlrAnim; startY: 0
                        PathLine { x: segItemBg.width - segItemBg.trrAnim; y: 0 }
                        PathArc { x: segItemBg.width; y: segItemBg.trrAnim; radiusX: segItemBg.trrAnim; radiusY: segItemBg.trrAnim; direction: PathArc.Clockwise }
                        PathLine { x: segItemBg.width; y: segItemBg.height - segItemBg.brrAnim }
                        PathArc { x: segItemBg.width - segItemBg.brrAnim; y: segItemBg.height; radiusX: segItemBg.brrAnim; radiusY: segItemBg.brrAnim; direction: PathArc.Clockwise }
                        PathLine { x: segItemBg.blrAnim; y: segItemBg.height }
                        PathArc { x: 0; y: segItemBg.height - segItemBg.blrAnim; radiusX: segItemBg.blrAnim; radiusY: segItemBg.blrAnim; direction: PathArc.Clockwise }
                        PathLine { x: 0; y: segItemBg.tlrAnim }
                        PathArc { x: segItemBg.tlrAnim; y: 0; radiusX: segItemBg.tlrAnim; radiusY: segItemBg.tlrAnim; direction: PathArc.Clockwise }
                    }
                }

                scale: segItemMa.pressed ? 0.98 : (isHovered ? 1.01 : 1.0)
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                DankRipple { id: segRip; anchors.fill: parent; cornerRadius: segItemBg.tlrAnim; rippleColor: Theme.primary }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        visible: segItem.optIcon !== ""
                        name: segItem.optIcon
                        size: 14
                        color: segItem.isSelected ? Theme.primary : Theme.surfaceVariantText
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: segItem.optTitle
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: segItem.isSelected ? Font.Bold : Font.Normal
                        color: segItem.isSelected ? Theme.primary : Theme.surfaceText
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    id: segItemMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: (m) => segRip.trigger(m.x, m.y)
                    onClicked: {
                        root.value = segItem.optVal;
                        root.changed(segItem.optVal);
                    }
                }
            }
        }
    }
}
