import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    required property var options
    property string defaultValue: ""
    property string value: defaultValue

    width: parent.width
    implicitHeight: layoutColumn.implicitHeight
    
    opacity: enabled ? 1 : 0.5
    Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }

    property bool isInitialized: false

    function loadValue() {
        const settings = findSettings();
        if (settings) {
            value = settings.loadValue(settingKey, defaultValue);
            isInitialized = true;
        } else if (typeof PluginService !== "undefined" && PluginService && PluginService.loadPluginData) {
            value = PluginService.loadPluginData("screenCaptureToolbar", settingKey, defaultValue);
            isInitialized = true;
        }
    }

    Component.onCompleted: Qt.callLater(loadValue)

    readonly property var optionLabels: {
        const labels = []
        for (let i = 0; i < options.length; i++) {
            labels.push(options[i].label || options[i])
        }
        return labels
    }

    readonly property var valueToLabel: {
        const map = {}
        for (let i = 0; i < options.length; i++) {
            const opt = options[i]
            if (typeof opt === 'object') map[opt.value] = opt.label
            else map[opt] = opt
        }
        return map
    }

    readonly property var labelToValue: {
        const map = {}
        for (let i = 0; i < options.length; i++) {
            const opt = options[i]
            if (typeof opt === 'object') map[opt.label] = opt.value
            else map[opt] = opt
        }
        return map
    }

    onValueChanged: {
        if (!isInitialized) return;
        const settings = findSettings();
        if (settings) {
            settings.saveValue(settingKey, value);
        } else if (typeof PluginService !== "undefined" && PluginService && PluginService.savePluginData) {
            PluginService.savePluginData("screenCaptureToolbar", settingKey, value);
            if (PluginService.setGlobalVar) PluginService.setGlobalVar("screenCaptureToolbar", settingKey, value);
        }
    }

    function findSettings() {
        let item = parent
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined) return item
            item = item.parent
        }
        return null
    }

    Column {
        id: layoutColumn
        anchors.fill: parent
        spacing: Theme.spacingXS

        StyledText {
            visible: root.label !== ""
            text: root.label
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }
        
        StyledText {
            visible: root.description !== ""
            text: root.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
        }

        DankDropdown {
            id: dropdown
            width: parent.width
            compactMode: true
            currentValue: root.valueToLabel[root.value] || root.value
            options: root.optionLabels
            onValueChanged: newValue => {
                root.value = root.labelToValue[newValue] || newValue
            }
        }
    }
}
