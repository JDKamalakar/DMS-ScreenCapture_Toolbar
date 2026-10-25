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
    property bool isInitialized: false
    property real animatedPct: getDisplayPercentage()

    width: parent.width
    implicitHeight: layoutColumn.implicitHeight

    opacity: enabled ? 1 : 0.5
    Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }

    function loadValue() {
        const settings = findSettings();
        if (settings) {
            value = String(settings.loadValue(settingKey, defaultValue));
            slider.value = getDisplayPercentage();
            isInitialized = true;
        } else {
            const svc = (typeof PluginService !== "undefined" && PluginService) ? PluginService : null;
            if (svc && svc.loadPluginData) {
                value = String(svc.loadPluginData("screenCaptureToolbar", settingKey, defaultValue));
                slider.value = getDisplayPercentage();
                isInitialized = true;
            }
        }
    }

    Component.onCompleted: Qt.callLater(loadValue)

    onValueChanged: {
        if (!isInitialized || isResetting) return;
        slider.value = getDisplayPercentage();
        const settings = findSettings();
        if (settings) {
            settings.saveValue(settingKey, value);
        } else {
            const svc = (typeof PluginService !== "undefined" && PluginService) ? PluginService : null;
            if (svc && svc.savePluginData) {
                svc.savePluginData("screenCaptureToolbar", settingKey, value);
                if (svc.setGlobalVar) {
                    svc.setGlobalVar("screenCaptureToolbar", settingKey, value);
                }
            }
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

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                anchors.verticalCenter: labelCol.verticalCenter

                DankIcon {
                    name: root.iconName
                    size: 18
                    color: Theme.primary
                    anchors.centerIn: parent
                }
            }

            Column {
                id: labelCol
                width: parent.width - 32 - Theme.spacingM - (resetBtn.visible ? 36 : 0)
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

            // Reset Button on top right with container matching NiriDisplaySettings
            Rectangle {
                id: resetBtn
                width: 32
                height: 32
                radius: Theme.cornerRadius
                anchors.verticalCenter: labelCol.verticalCenter
                color: resetBtnMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                border.color: resetBtnMa.containsMouse ? Theme.primary : Theme.outline
                border.width: 1
                opacity: root.value !== root.defaultValue ? (resetBtnMa.containsMouse ? 1.0 : 0.9) : 0.0
                visible: opacity > 0
                scale: resetBtnMa.containsMouse ? 1.1 : 1.0

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                DankRipple {
                    id: resetRip
                    anchors.fill: parent
                    cornerRadius: parent.radius
                    rippleColor: Theme.primary
                }

                DankIcon {
                    name: "restart_alt"
                    size: 18
                    anchors.centerIn: parent
                    color: resetBtnMa.containsMouse ? Theme.primary : Theme.surfaceVariantText
                    rotation: resetBtnMa.containsMouse ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: resetBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.resetToDefault();
                    }
                    onPressed: (m) => resetRip.trigger(m.x, m.y)
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
