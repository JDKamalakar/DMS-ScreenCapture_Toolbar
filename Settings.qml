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

    property bool showAdv: false


    property var monitorList: ["default"]
    property var micList: [{label: "Default", value: "default"}]
    property bool isTestingMic: false
    property bool isPlayingMic: false
    property bool isProcessingMic: false
    property int micTestCountdown: 0

    Process {
        command: ["bash", "-c", "hyprctl monitors -j 2>/dev/null | jq -r \".[].name\" || xrandr --listmonitors 2>/dev/null | awk \"{print \$4}\" | grep -v \"^$\""]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                var name = data.trim();
                if (name !== "") {
                    var exists = false;
                    for (var i = 0; i < root.monitorList.length; i++) {
                        if (root.monitorList[i] === name) exists = true;
                    }
                    if (!exists) {
                        var l = root.monitorList.slice();
                        l.push(name);
                        root.monitorList = l;
                    }
                }
            }
        }
    }

    Process {
        command: ["bash", "-c", "gpu-screen-recorder --list-audio-devices 2>/dev/null | grep -v '\.monitor' | grep -v 'output' | grep -v 'default_input'"]
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

    // Wrap everything in a Row for Dual Panel Layout
    Row {
        width: parent.width
        spacing: Theme.spacingM

        Column {
            width: root.showAdv ? (parent.width - Theme.spacingM) / 2 : parent.width
            spacing: Theme.spacingM
            
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }



        // --- Screenshot Settings ---
        Rectangle {
            width: parent.width
            height: captureGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            function loadValue() {
                if (!captureGroup) return;
                for (var i = 0; i < captureGroup.children.length; i++) {
                    var row = captureGroup.children[i];
                    if (row && row.children) {
                        for (var j = 0; j < row.children.length; j++) {
                            if (row.children[j].loadValue) row.children[j].loadValue();
                        }
                    }
                }
            }

            Column {
                id: captureGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "camera"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    SelectionSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "captureMode"
                        label: "Screenshot Mode"
                        description: "Choose what to capture"
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

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "monitor_weight"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "multiMonitorScreenshot"
                        label: "Multi-Monitor Screenshots"
                        description: "Use slurp and grim for interactive screenshots across displays"
                        defaultValue: false
                    }
                }
            }
        }


        // --- Output Settings ---
        Rectangle {
            width: parent.width
            height: outputGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            function loadValue() {
                if (!outputGroup) return;
                for (var i = 0; i < outputGroup.children.length; i++) {
                    var row = outputGroup.children[i];
                    if (row && row.children) {
                        for (var j = 0; j < row.children.length; j++) {
                            if (row.children[j].loadValue) row.children[j].loadValue();
                        }
                    }
                }
            }

            Column {
                id: outputGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "image"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    SelectionSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "format"
                        label: "Image Format"
                        description: "Format to save the screenshot in"
                        options: [
                            {label: "PNG (Lossless)", value: "png"},
                            {label: "JPEG", value: "jpg"},
                            {label: "PPM (Raw)", value: "ppm"}
                        ]
                        defaultValue: "png"
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "high_quality"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    Column {
                        width: parent.width - 22 - Theme.spacingM
                        spacing: Theme.spacingXS
                        StyledText { text: "JPEG Quality"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Quality from 1-100 (only applies if format is JPEG)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        StringSetting { width: parent.width; settingKey: "quality"; label: ""; description: ""; defaultValue: "90" }
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "folder"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    Column {
                        width: parent.width - 22 - Theme.spacingM
                        spacing: Theme.spacingXS
                        StyledText { text: "Custom Path"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Absolute path to save screenshots. Leave empty for default."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        StringSetting { width: parent.width; settingKey: "customPath"; label: ""; description: ""; placeholder: root.defaultPath; defaultValue: "" }
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "timer"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    SelectionSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "delaySeconds"
                        label: "Capture Delay"
                        description: "Delay in seconds before capturing (non-interactive modes only)"
                        options: [
                            {label: "No Delay", value: "0"},
                            {label: "3 Seconds", value: "3"},
                            {label: "5 Seconds", value: "5"},
                            {label: "10 Seconds", value: "10"}
                        ]
                        defaultValue: "0"
                    }
                }
            }
        }


        // --- Video Settings ---
        Rectangle {
            width: parent.width
            height: videoGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            function loadValue() {
                if (!videoGroup) return;
                for (var i = 0; i < videoGroup.children.length; i++) {
                    var row = videoGroup.children[i];
                    if (row && row.children) {
                        for (var j = 0; j < row.children.length; j++) {
                            if (row.children[j].loadValue) row.children[j].loadValue();
                        }
                    }
                }
            }

            Column {
                id: videoGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "videocam"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    SelectionSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "videoFormat"
                        label: "Video Format"
                        description: "Container format for recordings"
                        options: [
                            {label: "MKV (Matroska)", value: "mkv"},
                            {label: "MP4 (MPEG-4)", value: "mp4"},
                            {label: "FLV (Flash)", value: "flv"}
                        ]
                        defaultValue: "mkv"
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "mic"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "recordAudio"
                        label: "Record Audio"
                        description: "Include system audio in the recording"
                        defaultValue: true
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "mic"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "recordMic"
                        label: "Record Microphone"
                        description: "Include the default microphone input in the recording"
                        defaultValue: false
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "speed"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    SelectionSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "videoFPS"
                        label: "Video FPS"
                        description: "Frames per second for recording"
                        options: [
                            {label: "24 FPS", value: "24"},
                            {label: "30 FPS", value: "30"},
                            {label: "60 FPS", value: "60"}
                        ]
                        defaultValue: "60"
                    }
                }
                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "tune"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM
                        id: advSettingsToggle
                        settingKey: "showAdvancedSettings"
                        label: "Show Advanced Settings"
                        description: "Enable advanced codec options in the capture toolbar"
                        defaultValue: false
                        onValueChanged: root.showAdv = value
                        Component.onCompleted: root.showAdv = value
                    }
                }
            }
        }


        // --- Interface ---
        Rectangle {
            width: parent.width
            height: interfaceGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            function loadValue() {
                if (!interfaceGroup) return;
                for (var i = 0; i < interfaceGroup.children.length; i++) {
                    var row = interfaceGroup.children[i];
                    if (row && row.children) {
                        for (var j = 0; j < row.children.length; j++) {
                            if (row.children[j].loadValue) row.children[j].loadValue();
                        }
                    }
                }
            }

            Column {
                id: interfaceGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "mouse"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "showPointer"
                        label: "Show Pointer"
                        description: "Include mouse pointer in the screenshot"
                        defaultValue: true
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "notifications"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "showNotify"
                        label: "Show Notification"
                        description: "Show system notification after capture"
                        defaultValue: true
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "pill"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "showRecPill"
                        label: "Show Recording Pill"
                        description: "Show the status pill at the top during recording"
                        defaultValue: true
                    }
                }
            }
        }


        // --- Styles ---
        Rectangle {
            width: parent.width
            height: interfaceStylesGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            function loadValue() {
                if (!interfaceStylesGroup) return;
                for (var i = 0; i < interfaceStylesGroup.children.length; i++) {
                    var row = interfaceStylesGroup.children[i];
                    if (row && row.children) {
                        for (var j = 0; j < row.children.length; j++) {
                            if (row.children[j].loadValue) row.children[j].loadValue();
                        }
                    }
                }
            }

            Column {
                id: interfaceStylesGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "opacity"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    Column {
                        width: parent.width - 22 - Theme.spacingM
                        spacing: Theme.spacingXS
                        StyledText { text: "Toolbar Transparency"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Adjust the background opacity of the toolbar and recording pill"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        StyledText { text: "Toolbar Background Opacity"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                        StringSetting { width: parent.width; settingKey: "toolbarOpacity"; label: ""; description: ""; placeholder: "0.85"; defaultValue: "0.85" }
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        StyledText { text: "Recording Pill Opacity"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                        StringSetting { width: parent.width; settingKey: "pillOpacity"; label: ""; description: ""; placeholder: "0.92"; defaultValue: "0.92" }
                    }
                }
            }
        }
        }

        Column {
            width: root.showAdv ? (parent.width - Theme.spacingM) / 2 : 0
            spacing: Theme.spacingM
            visible: width > 0
            clip: true
            
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

        // --- Advanced Video Settings ---
        Rectangle {
            width: parent.width
            height: advVideoGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            function loadValue() {
                if (!advVideoGroup) return;
                for (var i = 0; i < advVideoGroup.children.length; i++) {
                    var row = advVideoGroup.children[i];
                    if (row && row.children) {
                        for (var j = 0; j < row.children.length; j++) {
                            if (row.children[j].loadValue) row.children[j].loadValue();
                        }
                    }
                }
            }

            Column {
                id: advVideoGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM


                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "high_quality"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    SelectionSetting {
                        width: Math.max(0, parent.width - 22 - Theme.spacingM)
                        settingKey: "videoQuality"
                        label: "Video Quality"
                        description: "Quality preset for video recording"
                        options: [
                            {label: "Medium", value: "medium"},
                            {label: "High", value: "high"},
                            {label: "Very High", value: "very_high"},
                            {label: "Ultra", value: "ultra"}
                        ]
                        defaultValue: "medium"
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "settings_applications"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    SelectionSetting {
                        width: Math.max(0, parent.width - 22 - Theme.spacingM)
                        settingKey: "videoCodec"
                        label: "Video Codec"
                        description: "Hardware video encoder for recording"
                        options: [
                            {label: "Auto (Recomended)", value: "auto"},
                            {label: "AV1", value: "av1"},
                            {label: "AV1 (10 Bit)", value: "av1_10bit"},
                            {label: "AV1 (HDR)", value: "av1_hdr"},
                            {label: "H.264 SE (Not Recomended)", value: "h264"}
                        ]
                        defaultValue: "auto"
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "audio_file"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    SelectionSetting {
                        width: Math.max(0, parent.width - 22 - Theme.spacingM)
                        settingKey: "audioCodec"
                        label: "Audio Codec"
                        description: "Audio encoder for recording"
                        options: [
                            {label: "Opus (Recomended)", value: "opus"},
                            {label: "AAC", value: "aac"}
                        ]
                        defaultValue: "aac"
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    visible: typeof pluginData !== "undefined" && pluginData.captureMode === "monitor"
                    DankIcon { name: "desktop_windows"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    SelectionSetting {
                        width: Math.max(0, parent.width - 22 - Theme.spacingM)
                        settingKey: "videoMonitor"
                        label: "Target Monitor"
                        description: "Monitor to record when in multi-monitor setup"
                        options: root.monitorList.map(function(m) { return {label: m, value: m}; })
                        defaultValue: "default"
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    visible: typeof pluginData !== "undefined" && pluginData.recordMic === true
                    DankIcon { name: "mic"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    SelectionSetting {
                        width: Math.max(0, parent.width - 22 - Theme.spacingM)
                        settingKey: "videoMic"
                        label: "Microphone Device"
                        description: "Microphone to record from"
                        options: root.micList
                        defaultValue: "default"
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    visible: typeof pluginData !== "undefined" && pluginData.recordMic === true
                    DankIcon { name: "mic_none"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    Rectangle {
                        width: Math.max(0, parent.width - 22 - Theme.spacingM)
                        height: 32
                        radius: (root.isTestingMic && !root.isPlayingMic && !root.isProcessingMic) ? 16 : 8
                        color: (root.isTestingMic && !root.isPlayingMic && !root.isProcessingMic) ? (Theme.primary || "#38bdf8") : (testMicMaSettings.containsMouse ? Theme.withAlpha(Theme.primary || "#38bdf8", 0.1) : "transparent")
                        border.color: Theme.primary || "#38bdf8"
                        border.width: 1
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on radius { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            DankIcon {
                                id: testMicIconSettings
                                name: root.isTestingMic ? (root.isProcessingMic ? "autorenew" : (root.isPlayingMic ? "volume_up" : (root.micTestCountdown > 0 ? "timer" : "stop"))) : "fiber_manual_record"
                                size: 16
                                color: (root.isTestingMic && !root.isPlayingMic && !root.isProcessingMic) ? (Theme.onPrimary || "#ffffff") : (Theme.primary || "#38bdf8")
                                
                                transformOrigin: Item.Center
                                
                                RotationAnimator on rotation {
                                    from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: root.isProcessingMic
                                }
                                
                                SequentialAnimation on scale {
                                    id: pulseAnimSettings
                                    loops: Animation.Infinite; running: root.isTestingMic && !root.isProcessingMic
                                    NumberAnimation { to: 1.25; duration: 500; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                                }
                                
                                onNameChanged: {
                                    if (!root.isProcessingMic) rotation = 0;
                                    if (!pulseAnimSettings.running) scale = 1.0;
                                }
                            }
                            StyledText {
                                text: root.isTestingMic ? (root.isProcessingMic ? "Processing..." : (root.isPlayingMic ? "Playing Test..." : (root.micTestCountdown > 0 ? "Starting in " + root.micTestCountdown + "..." : "Testing (Speak now...)"))) : "Test Microphone"
                                color: (root.isTestingMic && !root.isPlayingMic && !root.isProcessingMic) ? (Theme.onPrimary || "#ffffff") : (Theme.primary || "#38bdf8")
                                font.pixelSize: 12
                            }
                        }
                        
                        MouseArea {
                            id: testMicMaSettings
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.isTestingMic) {
                                    if (root.isPlayingMic || root.isProcessingMic || root.micTestCountdown > 0) {
                                        micTestProcess.running = false;
                                        root.isTestingMic = false;
                                    } else {
                                        Qt.createQmlObject('import QtQuick 2.15; import DankMaterialShell 1.0; Process { command: ["bash", "-c", "touch /tmp/mic_stop"]; running: true }', testMicMaSettings, "stopSignalProc");
                                    }
                                } else {
                                    root.isTestingMic = true;
                                    root.isPlayingMic = false;
                                    root.micTestCountdown = 3;
                                    var mic = "default";
                                    // Hack to get the current setting value if available
                                    if (typeof pluginData !== "undefined" && pluginData.videoMic) {
                                        mic = pluginData.videoMic;
                                    }
                                    var recordCmd = "killall -9 pw-record pw-play 2>/dev/null; rm -f /tmp/mic_test.wav /tmp/mic_stop; ";
                                    recordCmd += "echo COUNTDOWN 3; sleep 1; echo COUNTDOWN 2; sleep 1; echo COUNTDOWN 1; sleep 1; echo RECORDING; ";
                                    if (mic && mic !== "default" && mic !== "default_input") {
                                        recordCmd += "pw-record --target " + mic + " /tmp/mic_test.wav & REC_PID=$!; ";
                                    } else {
                                        recordCmd += "pw-record /tmp/mic_test.wav & REC_PID=$!; ";
                                    }
                                    recordCmd += "for i in {1..50}; do if [ -f /tmp/mic_stop ]; then break; fi; sleep 0.1; done; ";
                                    recordCmd += "if kill -0 $REC_PID 2>/dev/null; then kill -INT $REC_PID 2>/dev/null; echo PROCESSING; wait $REC_PID 2>/dev/null; sleep 6; echo PLAYING; pw-play /tmp/mic_test.wav; fi";
                                    micTestProcess.command = ["bash", "-c", recordCmd];
                                    micTestProcess.running = true;
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "folder"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    Column {
                        width: parent.width - 22 - Theme.spacingM
                        spacing: Theme.spacingXS
                        StyledText { text: "Video Custom Path"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Absolute path to save recordings. Leave empty for ~/Videos."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        StringSetting { width: parent.width; settingKey: "videoCustomPath"; label: ""; description: ""; placeholder: "~/Videos"; defaultValue: "" }
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "terminal"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    Column {
                        width: parent.width - 22 - Theme.spacingM
                        spacing: Theme.spacingXS
                        StyledText { text: "Video Filename"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Override the generated recording filename. Extension is added if omitted."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        StringSetting { width: parent.width; settingKey: "videoFilename"; label: ""; description: ""; placeholder: "recording_2026-05-15_14-30-00.mkv"; defaultValue: "" }
                    }
                }
            }
        }


        // --- Editor & Shortcuts ---
        Rectangle {
            width: parent.width
            height: actionsGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            function loadValue() {
                if (!actionsGroup) return;
                for (var i = 0; i < actionsGroup.children.length; i++) {
                    var row = actionsGroup.children[i];
                    if (row && row.children) {
                        for (var j = 0; j < row.children.length; j++) {
                            if (row.children[j].loadValue) row.children[j].loadValue();
                        }
                    }
                }
            }

            Column {
                id: actionsGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "save"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "saveToDisk"
                        label: "Save to Disk"
                        description: "Save screenshot to disk (disable to only save to clipboard)"
                        defaultValue: true
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "content_copy"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "copyToClipboard"
                        label: "Copy to Clipboard"
                        description: "Copy the resulting image to your clipboard"
                        defaultValue: true
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "output"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "stdout"
                        label: "Screenshot Editor"
                        description: "Master switch: Enable external editor integration"
                        defaultValue: false
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "keyboard"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "enableEditorShortcut"
                        label: "Enable Editor Shortcut"
                        description: "Allow using the secondary shortcut to trigger the editor"
                        defaultValue: true
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "swap_horiz"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    ToggleSetting {
                        width: parent.width - 22 - Theme.spacingM
                        settingKey: "swapCaptureKeys"
                        label: "Swap Shortcuts"
                        description: "Space: Edit, Ctrl+Space: Capture"
                        defaultValue: false
                    }
                }

                Row {
                    width: parent.width; spacing: Theme.spacingM
                    DankIcon { name: "input"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                    Column {
                        width: parent.width - 22 - Theme.spacingM
                        spacing: Theme.spacingXS
                        StyledText { text: "Editor Pipe Command"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Medium; color: Theme.surfaceText }
                        StyledText { text: "Command after ' | ' (e.g. swappy -f -)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        StringSetting { width: parent.width; settingKey: "pipeCommand"; label: ""; description: ""; placeholder: "swappy -f -"; defaultValue: "" }
                    }
                }
            }
        }
        }
    }
}
