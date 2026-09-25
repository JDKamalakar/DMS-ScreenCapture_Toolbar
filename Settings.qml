import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
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

    Column {
        id: mainSettingsCol
        width: parent.width
        spacing: Theme.spacingL

        function loadValue(key, def) {
            return PluginService.loadPluginData(root.pluginId, key, def);
        }

        function saveValue(key, val) {
            PluginService.savePluginData(root.pluginId, key, val);
            PluginService.setGlobalVar(root.pluginId, key, val);
        }

        function loadValueInternal() {
            function triggerLoad(item) {
                if (!item) return;
                if (item.loadValue) item.loadValue();
                if (item.children) {
                    for (var i = 0; i < item.children.length; i++) triggerLoad(item.children[i]);
                }
            }
            triggerLoad(mainSettingsCol);
        }

        Component.onCompleted: loadValueInternal()

        // ── About & Plugin Info Card ───────────────────────────
        StyledRect {
            width: parent.width
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.65)
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
            implicitHeight: aboutCol.implicitHeight + Theme.spacingM * 2

            ColumnLayout {
                id: aboutCol
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.primary, 0.12)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)

                        DankIcon {
                            anchors.centerIn: parent
                            name: "screenshot_region"
                            size: 26
                            color: Theme.primary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: "Screen Capture Toolbar"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: "Floating pill toolbar for fast screenshots & screen recordings"
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceVariantText
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "Quickly capture interactive regions, full screens, specific monitors, or scrolling screenshots and record system audio/video directly from a floating pill toolbar."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    id: openToolbarBtn
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: openToolbarRow.implicitWidth + 24
                    property bool isHovered: openToolbarMa.containsMouse

                    radius: isHovered ? (height / 2) : Theme.cornerRadius
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
                        onClicked: Proc.runCommand("toggle-toolbar", ["dms", "ipc", "call", "screenCaptureToolbar", "toggle"], function(){})
                    }
                }
            }
        }

        // ====================================================================
        // SECTION 1: SCREENSHOT SETTINGS
        // ====================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingM

            StyledText {
                text: "Screenshot Settings"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.primary
                padding: 0
                leftPadding: Theme.spacingM
            }

            Column {
                width: parent.width
                spacing: 2

                // 1. Multi-Monitor Screenshots (First)
                Rectangle {
                    width: parent.width
                    height: ssRow1.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: outerR; topRightRadius: outerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: ssRow1
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        DankIcon { name: "monitor_weight"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            Layout.fillWidth: true; settingKey: "multiMonitorScreenshot"
                            label: "Multi-Monitor Screenshots"; description: "Use slurp and grim for interactive screenshots across displays"
                            defaultValue: false
                        }
                    }
                }

                // 2. Save to Disk
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

                        DankIcon { name: "save"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            Layout.fillWidth: true; settingKey: "saveToDisk"
                            label: "Save to Disk"; description: "Save screenshot to disk (disable to only save to clipboard)"
                            defaultValue: true
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

                        DankIcon { name: "content_copy"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            Layout.fillWidth: true; settingKey: "copyToClipboard"
                            label: "Copy to Clipboard"; description: "Copy the resulting image to your clipboard"
                            defaultValue: true
                        }
                    }
                }

                // 4. Image Format (Segmented Pill)
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
                            DankIcon { name: "image"; size: 20; color: Theme.primary }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Image Format"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Format to save the screenshot in"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }

                        SegmentedSetting {
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

                // 5. JPEG Quality
                Rectangle {
                    width: parent.width
                    height: ssCol5.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

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

                // 6. Scroll Interval
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

                // 7. Screenshot Custom Path
                Rectangle {
                    width: parent.width
                    height: ssCol7.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: ssCol7
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            DankIcon { name: "folder"; size: 20; color: Theme.primary }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Screenshot Custom Path"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Absolute path to save screenshots. Leave empty for default."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { Layout.fillWidth: true; settingKey: "customPath"; label: ""; description: ""; placeholder: root.defaultPath; defaultValue: "" }
                    }
                }

                // 8. Screenshot Editor
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

                        DankIcon { name: "output"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            Layout.fillWidth: true; settingKey: "stdout"
                            label: "Screenshot Editor"; description: "Master switch: Enable external editor integration"
                            defaultValue: false
                        }
                    }
                }

                // 9. Enable Editor Shortcut
                Rectangle {
                    width: parent.width
                    height: ssRow9.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: ssRow9
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        DankIcon { name: "keyboard"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            Layout.fillWidth: true; settingKey: "enableEditorShortcut"
                            label: "Enable Editor Shortcut"; description: "Allow using the secondary shortcut to trigger the editor"
                            defaultValue: true
                        }
                    }
                }

                // 10. Swap Shortcuts
                Rectangle {
                    width: parent.width
                    height: ssRow10.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: ssRow10
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        DankIcon { name: "swap_horiz"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            Layout.fillWidth: true; settingKey: "swapCaptureKeys"
                            label: "Swap Shortcuts"; description: "Space: Edit, Ctrl+Space: Capture"
                            defaultValue: false
                        }
                    }
                }

                // 11. Editor Pipe Command (Last)
                Rectangle {
                    width: parent.width
                    height: ssCol11.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: outerR; bottomRightRadius: outerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: ssCol11
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            DankIcon { name: "input"; size: 20; color: Theme.primary }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Editor Pipe Command"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Command after ' | ' (e.g. swappy -f -)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { Layout.fillWidth: true; settingKey: "pipeCommand"; label: ""; description: ""; placeholder: "swappy -f -"; defaultValue: "" }
                    }
                }
            }
        }

        // ====================================================================
        // SECTION 2: VIDEO SETTINGS
        // ====================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingM

            StyledText {
                text: "Video Settings"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.primary
                padding: 0
                leftPadding: Theme.spacingM
            }

            Column {
                width: parent.width
                spacing: 2

                // 1. Video Format (Segmented Pill - First)
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
                            DankIcon { name: "videocam"; size: 20; color: Theme.primary }
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

                // 2. Record Audio
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

                        DankIcon { name: "volume_up"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            Layout.fillWidth: true; settingKey: "recordAudio"
                            label: "Record Audio"; description: "Include system audio in the recording"
                            defaultValue: true
                        }
                    }
                }

                // 3. Record Microphone
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

                        DankIcon { name: "mic"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            id: videoMicToggle
                            Layout.fillWidth: true; settingKey: "recordMic"
                            label: "Record Microphone"; description: "Include the default microphone input in the recording"
                            defaultValue: false
                        }
                    }
                }

                // 4. Microphone Device (Visible if mic enabled)
                Rectangle {
                    width: parent.width
                    height: vidCol4.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: videoMicToggle.value

                    ColumnLayout {
                        id: vidCol4
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            DankIcon { name: "mic"; size: 20; color: Theme.primary }
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

                // 5. Video FPS (Segmented Pill)
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
                            DankIcon { name: "speed"; size: 20; color: Theme.primary }
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

                // 6. Video Quality (Segmented Pill)
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
                            DankIcon { name: "high_quality"; size: 20; color: Theme.primary }
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

                // 7. Target Monitor
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
                            DankIcon { name: "desktop_windows"; size: 20; color: Theme.primary }
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

                // 8. Video Custom Path
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
                            DankIcon { name: "folder"; size: 20; color: Theme.primary }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Video Custom Path"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Absolute path to save recordings. Leave empty for ~/Videos."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { Layout.fillWidth: true; settingKey: "videoCustomPath"; label: ""; description: ""; placeholder: "~/Videos"; defaultValue: "" }
                    }
                }

                // 9. Video Filename
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
                            DankIcon { name: "terminal"; size: 20; color: Theme.primary }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Video Filename"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Override the generated recording filename. Extension is added if omitted."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { Layout.fillWidth: true; settingKey: "videoFilename"; label: ""; description: ""; placeholder: "recording_2026-05-15_14-30-00.mkv"; defaultValue: "" }
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

                        DankIcon { name: "tune"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            id: advancedVideoToggle
                            Layout.fillWidth: true; settingKey: "showAdvancedSettings"
                            label: "Show Advanced Settings"; description: "Enable advanced codec options for video recording"
                            defaultValue: false
                        }
                    }
                }

                // 11. Video Codec (Advanced - Segmented Pill)
                Rectangle {
                    width: parent.width
                    height: vidAdvCol1.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: advancedVideoToggle.value

                    ColumnLayout {
                        id: vidAdvCol1
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            DankIcon { name: "settings_applications"; size: 20; color: Theme.primary }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Video Codec"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Hardware video encoder for recording"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }

                        SegmentedSetting {
                            Layout.fillWidth: true
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

                // 12. Audio Codec (Advanced - Segmented Pill - Last)
                Rectangle {
                    width: parent.width
                    height: vidAdvCol2.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: outerR; bottomRightRadius: outerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: advancedVideoToggle.value

                    ColumnLayout {
                        id: vidAdvCol2
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            DankIcon { name: "audio_file"; size: 20; color: Theme.primary }
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
        // SECTION 3: STANDALONE AUDIO RECORDER SETTINGS
        // ====================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingM

            StyledText {
                text: "Standalone Audio Recorder"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.primary
                padding: 0
                leftPadding: Theme.spacingM
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
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: audRow1
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        DankIcon { name: "graphic_eq"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            id: enableAudioToggle
                            Layout.fillWidth: true; settingKey: "enableAudioRecorder"
                            label: "Enable Audio Recorder"; description: "Enable standalone audio recording feature in toolbar mode selection"
                            defaultValue: false
                        }
                    }
                }

                // 2. Audio Format (Segmented Pill)
                Rectangle {
                    width: parent.width
                    height: audCol2.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: enableAudioToggle.value

                    ColumnLayout {
                        id: audCol2
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            DankIcon { name: "audio_file"; size: 20; color: Theme.primary }
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

                // 3. Audio Source Mode (Segmented Pill)
                Rectangle {
                    width: parent.width
                    height: audCol3.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: enableAudioToggle.value

                    ColumnLayout {
                        id: audCol3
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            DankIcon { name: "mic"; size: 20; color: Theme.primary }
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

                // 4. Microphone Device
                Rectangle {
                    width: parent.width
                    height: audCol4.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: enableAudioToggle.value && (audioSourceSetting.value === "mic" || audioSourceSetting.value === "both" || !audioSourceSetting.value)

                    ColumnLayout {
                        id: audCol4
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            DankIcon { name: "mic"; size: 20; color: Theme.primary }
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

                // 5. Audio Custom Path
                Rectangle {
                    width: parent.width
                    height: audCol5.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: enableAudioToggle.value

                    ColumnLayout {
                        id: audCol5
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            DankIcon { name: "folder"; size: 20; color: Theme.primary }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Audio Custom Path"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Absolute path to save audio recordings. Leave empty for ~/Music."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { Layout.fillWidth: true; settingKey: "audioCustomPath"; label: ""; description: ""; placeholder: "~/Music"; defaultValue: "" }
                    }
                }

                // 6. Audio Filename
                Rectangle {
                    width: parent.width
                    height: audCol6.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: enableAudioToggle.value

                    ColumnLayout {
                        id: audCol6
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            DankIcon { name: "terminal"; size: 20; color: Theme.primary }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Audio Filename"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Override generated audio filename template. Extension is added if omitted."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { Layout.fillWidth: true; settingKey: "audioFilename"; label: ""; description: ""; placeholder: "audio_2026-05-15_14-30-00.mp3"; defaultValue: "" }
                    }
                }

                // 7. Audio Quality / Bitrate (Segmented Pill - Last)
                Rectangle {
                    width: parent.width
                    height: audCol7.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: outerR; bottomRightRadius: outerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                    visible: enableAudioToggle.value

                    ColumnLayout {
                        id: audCol7
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            DankIcon { name: "tune"; size: 20; color: Theme.primary }
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
            }
        }

        // ====================================================================
        // SECTION 4: GENERAL CAPTURE SETTINGS
        // ====================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingM

            StyledText {
                text: "General Capture Settings"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.primary
                padding: 0
                leftPadding: Theme.spacingM
            }

            Column {
                width: parent.width
                spacing: 2

                // 1. Capture Mode (Segmented Pill - First)
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
                            DankIcon { name: "camera"; size: 20; color: Theme.primary }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: "Default Capture Mode"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Choose default capture mode (Interactive, Focused, Monitor, Window, All, Scrolling)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                            }
                        }

                        SegmentedSetting {
                            Layout.fillWidth: true
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

                // 2. Capture Delay (Segmented Pill)
                Rectangle {
                    width: parent.width
                    height: genCol2.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: genCol2
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true; spacing: Theme.spacingM
                            DankIcon { name: "timer"; size: 20; color: Theme.primary }
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

                // 3. Show Pointer
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

                        DankIcon { name: "mouse"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            Layout.fillWidth: true; settingKey: "showPointer"
                            label: "Show Pointer"; description: "Include mouse pointer in screenshots and video recordings"
                            defaultValue: true
                        }
                    }
                }

                // 4. Show Notification
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

                        DankIcon { name: "notifications"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            Layout.fillWidth: true; settingKey: "showNotify"
                            label: "Show Notification"; description: "Show system notification after capture or recording finishes"
                            defaultValue: true
                        }
                    }
                }

                // 5. Copy Path on Capture (Last)
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

                        DankIcon { name: "content_copy"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            Layout.fillWidth: true; settingKey: "copyPathOnCapture"
                            label: "Copy Path on Capture"; description: "Automatically copy the file path to clipboard after saving"
                            defaultValue: true
                        }
                    }
                }
            }
        }

        // ====================================================================
        // SECTION 5: TOOLBAR & UI SETTINGS
        // ====================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingM

            StyledText {
                text: "Toolbar & UI Settings"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.primary
                padding: 0
                leftPadding: Theme.spacingM
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

                        DankIcon { name: "smart_button"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            Layout.fillWidth: true; settingKey: "showRecPill"
                            label: "Show Recording Pill"; description: "Show the floating recording status pill during active recordings"
                            defaultValue: true
                        }
                    }
                }

                // 2. Enable Controller Support
                Rectangle {
                    width: parent.width
                    height: tbRow2.implicitHeight + Theme.spacingM * 2
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    RowLayout {
                        id: tbRow2
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        DankIcon { name: "stadia_controller"; size: 20; color: Theme.primary }
                        ToggleSetting {
                            Layout.fillWidth: true; settingKey: "enableController"
                            label: "Enable Controller Support (BETA)"; description: "Allow gamepads to trigger and navigate the toolbar via IPC"
                            defaultValue: false
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

                // 4. Recording Pill Opacity (Last)
                Rectangle {
                    width: parent.width
                    height: tbCol4.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: outerR; bottomRightRadius: outerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

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
            }
        }

        // ====================================================================
        // SECTION 6: COMMANDS & SHORTCUTS
        // ====================================================================
        Column {
            width: parent.width
            spacing: Theme.spacingM

            StyledText {
                text: "Commands & Shortcuts"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.primary
                padding: 0
                leftPadding: Theme.spacingM
            }

            Column {
                width: parent.width
                spacing: 2

                // 1. CLI Commands (First)
                Rectangle {
                    width: parent.width
                    height: cmdCol1.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: outerR; topRightRadius: outerR; bottomLeftRadius: innerR; bottomRightRadius: innerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: cmdCol1
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        StyledText {
                            Layout.fillWidth: true
                            text: "You can open, close, or toggle the screen capture toolbar using the dms CLI:"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
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
                    }
                }

                // 2. Niri Keybind (Last)
                Rectangle {
                    width: parent.width
                    height: cmdCol2.implicitHeight + Theme.spacingM * 2
                    readonly property real outerR: Theme.cornerRadius
                    readonly property real innerR: 4
                    topLeftRadius: innerR; topRightRadius: innerR; bottomLeftRadius: outerR; bottomRightRadius: outerR
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

                    ColumnLayout {
                        id: cmdCol2
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.spacingM; anchors.rightMargin: Theme.spacingM
                        spacing: Theme.spacingM

                        StyledText {
                            Layout.fillWidth: true
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
        }
    }
}
