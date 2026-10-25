import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets
import qs.Widgets
import qs.Services
import QtCore

PluginSettings {
    id: root
    pluginId: "screenCaptureToolbar"
    
    focus: true
    activeFocusOnTab: true

    property var monitorList: [{label: "Focused", value: "Focused"}]

    Timer {
        running: true
        interval: 500
        onTriggered: {
            var l = [{label: "Focused", value: "Focused"}];
            for (var i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name) {
                    var s = Quickshell.screens[i];
                    var desc = s.description || s.model || s.name;
                    l.push({label: desc, value: s.name});
                }
            }
            root.monitorList = l;
        }
    }

    property var micList: [{label: "Default", value: "default"}]
    property bool isTestingMic: false
    property bool isPlayingMic: false
    property bool isProcessingMic: false
    property int micTestCountdown: 0

    Process {
        command: ["bash", "-c", "gpu-screen-recorder --list-audio-devices 2>/dev/null | grep -v '\\.monitor' | grep -v 'output' | grep -v 'default_input'"]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                var line = data.trim();
                if (line !== "") {
                    var parts = line.split("|");
                    if (parts.length >= 2) {
                        var name = parts[0];
                        var label = parts[1];
                        if (typeof AudioService !== "undefined" && AudioService) {
                            var found = false;
                            if (AudioService.sources) {
                                for (var k = 0; k < AudioService.sources.length; k++) {
                                    if (AudioService.sources[k].name === name || AudioService.sources[k].name === name + ".monitor" || name.indexOf(AudioService.sources[k].name) !== -1) {
                                        if (AudioService.sources[k].description) {
                                            label = AudioService.sources[k].description;
                                            found = true;
                                        }
                                        break;
                                    }
                                }
                            }
                            if (!found && AudioService.sinks) {
                                for (var k = 0; k < AudioService.sinks.length; k++) {
                                    if (AudioService.sinks[k].name === name || AudioService.sinks[k].name + ".monitor" === name || name.indexOf(AudioService.sinks[k].name) !== -1) {
                                        if (AudioService.sinks[k].description) {
                                            label = AudioService.sinks[k].description;
                                            found = true;
                                        }
                                        break;
                                    }
                                }
                            }
                        }
                        var exists = false;
                        for (var i = 0; i < root.micList.length; i++) {
                            if (root.micList[i].value === name) exists = true;
                        }
                        if (!exists) {
                            var l = root.micList.slice();
                            l.push({label: label, value: name});
                            root.micList = l;
                        }
                    }
                }
            }
        }
    }

    Process {
        id: micTestProcess
        command: []
        running: false
        stdout: SplitParser {
            onRead: function(data) {
                var line = data.trim();
                if (line === "PLAYING") {
                    root.isProcessingMic = false;
                    root.isPlayingMic = true;
                } else if (line === "PROCESSING") {
                    root.isPlayingMic = false;
                    root.isProcessingMic = true;
                } else if (line === "RECORDING") {
                    root.micTestCountdown = 0;
                } else if (line.indexOf("COUNTDOWN") === 0) {
                    var parts = line.split(" ");
                    if (parts.length > 1) {
                        root.micTestCountdown = parseInt(parts[1]);
                    }
                }
            }
        }
        onExited: {
            root.isTestingMic = false;
            root.isPlayingMic = false;
            root.isProcessingMic = false;
            root.micTestCountdown = 0;
        }
    }

    property string defaultPath: ""

    Process {
        id: defaultPathDetector
        command: ["bash", "-c", "dir=$(xdg-user-dir PICTURES 2>/dev/null); if [ -n \"$dir\" ]; then echo \"${dir/#$HOME/~}/Screenshots\"; else echo \"~/Pictures/Screenshots\"; fi"]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                if (data.trim() !== "") {
                    root.defaultPath = data.trim();
                }
            }
        }
    }

    Process {
        id: launchProcess
        command: ["dms", "ipc", "call", "screenCaptureToolbar", "toggle"]
        running: false
    }

    readonly property real outerR: Theme.cornerRadius || 12
    readonly property real innerR: 4

    component SectionHeader: Row {
        property string title: ""
        property string iconName: ""

        spacing: Theme.spacingXS
        leftPadding: Theme.spacingM

        DankIcon {
            name: iconName
            size: 16
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: title
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    function loadValue(key, def) {
        var svc = (typeof PluginService !== "undefined" && PluginService) ? PluginService : root.pluginService;
        if (svc && svc.loadPluginData) {
            var val = svc.loadPluginData(root.pluginId, key, def);
            return (val !== undefined) ? val : def;
        }
        return def;
    }

    function saveValue(key, val) {
        var svc = (typeof PluginService !== "undefined" && PluginService) ? PluginService : root.pluginService;
        if (svc && svc.savePluginData) {
            svc.savePluginData(root.pluginId, key, val);
            if (svc.setGlobalVar) {
                svc.setGlobalVar(root.pluginId, key, val);
            }
        }
    }

    function loadAll() {
        function triggerLoad(item) {
            if (!item) return;
            if (item !== root && item !== mainSettingsCol && item.loadValue && typeof item.loadValue === "function") {
                item.loadValue();
            }
            if (item.children) {
                for (var i = 0; i < item.children.length; i++) {
                    triggerLoad(item.children[i]);
                }
            }
            if (item.data) {
                for (var j = 0; j < item.data.length; j++) {
                    if (item.data[j] !== item && (!item.children || item.children.indexOf(item.data[j]) === -1)) {
                        triggerLoad(item.data[j]);
                    }
                }
            }
        }
        triggerLoad(mainSettingsCol);
    }

    Component.onCompleted: Qt.callLater(loadAll)

    onPluginServiceChanged: {
        if (pluginService) {
            Qt.callLater(loadAll);
        }
    }

    Connections {
        target: (typeof PluginService !== "undefined" && PluginService) ? PluginService : root.pluginService
        ignoreUnknownSignals: true
        function onPluginDataChanged(pId) {
            if (pId === root.pluginId) {
                root.loadAll();
            }
        }
        function onGlobalVarChanged(pId, varName) {
            if (pId === root.pluginId) {
                root.loadAll();
            }
        }
    }

    Column {
        id: mainSettingsCol
        width: parent.width
        spacing: Theme.spacingL

        readonly property var pluginService: (typeof PluginService !== "undefined" && PluginService) ? PluginService : root.pluginService

        function loadValue(key, def) {
            return root.loadValue(key, def);
        }

        function saveValue(key, val) {
            root.saveValue(key, val);
        }

                // ====================================================================
        // SECTION 1: GENERAL SETTINGS
        // ====================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingXS
                leftPadding: Theme.spacingM
                DankIcon {
                    name: "tune"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "General Settings"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Column {
                width: parent.width
                spacing: 2

                // 1. Capture Delay (Segmented Pill) (First)
                Rectangle {
                    width: parent.width
                    height: genCol2.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: outerR; topRightRadius: outerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: genCol2
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "timer"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Capture Delay"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Delay in seconds before capturing (non-interactive modes only)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }

                        SegmentedSetting {
                            Layout.fillWidth: true
                            settingKey: "delaySeconds"
                            defaultValue: "0"
                            options: [
                                { title: "None", value: "0", icon: "timer_off" },
                                { title: "3s", value: "3", icon: "timer_3" },
                                { title: "5s", value: "5", icon: "timer_5" },
                                { title: "10s", value: "10", icon: "timer_10" }
                            ]
                        }
                    }
                }

                // 2. Show Pointer
                Rectangle {
                    width: parent.width
                    height: genRow3.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: genRow3
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: showPointerToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "mouse"
                                size: 18
                                color: showPointerToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Show Pointer"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Include mouse pointer in screenshots and video recordings"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: showPointerToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "showPointer"
                            readonly property alias value: showPointerToggle.checked
                            checked: true

                            function loadValue() {
                                var val = root.loadValue(settingKey, true);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

                // 3. Show Notification
                Rectangle {
                    width: parent.width
                    height: genRow4.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: genRow4
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: showNotifyToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "notifications"
                                size: 18
                                color: showNotifyToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Show Notification"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Show system notification after capture or recording finishes"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: showNotifyToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "showNotify"
                            readonly property alias value: showNotifyToggle.checked
                            checked: true

                            function loadValue() {
                                var val = root.loadValue(settingKey, true);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

                // 4. Copy Path on Capture (Last)
                Rectangle {
                    width: parent.width
                    height: genRow5.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: outerR; bottomRightRadius: outerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: genRow5
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: copyPathOnCaptureToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "content_copy"
                                size: 18
                                color: copyPathOnCaptureToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Copy Path on Capture"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Automatically copy the file path to clipboard after saving"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: copyPathOnCaptureToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "copyPathOnCapture"
                            readonly property alias value: copyPathOnCaptureToggle.checked
                            checked: true

                            function loadValue() {
                                var val = root.loadValue(settingKey, true);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }
            }
        }

        // ====================================================================
        // SECTION 2: SCREENSHOT SETTINGS
        // ====================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingXS
                leftPadding: Theme.spacingM
                DankIcon {
                    name: "screenshot_region"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "Screenshot Settings"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Column {
                width: parent.width
                spacing: 2

                // 1. Capture Mode (Segmented Pill - First) (First)
                Rectangle {
                    width: parent.width
                    height: genCol1.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: outerR; topRightRadius: outerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: genCol1
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "camera"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Default Capture Mode"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Choose default capture mode (Interactive, Focused, Monitor, Window, All, Scrolling)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }

                        SegmentedSetting {
                            Layout.fillWidth: true
                            columns: 3
                            settingKey: "captureMode"
                            defaultValue: "interactive"
                            options: [
                                { title: "Region", value: "interactive", icon: "crop" },
                                { title: "Screen", value: "full", icon: "fullscreen" },
                                { title: "Monitor", value: "monitor", icon: "desktop_windows" },
                                { title: "Window", value: "window", icon: "picture_in_picture" },
                                { title: "All", value: "all", icon: "grid_view" },
                                { title: "Scroll", value: "scroll", icon: "swap_vert" }
                            ]
                        }
                    }
                }

                // 2. Multi-Monitor Screenshots
                Rectangle {
                    width: parent.width
                    height: ssRow1.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: ssRow1
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: multiMonitorScreenshotToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "monitor_weight"
                                size: 18
                                color: multiMonitorScreenshotToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Multi-Monitor Screenshots"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Use slurp and grim for interactive screenshots across displays"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: multiMonitorScreenshotToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "multiMonitorScreenshot"
                            readonly property alias value: multiMonitorScreenshotToggle.checked
                            checked: false

                            function loadValue() {
                                var val = root.loadValue(settingKey, false);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

                // 3. Copy to Clipboard
                Rectangle {
                    width: parent.width
                    height: ssRow3.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: ssRow3
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: copyToClipboardToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "content_copy"
                                size: 18
                                color: copyToClipboardToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Copy to Clipboard"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Copy the resulting image to your clipboard"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: copyToClipboardToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "copyToClipboard"
                            readonly property alias value: copyToClipboardToggle.checked
                            checked: true

                            function loadValue() {
                                var val = root.loadValue(settingKey, true);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

                // 4. Save to Disk
                Rectangle {
                    width: parent.width
                    height: ssRow2.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: ssRow2
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: saveToDiskToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "save"
                                size: 18
                                color: saveToDiskToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Save to Disk"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Save screenshot to disk (disable to only save to clipboard)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: saveToDiskToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "saveToDisk"
                            readonly property alias value: saveToDiskToggle.checked
                            checked: true

                            function loadValue() {
                                var val = root.loadValue(settingKey, true);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

                // 5. Screenshot Editor
                Rectangle {
                    width: parent.width
                    height: ssRow8.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: ssRow8
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: stdoutToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "output"
                                size: 18
                                color: stdoutToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Screenshot Editor"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Master switch: Enable external editor integration"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: stdoutToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "stdout"
                            readonly property alias value: stdoutToggle.checked
                            checked: false

                            function loadValue() {
                                var val = root.loadValue(settingKey, false);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

                // 6. Editor Pipe Command
                Rectangle {
                    width: parent.width
                    height: ssCol11.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    opacity: stdoutToggle.value ? 1.0 : 0.4
                    enabled: stdoutToggle.value
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    ColumnLayout {
                        id: ssCol11
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "input"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Editor Pipe Command"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Command after ' | ' (e.g. swappy -f -)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { Layout.fillWidth: true; settingKey: "pipeCommand"; label: ""; description: ""; placeholder: "swappy -f -"; defaultValue: "" }
                    }
                }
                // 7. Enable Editor Shortcut
                Rectangle {
                    width: parent.width
                    height: ssRow9.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    opacity: stdoutToggle.value ? 1.0 : 0.4
                    enabled: stdoutToggle.value
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    RowLayout {
                        id: ssRow9
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: enableEditorShortcutToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "keyboard"
                                size: 18
                                color: enableEditorShortcutToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Enable Editor Shortcut"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Allow using the secondary shortcut to trigger the editor"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: enableEditorShortcutToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "enableEditorShortcut"
                            readonly property alias value: enableEditorShortcutToggle.checked
                            checked: true

                            function loadValue() {
                                var val = root.loadValue(settingKey, true);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

                // 8. Swap Shortcuts
                Rectangle {
                    width: parent.width
                    height: ssRow10.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    opacity: stdoutToggle.value ? 1.0 : 0.4
                    enabled: stdoutToggle.value
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    RowLayout {
                        id: ssRow10
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: swapCaptureKeysToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "swap_horiz"
                                size: 18
                                color: swapCaptureKeysToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Swap Shortcuts"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Space: Edit, Ctrl+Space: Capture"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: swapCaptureKeysToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "swapCaptureKeys"
                            readonly property alias value: swapCaptureKeysToggle.checked
                            checked: false

                            function loadValue() {
                                var val = root.loadValue(settingKey, false);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

                // 9. Scroll Interval
                Rectangle {
                    width: parent.width
                    height: ssCol6.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: ssCol6
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        SliderSettingV2 {
                            Layout.fillWidth: true; settingKey: "scrollInterval"
                            label: "Scroll Interval"; description: "Capture cadence in milliseconds for scrolling screenshot (30-1000ms, default: 45ms)"
                            defaultValue: "45"; minVal: 30; maxVal: 1000; isFloatBackend: false; showPercentage: false
                            iconName: "swap_vert"
                        }
                    }
                }

                // 10. Image Format (Segmented Pill)
                Rectangle {
                    width: parent.width
                    height: ssCol4.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: ssCol4
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "image"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Image Format"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Format to save the screenshot in"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }

                        SegmentedSetting {
                            id: imageFormatSetting
                            Layout.fillWidth: true
                            settingKey: "format"
                            defaultValue: "png"
                            options: [
                                { title: "PNG (Lossless)", value: "png", icon: "image" },
                                { title: "JPEG", value: "jpg", icon: "photo" },
                                { title: "PPM (Raw)", value: "ppm", icon: "raw_on" }
                            ]
                        }
                    }
                }

                // 11. JPEG Quality
                Rectangle {
                    width: parent.width
                    height: ssCol5.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    opacity: (imageFormatSetting.value === "jpg") ? 1.0 : 0.4
                    enabled: (imageFormatSetting.value === "jpg")
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    ColumnLayout {
                        id: ssCol5
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        SliderSettingV2 {
                            Layout.fillWidth: true; settingKey: "quality"
                            label: "JPEG Quality"; description: "Quality from 1-100% (only applies if format is JPEG)"
                            defaultValue: "90"; minVal: 1; maxVal: 100; isFloatBackend: false; showPercentage: true
                            iconName: "high_quality"
                        }
                    }
                }

                // 12. Screenshot Filename
                Rectangle {
                    width: parent.width
                    height: ssColFilename.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    opacity: saveToDiskToggle.value ? 1.0 : 0.4
                    enabled: saveToDiskToggle.value
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    ColumnLayout {
                        id: ssColFilename
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                Layout.alignment: Qt.AlignVCenter

                                DankIcon {
                                    name: "terminal"
                                    size: 18
                                    color: Theme.primary
                                    anchors.centerIn: parent
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Screenshot Filename"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Override the generated screenshot filename template. Extension is added if omitted."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { Layout.fillWidth: true; settingKey: "filename"; label: ""; description: ""; placeholder: "screenshot_2026-05-15_14-30-00.png"; defaultValue: "" }
                    }
                }
                // 13. Screenshot Custom Path (Last)
                Rectangle {
                    width: parent.width
                    height: ssCol7.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: outerR; bottomRightRadius: outerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    opacity: saveToDiskToggle.value ? 1.0 : 0.4
                    enabled: saveToDiskToggle.value
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    ColumnLayout {
                        id: ssCol7
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "folder"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Screenshot Custom Path"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Absolute path to save screenshots. Leave empty for default."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { Layout.fillWidth: true; settingKey: "customPath"; label: ""; description: ""; placeholder: root.defaultPath; defaultValue: "" }
                    }
                }
            }
        }

        // ====================================================================
        // SECTION 3: VIDEO SETTINGS
        // ====================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingXS
                leftPadding: Theme.spacingM
                DankIcon {
                    name: "videocam"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "Video Settings"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Column {
                width: parent.width
                spacing: 2

                // 1. Video Format (Segmented Pill - First) (First)
                Rectangle {
                    width: parent.width
                    height: vidCol1.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: outerR; topRightRadius: outerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: vidCol1
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "videocam"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Video Format"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Container format for recordings"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }

                        SegmentedSetting {
                            Layout.fillWidth: true
                            settingKey: "videoFormat"
                            defaultValue: "mkv"
                            options: [
                                { title: "MKV (Matroska)", value: "mkv", icon: "movie" },
                                { title: "MP4 (MPEG-4)", value: "mp4", icon: "movie_creation" },
                                { title: "FLV (Flash)", value: "flv", icon: "video_file" }
                            ]
                        }
                    }
                }

                // 2. Video FPS (Segmented Pill)
                Rectangle {
                    width: parent.width
                    height: vidCol5.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: vidCol5
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "speed"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Video FPS"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Frames per second for recording"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }

                        SegmentedSetting {
                            Layout.fillWidth: true
                            settingKey: "videoFPS"
                            defaultValue: "60"
                            options: [
                                { title: "24 FPS", value: "24", icon: "speed" },
                                { title: "30 FPS", value: "30", icon: "speed" },
                                { title: "60 FPS", value: "60", icon: "speed" }
                            ]
                        }
                    }
                }

                // 3. Video Quality (Segmented Pill)
                Rectangle {
                    width: parent.width
                    height: vidCol6.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: vidCol6
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "high_quality"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Video Quality"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Quality preset for video recording"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }

                        SegmentedSetting {
                            Layout.fillWidth: true
                            settingKey: "videoQuality"
                            defaultValue: "medium"
                            options: [
                                { title: "Med", value: "medium", icon: "hd" },
                                { title: "High", value: "high", icon: "high_quality" },
                                { title: "V.High", value: "very_high", icon: "4k" },
                                { title: "Ultra", value: "ultra", icon: "auto_awesome" }
                            ]
                        }
                    }
                }

                // 4. Target Monitor
                Rectangle {
                    width: parent.width
                    height: vidCol7.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: vidCol7
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "desktop_windows"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Target Monitor"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Monitor to record when in multi-monitor setup"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        SelectionSettingV2 {
                            Layout.fillWidth: true; settingKey: "videoMonitor"; label: ""; description: ""
                            options: root.monitorList; defaultValue: "Focused"
                        }
                    }
                }

                // 5. Record Audio
                Rectangle {
                    width: parent.width
                    height: vidRow2.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: vidRow2
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: recordAudioToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "volume_up"
                                size: 18
                                color: recordAudioToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Record Audio"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Include system audio in the recording"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: recordAudioToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "recordAudio"
                            readonly property alias value: recordAudioToggle.checked
                            checked: true

                            function loadValue() {
                                var val = root.loadValue(settingKey, true);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

                // 6. Record Microphone
                Rectangle {
                    width: parent.width
                    height: vidRow3.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: vidRow3
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: videoMicToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "mic"
                                size: 18
                                color: videoMicToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Record Microphone"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Include the default microphone input in the recording"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: videoMicToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "recordMic"
                            readonly property alias value: videoMicToggle.checked
                            checked: false

                            function loadValue() {
                                var val = root.loadValue(settingKey, false);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

                // 7. Microphone Device (Greyed out if mic disabled)
                Rectangle {
                    width: parent.width
                    height: vidCol4.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    opacity: videoMicToggle.value ? 1.0 : 0.4
                    enabled: videoMicToggle.value
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    ColumnLayout {
                        id: vidCol4
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "mic"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Microphone Device"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Microphone to record from"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        SelectionSettingV2 {
                            Layout.fillWidth: true; settingKey: "videoMic"; label: ""; description: ""
                            options: root.micList; defaultValue: "default"
                        }
                    }
                }

                // 8. Video Filename
                Rectangle {
                    width: parent.width
                    height: vidCol9.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: vidCol9
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "terminal"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Video Filename"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Override the generated recording filename. Extension is added if omitted."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { Layout.fillWidth: true; settingKey: "videoFilename"; label: ""; description: ""; placeholder: "recording_2026-05-15_14-30-00.mkv"; defaultValue: "" }
                    }
                }

                // 9. Video Custom Path
                Rectangle {
                    width: parent.width
                    height: vidCol8.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: vidCol8
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "folder"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Video Custom Path"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Absolute path to save recordings. Leave empty for ~/Videos."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { Layout.fillWidth: true; settingKey: "videoCustomPath"; label: ""; description: ""; placeholder: "~/Videos"; defaultValue: "" }
                    }
                }
                // 10. Show Advanced Settings
                Rectangle {
                    width: parent.width
                    height: vidRow10.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    readonly property bool isLast: !advancedVideoToggle.value
                    topLeftRadius: innerR; topRightRadius: innerR
                    bottomLeftRadius: isLast ? outerR : innerR
                    bottomRightRadius: isLast ? outerR : innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: vidRow10
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: advancedVideoToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "tune"
                                size: 18
                                color: advancedVideoToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Show Advanced Settings"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Enable advanced codec options for video recording"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: advancedVideoToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "showAdvancedSettings"
                            readonly property alias value: advancedVideoToggle.checked
                            checked: false

                            function loadValue() {
                                var val = root.loadValue(settingKey, false);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

                // 11. Video Codec (Advanced - Segmented Pill)
                Rectangle {
                    width: parent.width
                    height: advancedVideoToggle.value ? (vidAdvCol1.implicitHeight + Theme.spacingM * 2) : 0
                    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    clip: true
                    opacity: advancedVideoToggle.value ? 1.0 : 0.0
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: height > 0 || opacity > 0

                    ColumnLayout {
                        id: vidAdvCol1
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "settings_applications"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Video Codec"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Hardware video encoder for recording"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }

                        SegmentedSetting {
                            Layout.fillWidth: true
                            columns: 3
                            settingKey: "videoCodec"
                            defaultValue: "auto"
                            options: [
                                { title: "Auto", value: "auto", icon: "auto_awesome" },
                                { title: "AV1", value: "av1", icon: "video_settings" },
                                { title: "AV1 10Bit", value: "av1_10bit", icon: "hdr_on" },
                                { title: "AV1 HDR", value: "av1_hdr", icon: "hdr_auto" },
                                { title: "H.264", value: "h264", icon: "movie" }
                            ]
                        }
                    }
                }

                // 12. Audio Codec (Advanced - Segmented Pill - Last) (Last)
                Rectangle {
                    width: parent.width
                    height: advancedVideoToggle.value ? (vidAdvCol2.implicitHeight + Theme.spacingM * 2) : 0
                    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    clip: true
                    opacity: advancedVideoToggle.value ? 1.0 : 0.0
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: outerR; bottomRightRadius: outerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: height > 0 || opacity > 0

                    ColumnLayout {
                        id: vidAdvCol2
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "audio_file"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Audio Codec"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Audio encoder for recording"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }

                        SegmentedSetting {
                            Layout.fillWidth: true
                            settingKey: "audioCodec"
                            defaultValue: "aac"
                            options: [
                                { title: "Opus (Recommended)", value: "opus", icon: "graphic_eq" },
                                { title: "AAC", value: "aac", icon: "audiotrack" }
                            ]
                        }
                    }
                }
            }
        }

        // ====================================================================
        // SECTION 4: STANDALONE AUDIO RECORDER
        // ====================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingXS
                leftPadding: Theme.spacingM
                DankIcon {
                    name: "graphic_eq"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "Standalone Audio Recorder"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Column {
                width: parent.width
                spacing: 2

                // 1. Enable Audio Recorder (First)
                Rectangle {
                    width: parent.width
                    height: audRow1.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    readonly property bool isLast: !enableAudioToggle.value
                    topLeftRadius: outerR; topRightRadius: outerR
                    bottomLeftRadius: isLast ? outerR : innerR
                    bottomRightRadius: isLast ? outerR : innerR
                    Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: audRow1
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: enableAudioToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "graphic_eq"
                                size: 18
                                color: enableAudioToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Enable Audio Recorder"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Enable standalone audio recording feature in toolbar mode selection"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: enableAudioToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "enableAudioRecorder"
                            readonly property alias value: enableAudioToggle.checked
                            checked: false

                            function loadValue() {
                                var val = root.loadValue(settingKey, false);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

                // 2. Audio Source Mode (Segmented Pill)
                Rectangle {
                    width: parent.width
                    height: enableAudioToggle.value ? (audCol3.implicitHeight + Theme.spacingM * 2) : 0
                    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    clip: true
                    opacity: enableAudioToggle.value ? 1.0 : 0.0
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: height > 0 || opacity > 0

                    ColumnLayout {
                        id: audCol3
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "mic"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Audio Source Mode"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Select what to capture in standalone audio recordings"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }

                        SegmentedSetting {
                            id: audioSourceSetting
                            Layout.fillWidth: true
                            settingKey: "audioSource"
                            defaultValue: "mic"
                            options: [
                                { title: "Mic Only", value: "mic", icon: "mic" },
                                { title: "System Audio", value: "system", icon: "volume_up" },
                                { title: "Both", value: "both", icon: "graphic_eq" }
                            ]
                        }
                    }
                }

                // 3. Microphone Device
                Rectangle {
                    width: parent.width
                    height: enableAudioToggle.value ? (audCol4.implicitHeight + Theme.spacingM * 2) : 0
                    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    clip: true
                    opacity: enableAudioToggle.value ? ((audioSourceSetting.value === "system") ? 0.4 : 1.0) : 0.0
                    enabled: enableAudioToggle.value && (audioSourceSetting.value !== "system")
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: height > 0 || opacity > 0

                    ColumnLayout {
                        id: audCol4
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "mic"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Microphone Device"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Microphone to record from"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        SelectionSettingV2 {
                            Layout.fillWidth: true; settingKey: "audioMic"; label: ""; description: ""
                            options: root.micList; defaultValue: "default"
                        }
                    }
                }

                // 4. Audio Format (Segmented Pill)
                Rectangle {
                    width: parent.width
                    height: enableAudioToggle.value ? (audCol2.implicitHeight + Theme.spacingM * 2) : 0
                    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    clip: true
                    opacity: enableAudioToggle.value ? 1.0 : 0.0
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: height > 0 || opacity > 0

                    ColumnLayout {
                        id: audCol2
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "audio_file"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Audio Format"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Container format for audio recordings"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }

                        SegmentedSetting {
                            Layout.fillWidth: true
                            settingKey: "audioFormat"
                            defaultValue: "mp3"
                            options: [
                                { title: "MP3", value: "mp3", icon: "audio_file" },
                                { title: "Opus", value: "opus", icon: "graphic_eq" },
                                { title: "FLAC", value: "flac", icon: "album" },
                                { title: "WAV", value: "wav", icon: "multitrack_audio" },
                                { title: "M4A", value: "m4a", icon: "audiotrack" },
                                { title: "OGG", value: "ogg", icon: "music_note" }
                            ]
                        }
                    }
                }

                // 5. Audio Quality / Bitrate (Segmented Pill)
                Rectangle {
                    width: parent.width
                    height: enableAudioToggle.value ? (audCol7.implicitHeight + Theme.spacingM * 2) : 0
                    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    clip: true
                    opacity: enableAudioToggle.value ? 1.0 : 0.0
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: height > 0 || opacity > 0

                    ColumnLayout {
                        id: audCol7
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "tune"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Audio Quality / Bitrate"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Bitrate quality preset for standalone audio recordings"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }

                        SegmentedSetting {
                            Layout.fillWidth: true
                            settingKey: "audioBitrate"
                            defaultValue: "192k"
                            options: [
                                { title: "128k", value: "128k", icon: "speed" },
                                { title: "192k", value: "192k", icon: "speed" },
                                { title: "256k", value: "256k", icon: "speed" },
                                { title: "320k", value: "320k", icon: "speed" }
                            ]
                        }
                    }
                }

                // 6. Audio Filename
                Rectangle {
                    width: parent.width
                    height: enableAudioToggle.value ? (audCol6.implicitHeight + Theme.spacingM * 2) : 0
                    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    clip: true
                    opacity: enableAudioToggle.value ? 1.0 : 0.0
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: height > 0 || opacity > 0

                    ColumnLayout {
                        id: audCol6
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "terminal"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Audio Filename"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Override generated audio filename template. Extension is added if omitted."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { Layout.fillWidth: true; settingKey: "audioFilename"; label: ""; description: ""; placeholder: "audio_2026-05-15_14-30-00.mp3"; defaultValue: "" }
                    }
                }
                // 7. Audio Custom Path (Last)
                Rectangle {
                    width: parent.width
                    height: enableAudioToggle.value ? (audCol5.implicitHeight + Theme.spacingM * 2) : 0
                    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    clip: true
                    opacity: enableAudioToggle.value ? 1.0 : 0.0
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: outerR; bottomRightRadius: outerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: height > 0 || opacity > 0

                    ColumnLayout {
                        id: audCol5
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            Layout.alignment: Qt.AlignVCenter

                            DankIcon {
                                name: "folder"
                                size: 18
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Audio Custom Path"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Absolute path to save audio recordings. Leave empty for ~/Music."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { Layout.fillWidth: true; settingKey: "audioCustomPath"; label: ""; description: ""; placeholder: "~/Music"; defaultValue: "" }
                    }
                }
            }
        }

// ====================================================================
                // SECTION 5: TOOLBAR & UI SETTINGS (COSMETICS)
        // ====================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingXS
                leftPadding: Theme.spacingM
                DankIcon {
                    name: "dock_to_bottom"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "Toolbar & UI Settings"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Column {
                width: parent.width
                spacing: 2

                // 1. Show Recording Pill (First)
                Rectangle {
                    width: parent.width
                    height: tbRow1.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: outerR; topRightRadius: outerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: tbRow1
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: showRecPillToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "smart_button"
                                size: 18
                                color: showRecPillToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Show Recording Pill"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Show the floating recording status pill during active recordings"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: showRecPillToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "showRecPill"
                            readonly property alias value: showRecPillToggle.checked
                            checked: true

                            function loadValue() {
                                var val = root.loadValue(settingKey, true);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

                // 2. Recording Pill Opacity
                Rectangle {
                    width: parent.width
                    height: tbCol4.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    opacity: showRecPillToggle.value ? 1.0 : 0.4
                    enabled: showRecPillToggle.value
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    ColumnLayout {
                        id: tbCol4
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        SliderSettingV2 {
                            Layout.fillWidth: true; settingKey: "pillOpacity"
                            label: "Recording Pill Opacity"; description: "Adjust background transparency of the status pill (default: 92%)"
                            defaultValue: "0.92"; minVal: 0.10; maxVal: 1.00; isFloatBackend: true; showPercentage: true
                            iconName: "opacity"
                        }
                    }
                }
                // 3. Toolbar Background Opacity
                Rectangle {
                    width: parent.width
                    height: tbCol3.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: tbCol3
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        SliderSettingV2 {
                            Layout.fillWidth: true; settingKey: "toolbarOpacity"
                            label: "Toolbar Background Opacity"; description: "Adjust background transparency of the capture toolbar (default: 85%)"
                            defaultValue: "0.85"; minVal: 0.10; maxVal: 1.00; isFloatBackend: true; showPercentage: true
                            iconName: "opacity"
                        }
                    }
                }

                // 4. Enable Controller Support (Last)
                Rectangle {
                    width: parent.width
                    height: tbRow2.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: outerR; bottomRightRadius: outerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: tbRow2
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: enableControllerToggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 150 } }

                            DankIcon {
                                name: "stadia_controller"
                                size: 18
                                color: enableControllerToggle.checked ? Theme.primary : Theme.surfaceVariantText
                                anchors.centerIn: parent
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            StyledText { text: "Enable Controller Support (BETA)"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Allow gamepads to trigger and navigate the toolbar via IPC"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                        }

                        DankToggle {
                            id: enableControllerToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "enableController"
                            readonly property alias value: enableControllerToggle.checked
                            checked: false

                            function loadValue() {
                                var val = root.loadValue(settingKey, false);
                                checked = (val === true || val === "true");
                            }
                            Component.onCompleted: loadValue()

                            onToggled: isChecked => {
                                checked = isChecked;
                                root.saveValue(settingKey, isChecked);
                            }
                        }
                    }
                }

            }
        }

        // ---------------------------------------------------------------------
        // IPC COMMANDS & SHORTCUTS
        // ---------------------------------------------------------------------
        Column {
            width: parent.width
            spacing: Theme.spacingS

            SectionHeader {
                title: "IPC Commands & Shortcuts"
                iconName: "keyboard_command_key"
            }

            Rectangle {
                width: parent.width
                implicitHeight: ipcInnerCol.implicitHeight + Theme.spacingM * 2
                radius: root.outerR
                color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                border.width: 1
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                Column {
                    id: ipcInnerCol
                    width: parent.width - Theme.spacingM * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    spacing: Theme.spacingM

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: "Control and trigger the screen capture toolbar via IPC and keybinds"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }
                        }

                        Rectangle {
                            id: openToolbarBtn
                            Layout.preferredHeight: 34
                            Layout.preferredWidth: openToolbarRow.implicitWidth + 24
                            Layout.alignment: Qt.AlignVCenter
                            property bool isHovered: openToolbarMa.containsMouse

                            radius: isHovered ? (height / 2) : (Theme.cornerRadius || 12)
                            Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }

                            color: isHovered ? Theme.withAlpha(Theme.primary, 0.25) : Theme.withAlpha(Theme.primary, 0.15)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            border.width: 1
                            border.color: isHovered ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            scale: openToolbarMa.pressed ? 0.94 : (isHovered ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                            DankRipple {
                                id: openToolbarRip
                                anchors.fill: parent
                                cornerRadius: parent.radius
                                rippleColor: Theme.primary
                            }

                            RowLayout {
                                id: openToolbarRow
                                anchors.centerIn: parent
                                spacing: 6

                                DankIcon {
                                    name: "open_in_new"
                                    size: 16
                                    color: Theme.primary
                                }

                                StyledText {
                                    text: "Toggle Toolbar"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                    color: Theme.primary
                                }
                            }

                            MouseArea {
                                id: openToolbarMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: (m) => openToolbarRip.trigger(m.x, m.y)
                                onClicked: {
                                    launchProcess.running = true;
                                }
                            }
                        }
                    }

                    CopyBox {
                        label: "Toggle Toolbar Command"
                        text: "dms ipc call screenCaptureToolbar toggle"
                    }

                    CopyBox {
                        label: "Open Toolbar Command"
                        text: "dms ipc call screenCaptureToolbar open"
                    }

                    CopyBox {
                        label: "Close Toolbar Command"
                        text: "dms ipc call screenCaptureToolbar close"
                    }

                    StyledText {
                        width: parent.width
                        text: "To trigger the screen capture toolbar using Print Screen, add this spawn command to your Niri configuration binds:"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primary
                        font.italic: true
                        wrapMode: Text.WordWrap
                    }

                    CopyBox {
                        label: "Niri Bind Configuration"
                        text: "Print { spawn \"dms\" \"ipc\" \"call\" \"screenCaptureToolbar\" \"toggle\"; }"
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 5. REQUIRED PACKAGES
        // ---------------------------------------------------------------------
        Item {
            id: depsWrapper
            width: parent.width
            implicitHeight: depsCol.implicitHeight

            property bool expanded: false
            property var depStatus: ({
                "gpu-screen-recorder": true,
                "slurp": true,
                "grim": true,
                "wl-copy": true,
                "satty": true,
                "ffmpeg": true,
                "pw-record": true,
                "pactl": true,
                "jq": true,
                "notify-send": true,
                "python3": true,
                "wtype": true
            })
            property bool isChecking: true

            Process {
                id: depChecker
                command: [
                    "bash", "-c",
                    "python3 -c \"import json, shutil, sys\n" +
                    "cmds = [\n" +
                    "  ('gpu-screen-recorder', 'gpu-screen-recorder'),\n" +
                    "  ('slurp', 'slurp'),\n" +
                    "  ('grim', 'grim'),\n" +
                    "  ('wl-copy', 'wl-copy'),\n" +
                    "  ('satty', 'satty'),\n" +
                    "  ('ffmpeg', 'ffmpeg'),\n" +
                    "  ('pw-record', 'pw-record'),\n" +
                    "  ('pactl', 'pactl'),\n" +
                    "  ('jq', 'jq'),\n" +
                    "  ('notify-send', 'notify-send'),\n" +
                    "  ('python3', 'python3'),\n" +
                    "  ('wtype', 'wtype')\n" +
                    "]\n" +
                    "results = {k: bool(shutil.which(cmd)) for k, cmd in cmds}\n" +
                    "sys.stdout.write(json.dumps(results))\n\""
                ]
                stdout: StdioCollector {
                    onStreamFinished: {
                        depsWrapper.isChecking = false;
                        try {
                            if (text && text.trim() !== "") {
                                depsWrapper.depStatus = JSON.parse(text.trim());
                            }
                        } catch (e) {
                            console.warn("Failed to parse dependency status:", e);
                        }
                    }
                }
            }

            Component.onCompleted: {
                depChecker.running = true;
            }

            Column {
                id: depsCol
                width: parent.width
                spacing: 0

                Item {
                    id: depsHeaderRow
                    width: parent.width
                    height: 40

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: "extension"
                            size: 16
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Required packages")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    DankIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        name: "expand_more"
                        size: Theme.iconSize || 20
                        color: Theme.surfaceVariantText
                        rotation: depsWrapper.expanded ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            depsWrapper.expanded = !depsWrapper.expanded;
                            if (depsWrapper.expanded) {
                                depsWrapper.isChecking = true;
                                depChecker.running = true;
                            }
                        }
                    }
                }

                Item {
                    id: animHost
                    width: parent.width
                    clip: true
                    height: depsWrapper.expanded ? groupContent.implicitHeight : 0
                    opacity: depsWrapper.expanded ? 1.0 : 0.0
                    visible: height > 0 || depsWrapper.expanded

                    Behavior on height {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutQuad
                        }
                    }

                    SettingsGroup {
                        id: groupContent
                        width: parent.width

                        SettingsRow {
                            visible: depsWrapper.isChecking
                            iconName: "hourglass_top"
                            title: I18n.tr("Checking packages...")
                        }

                        Repeater {
                            model: [
                                {
                                    id: "gpu-screen-recorder",
                                    pkg: "gpu-screen-recorder",
                                    features: "Hardware-accelerated screen & window video recording",
                                    present: Boolean(depsWrapper.depStatus["gpu-screen-recorder"])
                                },
                                {
                                    id: "slurp",
                                    pkg: "slurp",
                                    features: "Interactive region selection on Wayland compositors",
                                    present: Boolean(depsWrapper.depStatus["slurp"])
                                },
                                {
                                    id: "grim",
                                    pkg: "grim",
                                    features: "Wayland image capture for region and multi-monitor screenshots",
                                    present: Boolean(depsWrapper.depStatus["grim"])
                                },
                                {
                                    id: "wl-copy",
                                    pkg: "wl-clipboard (wl-copy)",
                                    features: "Copying captured screenshots and file paths directly to clipboard",
                                    present: Boolean(depsWrapper.depStatus["wl-copy"])
                                },
                                {
                                    id: "satty",
                                    pkg: "satty",
                                    features: "Screenshot annotation and quick image editing integration",
                                    present: Boolean(depsWrapper.depStatus["satty"])
                                },
                                {
                                    id: "ffmpeg",
                                    pkg: "ffmpeg",
                                    features: "Encoding, processing, and container conversion for video captures",
                                    present: Boolean(depsWrapper.depStatus["ffmpeg"])
                                },
                                {
                                    id: "pw-record",
                                    pkg: "pipewire (pw-record)",
                                    features: "Dedicated audio recording and real-time microphone testing",
                                    present: Boolean(depsWrapper.depStatus["pw-record"])
                                },
                                {
                                    id: "pactl",
                                    pkg: "pulseaudio-utils (pactl)",
                                    features: "Querying audio devices and controlling mute state",
                                    present: Boolean(depsWrapper.depStatus["pactl"])
                                },
                                {
                                    id: "jq",
                                    pkg: "jq",
                                    features: "Querying active monitor geometries and window states from compositor IPC",
                                    present: Boolean(depsWrapper.depStatus["jq"])
                                },
                                {
                                    id: "notify-send",
                                    pkg: "libnotify (notify-send)",
                                    features: "Desktop notifications for completed captures and missing dependencies",
                                    present: Boolean(depsWrapper.depStatus["notify-send"])
                                },
                                {
                                    id: "python3",
                                    pkg: "python3",
                                    features: "Running gamepad/controller input listener service",
                                    present: Boolean(depsWrapper.depStatus["python3"])
                                },
                                {
                                    id: "wtype",
                                    pkg: "wtype",
                                    features: "Simulating Wayland keyboard events for gamepad controls",
                                    present: Boolean(depsWrapper.depStatus["wtype"])
                                }
                            ]

                            delegate: SettingsRow {
                                iconName: modelData.present ? "check_circle" : "error"
                                iconColor: modelData.present ? Theme.success : Theme.error
                                title: modelData.pkg
                                subtitle: I18n.tr("Used for: %1").arg(modelData.features)
                                trailingBadge: modelData.present ? I18n.tr("Installed") : I18n.tr("Missing")
                                trailingBadgeColor: modelData.present ? Theme.surfaceVariantText : Theme.error
                            }
                        }
                    }
                }
            }
        }
    }
}
