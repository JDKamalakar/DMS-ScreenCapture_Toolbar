import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property string defaultValue: "0.85"
    property string value: defaultValue
    
    // Slider & Formatting properties
    property real minVal: 0.10
    property real maxVal: 1.00
    property bool isFloatBackend: true  // true for 0.85 (opacity), false for 90 (quality)
    property bool showPercentage: true  // true to display % suffix
    property string iconName: "opacity"

    // Reset animation state
    property bool isResetting: false
    property real animatedPct: getDisplayPercentage()

    width: parent.width
    implicitHeight: layoutColumn.implicitHeight

    opacity: enabled ? 1 : 0.5
    Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }

    function loadValue() {
        const settings = findSettings();
        if (settings && settings.pluginService) {
            value = settings.loadValue(settingKey, defaultValue);
            slider.value = getDisplayPercentage();
        }
    }

    Component.onCompleted: Qt.callLater(loadValue)

    onValueChanged: {
        if (!isResetting) {
            slider.value = getDisplayPercentage();
            const settings = findSettings();
            if (settings) settings.saveValue(settingKey, value);
        }
    }

    onAnimatedPctChanged: {
        if (isResetting) {
            slider.value = Math.round(animatedPct);
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

    function getDisplayPercentage() {
        var num = parseFloat(root.value || root.defaultValue);
        if (isNaN(num)) num = parseFloat(root.defaultValue);
        if (isFloatBackend) {
            return Math.round(num * 100);
        } else {
            return Math.round(num);
        }
    }

    function getDefaultPercentage() {
        var num = parseFloat(root.defaultValue);
        if (isNaN(num)) num = 0;
        if (isFloatBackend) {
            return Math.round(num * 100);
        } else {
            return Math.round(num);
        }
    }

    function setFromPercentage(pct) {
        var minPct = isFloatBackend ? Math.round(minVal * 100) : minVal;
        var maxPct = isFloatBackend ? Math.round(maxVal * 100) : maxVal;
        var clamped = Math.max(minPct, Math.min(maxPct, pct));

        if (isFloatBackend) {
            root.value = (clamped / 100).toFixed(2);
        } else {
            root.value = Math.round(clamped).toString();
        }
    }

    // Synchronized Reset Animation: counts text up/down while moving slider to default
    function resetToDefault() {
        var startVal = getDisplayPercentage();
        var targetVal = getDefaultPercentage();
        
        if (startVal === targetVal) return;

        animatedPct = startVal;
        isResetting = true;
        
        resetCounterAnim.from = startVal;
        resetCounterAnim.to = targetVal;
        resetCounterAnim.restart();
    }

    NumberAnimation {
        id: resetCounterAnim
        target: root
        property: "animatedPct"
        duration: 350
        easing.type: Easing.OutQuad
        onStopped: {
            root.setFromPercentage(Math.round(root.animatedPct));
            slider.value = root.getDisplayPercentage();
            root.isResetting = false;
            const settings = root.findSettings();
            if (settings) settings.saveValue(root.settingKey, root.value);
        }
    }

    Column {
        id: layoutColumn
        anchors.fill: parent
        spacing: Theme.spacingS

        // Line 1: Header Row (Icon + Label & Description + Reset Button on top right)
        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                name: root.iconName
                size: 22
                anchors.verticalCenter: labelCol.verticalCenter
                opacity: 0.8
            }

            Column {
                id: labelCol
                width: parent.width - 22 - Theme.spacingM - (resetBtn.visible ? 36 : 0)
                spacing: Theme.spacingXS

                StyledText {
                    text: root.label
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    visible: root.label !== ""
                }

                StyledText {
                    text: root.description
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.WordWrap
                    visible: root.description !== ""
                }
            }

            // Reset Button on top right (same line as setting name & description header)
            Item {
                id: resetBtn
                width: 32
                height: 32
                anchors.verticalCenter: labelCol.verticalCenter
                visible: root.value !== root.defaultValue

                DankActionButton {
                    anchors.centerIn: parent
                    buttonSize: 32
                    iconName: "restart_alt"
                    iconSize: 18
                    iconColor: Theme.surfaceVariantText
                    onClicked: {
                        root.resetToDefault();
                    }
                }
            }
        }

        // Line 2: DankSlider + Small Input Box on right end of slider
        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankSlider {
                id: slider
                width: parent.width - smallBox.width - Theme.spacingM
                anchors.verticalCenter: smallBox.verticalCenter
                minimum: isFloatBackend ? Math.round(root.minVal * 100) : root.minVal
                maximum: isFloatBackend ? Math.round(root.maxVal * 100) : root.maxVal
                value: root.getDisplayPercentage()
                wheelEnabled: false
                thumbOutlineColor: Theme.surfaceContainerHigh

                onSliderValueChanged: newValue => {
                    if (!root.isResetting) {
                        root.setFromPercentage(newValue);
                    }
                }
            }

            // Small text input box with rounded corners similar to toggles (pill shape)
            Rectangle {
                id: smallBox
                width: 64
                height: 32
                color: Theme.surfaceContainerHigh
                radius: height / 2
                border.color: textInput.activeFocus ? Theme.primary : Theme.outline
                border.width: 1

                TextInput {
                    id: textInput
                    anchors.fill: parent
                    anchors.margins: 4
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    text: textInput.activeFocus 
                          ? displayValueRaw 
                          : ((root.isResetting ? Math.round(root.animatedPct) : root.getDisplayPercentage()) + (root.showPercentage ? "%" : ""))

                    property string displayValueRaw: (root.isResetting ? Math.round(root.animatedPct) : root.getDisplayPercentage()).toString()

                    onEditingFinished: {
                        if (root.isResetting) {
                            resetCounterAnim.stop();
                            root.isResetting = false;
                        }
                        var cleanText = text.replace("%", "").trim();
                        var parsed = parseFloat(cleanText);
                        if (!isNaN(parsed)) {
                            if (isFloatBackend && parsed <= 1.0 && parsed > 0) {
                                parsed = parsed * 100;
                            }
                            root.setFromPercentage(Math.round(parsed));
                        }
                        textInput.focus = false;
                    }

                    onAccepted: {
                        editingFinished();
                    }
                }
            }
        }
    }
}
