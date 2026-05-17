import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets
import QtCore

PluginSettings {
    id: root
    pluginId: "screenCaptureToolbar"

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

    // Wrap everything in a Column because PluginSettings is a Flickable 
    // and needs a single content item or manual layout.
    Column {
        width: parent.width
        spacing: Theme.spacingM

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
                            {label: "60 FPS", value: "60"},
                            {label: "30 FPS", value: "30"},
                            {label: "24 FPS", value: "24"}
                        ]
                        defaultValue: "60"
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
}
