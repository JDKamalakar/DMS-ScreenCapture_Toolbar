import QtQuick
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
        width: parent.width
        spacing: Theme.spacingM

        // ====================================================================
        // CONTAINER 1: SCREENSHOT SETTINGS ALL
        // ====================================================================
        Rectangle {
            width: parent.width
            height: ssGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            function loadValue() {
                function triggerLoad(item) {
                    if (!item) return;
                    if (item.loadValue) item.loadValue();
                    if (item.children) {
                        for (var i = 0; i < item.children.length; i++) triggerLoad(item.children[i]);
                    }
                }
                triggerLoad(ssGroup);
            }

            Column {
                id: ssGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                // 1. Multi-Monitor Screenshots
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "monitor_weight"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM; settingKey: "multiMonitorScreenshot"
                        label: "Multi-Monitor Screenshots"; description: "Use slurp and grim for interactive screenshots across displays"
                        defaultValue: false
                    }
                }

                // 2. Save to Disk
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "save"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM; settingKey: "saveToDisk"
                        label: "Save to Disk"; description: "Save screenshot to disk (disable to only save to clipboard)"
                        defaultValue: true
                    }
                }

                // 3. Copy to Clipboard
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "content_copy"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM; settingKey: "copyToClipboard"
                        label: "Copy to Clipboard"; description: "Copy the resulting image to your clipboard"
                        defaultValue: true
                    }
                }

                // 4. Image Format
                Column {
                    width: parent.width; spacing: Theme.spacingXS
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        DankIcon { name: "image"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                            StyledText { text: "Image Format"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Format to save the screenshot in"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }
                    SelectionSettingV2 {
                        width: parent.width; settingKey: "format"; label: ""; description: ""
                        options: [
                            {label: "PNG (Lossless)", value: "png"},
                            {label: "JPEG", value: "jpg"},
                            {label: "PPM (Raw)", value: "ppm"}
                        ]
                        defaultValue: "png"
                    }
                }

                // 5. JPEG Quality
                SliderSettingV2 {
                    width: parent.width
                    settingKey: "quality"
                    label: "JPEG Quality"
                    description: "Quality from 1-100% (only applies if format is JPEG)"
                    defaultValue: "90"
                    minVal: 1
                    maxVal: 100
                    isFloatBackend: false
                    showPercentage: true
                    iconName: "high_quality"
                }

                // 6. Screenshot Custom Path
                Column {
                    width: parent.width; spacing: Theme.spacingXS
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        DankIcon { name: "folder"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                            StyledText { text: "Screenshot Custom Path"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Absolute path to save screenshots. Leave empty for default."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }
                    StringSetting { width: parent.width; settingKey: "customPath"; label: ""; description: ""; placeholder: root.defaultPath; defaultValue: "" }
                }

                // 7. Screenshot Editor
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "output"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM; settingKey: "stdout"
                        label: "Screenshot Editor"; description: "Master switch: Enable external editor integration"
                        defaultValue: false
                    }
                }

                // 8. Enable Editor Shortcut
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "keyboard"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM; settingKey: "enableEditorShortcut"
                        label: "Enable Editor Shortcut"; description: "Allow using the secondary shortcut to trigger the editor"
                        defaultValue: true
                    }
                }

                // 9. Swap Shortcuts
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "swap_horiz"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM; settingKey: "swapCaptureKeys"
                        label: "Swap Shortcuts"; description: "Space: Edit, Ctrl+Space: Capture"
                        defaultValue: false
                    }
                }

                // 10. Editor Pipe Command
                Column {
                    width: parent.width; spacing: Theme.spacingXS
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        DankIcon { name: "input"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                            StyledText { text: "Editor Pipe Command"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Command after ' | ' (e.g. swappy -f -)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }
                    StringSetting { width: parent.width; settingKey: "pipeCommand"; label: ""; description: ""; placeholder: "swappy -f -"; defaultValue: "" }
                }
            }
        }

        // ====================================================================
        // CONTAINER 2: VIDEO SETTINGS ALL
        // ====================================================================
        Rectangle {
            id: videoCard
            width: parent.width
            height: videoCol.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8
            clip: true

            Behavior on height {
                NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
            }

            function loadValue() {
                function triggerLoad(item) {
                    if (!item) return;
                    if (item.loadValue) item.loadValue();
                    if (item.children) {
                        for (var i = 0; i < item.children.length; i++) triggerLoad(item.children[i]);
                    }
                }
                triggerLoad(videoCol);
            }

            Column {
                id: videoCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                // 1. Video Format
                Column {
                    width: parent.width; spacing: Theme.spacingXS
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        DankIcon { name: "videocam"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                            StyledText { text: "Video Format"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Container format for recordings"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }
                    SelectionSettingV2 {
                        width: parent.width; settingKey: "videoFormat"; label: ""; description: ""
                        options: [
                            {label: "MKV (Matroska)", value: "mkv"},
                            {label: "MP4 (MPEG-4)", value: "mp4"},
                            {label: "FLV (Flash)", value: "flv"}
                        ]
                        defaultValue: "mkv"
                    }
                }

                // 2. Record Audio
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "volume_up"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM; settingKey: "recordAudio"
                        label: "Record Audio"; description: "Include system audio in the recording"
                        defaultValue: true
                    }
                }

                // 3. Record Microphone
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "mic"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        id: videoMicToggle
                        width: parent.width - 22 - Theme.spacingM; settingKey: "recordMic"
                        label: "Record Microphone"; description: "Include the default microphone input in the recording"
                        defaultValue: false
                    }
                }

                // 4. Microphone Device
                Column {
                    width: parent.width; spacing: Theme.spacingXS
                    visible: videoMicToggle.value
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        DankIcon { name: "mic"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                            StyledText { text: "Microphone Device"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Microphone to record from"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }
                    SelectionSettingV2 {
                        width: parent.width; settingKey: "videoMic"; label: ""; description: ""
                        options: root.micList; defaultValue: "default"
                    }
                }

                // 5. Video FPS
                Column {
                    width: parent.width; spacing: Theme.spacingXS
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        DankIcon { name: "speed"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                            StyledText { text: "Video FPS"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Frames per second for recording"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }
                    SelectionSettingV2 {
                        width: parent.width; settingKey: "videoFPS"; label: ""; description: ""
                        options: [
                            {label: "24 FPS", value: "24"},
                            {label: "30 FPS", value: "30"},
                            {label: "60 FPS", value: "60"}
                        ]
                        defaultValue: "60"
                    }
                }

                // 6. Video Quality
                Column {
                    width: parent.width; spacing: Theme.spacingXS
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        DankIcon { name: "high_quality"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                            StyledText { text: "Video Quality"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Quality preset for video recording"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }
                    SelectionSettingV2 {
                        width: parent.width; settingKey: "videoQuality"; label: ""; description: ""
                        options: [
                            {label: "Medium", value: "medium"},
                            {label: "High", value: "high"},
                            {label: "Very High", value: "very_high"},
                            {label: "Ultra", value: "ultra"}
                        ]
                        defaultValue: "medium"
                    }
                }

                // 7. Target Monitor
                Column {
                    width: parent.width; spacing: Theme.spacingXS
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        DankIcon { name: "desktop_windows"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                            StyledText { text: "Target Monitor"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Monitor to record when in multi-monitor setup"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }
                    SelectionSettingV2 {
                        width: parent.width; settingKey: "videoMonitor"; label: ""; description: ""
                        options: root.monitorList; defaultValue: "Focused"
                    }
                }

                // 8. Video Custom Path
                Column {
                    width: parent.width; spacing: Theme.spacingXS
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        DankIcon { name: "folder"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                            StyledText { text: "Video Custom Path"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Absolute path to save recordings. Leave empty for ~/Videos."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }
                    StringSetting { width: parent.width; settingKey: "videoCustomPath"; label: ""; description: ""; placeholder: "~/Videos"; defaultValue: "" }
                }

                // 9. Video Filename
                Column {
                    width: parent.width; spacing: Theme.spacingXS
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        DankIcon { name: "terminal"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                            StyledText { text: "Video Filename"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Override the generated recording filename. Extension is added if omitted."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }
                    StringSetting { width: parent.width; settingKey: "videoFilename"; label: ""; description: ""; placeholder: "recording_2026-05-15_14-30-00.mkv"; defaultValue: "" }
                }

                // 10. Show Advanced Settings (LAST item in Video Settings)
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "tune"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        id: advancedVideoToggle
                        width: parent.width - 22 - Theme.spacingM; settingKey: "showAdvancedSettings"
                        label: "Show Advanced Settings"; description: "Enable advanced codec options for video recording"
                        defaultValue: false
                    }
                }

                // 11. Animated Advanced Video Settings Sub-Container
                Column {
                    id: videoAdvancedSubContent
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: opacity > 0
                    opacity: advancedVideoToggle.value ? 1.0 : 0.0
                    transform: Translate {
                        y: advancedVideoToggle.value ? 0 : -10
                        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                    }

                    // Video Codec
                    Column {
                        width: parent.width; spacing: Theme.spacingXS
                        Row {
                            width: parent.width; spacing: Theme.spacingM
                            DankIcon { name: "settings_applications"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                            Column {
                                width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                                StyledText { text: "Video Codec"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Hardware video encoder for recording"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                            }
                        }
                        SelectionSettingV2 {
                            width: parent.width; settingKey: "videoCodec"; label: ""; description: ""
                            options: [
                                {label: "Auto (Recommended)", value: "auto"},
                                {label: "AV1", value: "av1"},
                                {label: "AV1 (10 Bit)", value: "av1_10bit"},
                                {label: "AV1 (HDR)", value: "av1_hdr"},
                                {label: "H.264 SE (Not Recommended)", value: "h264"}
                            ]
                            defaultValue: "auto"
                        }
                    }

                    // Audio Codec
                    Column {
                        width: parent.width; spacing: Theme.spacingXS
                        Row {
                            width: parent.width; spacing: Theme.spacingM
                            DankIcon { name: "audio_file"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                            Column {
                                width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                                StyledText { text: "Audio Codec"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Audio encoder for recording"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                            }
                        }
                        SelectionSettingV2 {
                            width: parent.width; settingKey: "audioCodec"; label: ""; description: ""
                            options: [
                                {label: "Opus (Recommended)", value: "opus"},
                                {label: "AAC", value: "aac"}
                            ]
                            defaultValue: "aac"
                        }
                    }
                }
            }
        }

        // ====================================================================
        // CONTAINER 3: AUDIO SETTINGS ALL
        // ====================================================================
        Rectangle {
            id: audioCard
            width: parent.width
            height: audioCol.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8
            clip: true

            Behavior on height {
                NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
            }

            function loadValue() {
                function triggerLoad(item) {
                    if (!item) return;
                    if (item.loadValue) item.loadValue();
                    if (item.children) {
                        for (var i = 0; i < item.children.length; i++) triggerLoad(item.children[i]);
                    }
                }
                triggerLoad(audioCol);
            }

            Column {
                id: audioCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "graphic_eq"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        id: enableAudioToggle
                        width: parent.width - 22 - Theme.spacingM; settingKey: "enableAudioRecorder"
                        label: "Enable Audio Recorder"; description: "Enable standalone audio recording feature in toolbar mode selection"
                        defaultValue: false
                    }
                }

                Column {
                    id: audioSubContent
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: opacity > 0
                    opacity: enableAudioToggle.value ? 1.0 : 0.0
                    transform: Translate {
                        y: enableAudioToggle.value ? 0 : -10
                        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                    }

                    // 1. Audio Format
                    Column {
                        width: parent.width; spacing: Theme.spacingXS
                        Row {
                            width: parent.width; spacing: Theme.spacingM
                            DankIcon { name: "audio_file"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                            Column {
                                width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                                StyledText { text: "Audio Format"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Container format for audio recordings (mp3, opus, flac, wav, m4a, ogg)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                            }
                        }
                        SelectionSettingV2 {
                            width: parent.width; settingKey: "audioFormat"; label: ""; description: ""
                            options: [
                                {label: "MP3 (MPEG Layer III)", value: "mp3"},
                                {label: "Opus (Ogg Opus)", value: "opus"},
                                {label: "FLAC (Lossless)", value: "flac"},
                                {label: "WAV (Uncompressed)", value: "wav"},
                                {label: "AAC (M4A)", value: "m4a"},
                                {label: "OGG (Vorbis)", value: "ogg"}
                            ]
                            defaultValue: "mp3"
                        }
                    }

                    // 2. Audio Source Mode
                    Column {
                        width: parent.width; spacing: Theme.spacingXS
                        Row {
                            width: parent.width; spacing: Theme.spacingM
                            DankIcon { name: "mic"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                            Column {
                                width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                                StyledText { text: "Audio Source Mode"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Select what to capture in standalone audio recordings"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                            }
                        }
                        SelectionSettingV2 {
                            id: audioSourceSetting
                            width: parent.width; settingKey: "audioSource"; label: ""; description: ""
                            options: [
                                {label: "Microphone Only", value: "mic"},
                                {label: "System Audio Only", value: "system"},
                                {label: "Microphone + System Audio", value: "both"}
                            ]
                            defaultValue: "mic"
                        }
                    }

                    // 3. Microphone Device
                    Column {
                        width: parent.width; spacing: Theme.spacingXS
                        visible: audioSourceSetting.value === "mic" || audioSourceSetting.value === "both" || !audioSourceSetting.value
                        Row {
                            width: parent.width; spacing: Theme.spacingM
                            DankIcon { name: "mic"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                            Column {
                                width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                                StyledText { text: "Microphone Device"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Microphone to record from"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                            }
                        }
                        SelectionSettingV2 {
                            width: parent.width; settingKey: "videoMic"; label: ""; description: ""
                            options: root.micList; defaultValue: "default"
                        }
                    }

                    // 4. Audio Custom Path
                    Column {
                        width: parent.width; spacing: Theme.spacingXS
                        Row {
                            width: parent.width; spacing: Theme.spacingM
                            DankIcon { name: "folder"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                            Column {
                                width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                                StyledText { text: "Audio Custom Path"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Absolute path to save audio recordings. Leave empty for ~/Music."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { width: parent.width; settingKey: "audioCustomPath"; label: ""; description: ""; placeholder: "~/Music"; defaultValue: "" }
                    }

                    // 5. Audio Filename
                    Column {
                        width: parent.width; spacing: Theme.spacingXS
                        Row {
                            width: parent.width; spacing: Theme.spacingM
                            DankIcon { name: "terminal"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                            Column {
                                width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                                StyledText { text: "Audio Filename"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Override generated audio filename template. Extension is added if omitted."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                            }
                        }
                        StringSetting { width: parent.width; settingKey: "audioFilename"; label: ""; description: ""; placeholder: "audio_2026-05-15_14-30-00.mp3"; defaultValue: "" }
                    }

                    // 6. Audio Quality / Bitrate
                    Column {
                        width: parent.width; spacing: Theme.spacingXS
                        Row {
                            width: parent.width; spacing: Theme.spacingM
                            DankIcon { name: "tune"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                            Column {
                                width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                                StyledText { text: "Audio Quality / Bitrate"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Bitrate quality preset for standalone audio recordings"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                            }
                        }
                        SelectionSettingV2 {
                            width: parent.width; settingKey: "audioBitrate"; label: ""; description: ""
                            options: [
                                {label: "Standard (128 kbps)", value: "128k"},
                                {label: "High (192 kbps)", value: "192k"},
                                {label: "Very High (256 kbps)", value: "256k"},
                                {label: "Maximum (320 kbps)", value: "320k"}
                            ]
                            defaultValue: "192k"
                        }
                    }
                }
            }
        }

        // ====================================================================
        // CONTAINER 4: GENERAL SETTINGS
        // ====================================================================
        Rectangle {
            width: parent.width
            height: generalGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            function loadValue() {
                function triggerLoad(item) {
                    if (!item) return;
                    if (item.loadValue) item.loadValue();
                    if (item.children) {
                        for (var i = 0; i < item.children.length; i++) triggerLoad(item.children[i]);
                    }
                }
                triggerLoad(generalGroup);
            }

            Column {
                id: generalGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                // 1. Capture Mode (Moved from Screenshot Settings)
                Column {
                    width: parent.width; spacing: Theme.spacingXS
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        DankIcon { name: "camera"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                            StyledText { text: "Capture Mode"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Choose default capture mode (Interactive, Fullscreen, Monitor, Window, All)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }
                    SelectionSettingV2 {
                        width: parent.width; settingKey: "captureMode"; label: ""; description: ""
                        options: [
                            {label: "Interactive (Region)", value: "interactive"},
                            {label: "Focused Screen", value: "full"},
                            {label: "Specific Monitor", value: "monitor"},
                            {label: "Window", value: "window"},
                            {label: "All Screens", value: "all"}
                        ]
                        defaultValue: "interactive"
                    }
                }

                // 2. Capture Delay (Moved from Screenshot Settings)
                Column {
                    width: parent.width; spacing: Theme.spacingXS
                    Row {
                        width: parent.width; spacing: Theme.spacingM
                        DankIcon { name: "timer"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM; spacing: Theme.spacingXS
                            StyledText { text: "Capture Delay"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Delay in seconds before capturing (non-interactive modes only)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }
                    SelectionSettingV2 {
                        width: parent.width; settingKey: "delaySeconds"; label: ""; description: ""
                        options: [
                            {label: "No Delay", value: "0"},
                            {label: "3 Seconds", value: "3"},
                            {label: "5 Seconds", value: "5"},
                            {label: "10 Seconds", value: "10"}
                        ]
                        defaultValue: "0"
                    }
                }

                // 3. Show Pointer
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "mouse"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM; settingKey: "showPointer"
                        label: "Show Pointer"; description: "Include mouse pointer in screenshots and video recordings"
                        defaultValue: true
                    }
                }

                // 4. Show Notification
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "notifications"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM; settingKey: "showNotify"
                        label: "Show Notification"; description: "Show system notification after capture or recording finishes"
                        defaultValue: true
                    }
                }

                // 5. Copy Path on Capture
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "content_copy"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM; settingKey: "copyPathOnCapture"
                        label: "Copy Path on Capture"; description: "Automatically copy the file path to clipboard after saving"
                        defaultValue: true
                    }
                }

                // 6. Show Recording Pill
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "pill"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM; settingKey: "showRecPill"
                        label: "Show Recording Pill"; description: "Show the floating recording status pill during active recordings"
                        defaultValue: true
                    }
                }

                // 7. Enable Controller Support
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "stadia_controller"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM; settingKey: "enableController"
                        label: "Enable Controller Support (BETA)"; description: "Allow gamepads to trigger and navigate the toolbar via IPC"
                        defaultValue: false
                    }
                }

                // 8. Toolbar Background Opacity
                SliderSettingV2 {
                    width: parent.width
                    settingKey: "toolbarOpacity"
                    label: "Toolbar Background Opacity"
                    description: "Adjust background transparency of the capture toolbar (default: 85%)"
                    defaultValue: "0.85"
                    minVal: 0.10
                    maxVal: 1.00
                    isFloatBackend: true
                    showPercentage: true
                    iconName: "opacity"
                }

                // 9. Recording Pill Opacity
                SliderSettingV2 {
                    width: parent.width
                    settingKey: "pillOpacity"
                    label: "Recording Pill Opacity"
                    description: "Adjust background transparency of the status pill (default: 92%)"
                    defaultValue: "0.92"
                    minVal: 0.10
                    maxVal: 1.00
                    isFloatBackend: true
                    showPercentage: true
                    iconName: "opacity"
                }
            }
        }

        // ====================================================================
        // CONTAINER 5: COMMANDS & SHORTCUTS
        // ====================================================================
        Rectangle {
            width: parent.width
            height: commandsGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            Column {
                id: commandsGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "terminal"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    StyledText { text: "Commands & Shortcuts"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                }

                StyledText {
                    width: parent.width
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
}
