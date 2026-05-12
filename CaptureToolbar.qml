import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // -- Internal State -------------------------------------------------------
    property string captureMode: "interactive" // interactive, full, all, window
    property bool isVideoMode: false
    property bool settingsExpanded: false

    // -- Screenshot Settings -------------------------------------------------
    property bool showPointer: (pluginData && pluginData.showPointer != null) ? pluginData.showPointer : true
    property bool saveToDisk: (pluginData && pluginData.saveToDisk != null) ? pluginData.saveToDisk : true
    property bool copyToClipboard: (pluginData && pluginData.copyToClipboard != null) ? pluginData.copyToClipboard : true
    property string format: (pluginData && pluginData.format) || "png"
    property int quality: (pluginData && pluginData.quality) || 90
    property string customPath: (pluginData && pluginData.customPath) || ""
    property string filename: (pluginData && pluginData.filename) || ""
    property bool stdout: (pluginData && pluginData.stdout != null) ? pluginData.stdout : false
    property string pipeCommand: (pluginData && pluginData.pipeCommand) || ""

    // -- Video Settings ------------------------------------------------------
    property bool recordAudio: (pluginData && pluginData.recordAudio != null) ? pluginData.recordAudio : true
    property string videoFormat: (pluginData && pluginData.videoFormat) || "mkv"
    property int videoFPS: (pluginData && pluginData.videoFPS) || 60
    property string videoCodec: (pluginData && pluginData.videoCodec) || "auto"
    property bool isRecording: false
    property bool isPaused: false
    property int recordingElapsed: 0
    property var recordingProcess: null
    property bool showRecPill: (pluginData && pluginData.showRecPill !== undefined) ? pluginData.showRecPill : true
    property bool showNotify: (pluginData && pluginData.showNotify !== undefined) ? pluginData.showNotify : true
    property real toolbarOpacity: (pluginData && pluginData.toolbarOpacity != null) ? pluginData.toolbarOpacity : 0.85
    property real pillOpacity: (pluginData && pluginData.pillOpacity != null) ? pluginData.pillOpacity : 0.92

    // -- IPC ------------------------------------------------------------------
    IpcHandler {
        target: "screenCaptureToolbar"

        function toggle(): string {
            root.toggle();
            return overlay.visible ? "opened" : "closed";
        }

        function open(): string {
            root.open();
            return "opened";
        }

        function close(): string {
            root.close();
            return "closed";
        }

        /** Reset recording UI if interactive video setup fails (e.g. slurp cancelled). Called from bash. */
        function cancelRecording(): string {
            root.isRecording = false;
            root.isPaused = false;
            root.recordingElapsed = 0;
            return "cancelled";
        }

        /** Show pill + timer only after region selection / portal begins recording (interactive video). Called from bash. */
        function recordingStarted(): string {
            root.isRecording = true;
            root.isPaused = false;
            root.recordingElapsed = 0;
            if (root.showNotify) {
                let dirMsg = root.customPath !== "" ? root.customPath : "~/Videos";
                Quickshell.execDetached(["notify-send", "Recording Started", "Saving to " + dirMsg]);
            }
            return "started";
        }
    }



    function open() {
        root.settingsExpanded = false;
        overlay.visible = true;
        overlay.forceActiveFocus();
    }

    function close() {
        overlay.visible = false;
        root.settingsExpanded = false;
    }

    function toggle() {
        if (overlay.visible) root.close();
        else root.open();
    }

    function _save(key, value) {
        if (typeof PluginService !== "undefined" && PluginService) {
            PluginService.savePluginData("screenCaptureToolbar", key, value);
        }
    }

    function performCapture() {
        if (root.isRecording) {
            root.stopRecording();
            return;
        }
        root.handleCapture(root.captureMode);
    }

    function handleCapture(mode) {
        if (mode) root.captureMode = mode;
        
        if (root.isVideoMode) {
            if (root.isRecording) {
                root.stopRecording();
            } else {
                root.startVideoRecording();
            }
        } else {
            root.takeScreenshot();
        }
    }

    function takeScreenshot() {
        let dmsStr = "dms screenshot";
        if (root.captureMode === "full") dmsStr += " full";
        else if (root.captureMode === "all") dmsStr += " all";
        else if (root.captureMode === "window") dmsStr += " window";

        dmsStr += root.showPointer ? " --cursor=on" : " --cursor=off";
        if (!root.saveToDisk) dmsStr += " --no-file";
        if (!root.copyToClipboard) dmsStr += " --no-clipboard";
        if (!root.showNotify) dmsStr += " --no-notify";
        if (root.stdout) dmsStr += " --stdout";
        if (root.filename !== "") dmsStr += " --filename \"" + root.filename + "\"";

        dmsStr += " -f " + root.format;
        if (root.format === "jpg") dmsStr += " -q " + root.quality;
        
        if (root.customPath !== "") {
            dmsStr += " --dir \"" + root.customPath + "\"";
        }
        
        if (root.stdout && root.pipeCommand !== "") {
            dmsStr += " | " + root.pipeCommand;
        }

        // Close overlay immediately so interactive region selection works
        root.close();
        Quickshell.execDetached(["bash", "-c", "sleep 0.2; " + dmsStr]);
    }

    function startVideoRecording() {
        let timestamp = new Date().getTime();
        let filename = "recording-" + timestamp + "." + root.videoFormat;
        let dir = root.customPath !== "" ? root.customPath.replace(/^~/, "$HOME") : "$HOME/Videos";
        let path = dir + "/" + filename;

        let prepends = [];
        prepends.push("export NIRI_SOCKET=$(ls /run/user/$(id -u)/niri*.sock 2>/dev/null | head -n 1)");
        if (root.recordAudio) {
            prepends.push("SINK=$(pactl get-default-sink 2>/dev/null); if [ -n \"$SINK\" ]; then AUDIO=\"$SINK.monitor\"; else AUDIO=\"default_output\"; fi");
        }
        prepends.push("MONITOR=\"\"; if command -v niri >/dev/null 2>&1; then MONITOR=$(niri msg -j outputs 2>/dev/null | jq -r 'keys[0]'); elif command -v hyprctl >/dev/null 2>&1; then MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name'); fi; if [ -z \"$MONITOR\" ] || [ \"$MONITOR\" = \"null\" ]; then MONITOR=\"portal\"; fi");

        let gsrSuffix = " -c " + root.videoFormat;
        gsrSuffix += " -f " + root.videoFPS;
        if (root.recordAudio)
            gsrSuffix += " -a \"$AUDIO\"";
        gsrSuffix += root.showPointer ? " -cursor yes" : " -cursor no";
        gsrSuffix += " -o \"" + path + "\"";
        if (root.videoCodec !== "auto")
            gsrSuffix += " -k " + root.videoCodec;

        let prelude = prepends.join("; ");
        let scriptBody;
        if (root.captureMode === "interactive") {
            // Portal alone is unreliable on niri / some Wayland compositors; use slurp + -w region when available.
            scriptBody =
                "cancel_rec() { command -v dms >/dev/null 2>&1 && ( dms ipc call screenCaptureToolbar cancelRecording 2>/dev/null || dms ipc screenCaptureToolbar cancelRecording 2>/dev/null ); }; " +
                "start_rec() { command -v dms >/dev/null 2>&1 && ( dms ipc call screenCaptureToolbar recordingStarted 2>/dev/null || dms ipc screenCaptureToolbar recordingStarted 2>/dev/null ); }; " +
                "sleep 0.2; mkdir -p \"" + dir + "\"; " +
                "if command -v slurp >/dev/null 2>&1; then " +
                "REGION=$(slurp -f '%wx%h+%x+%y') || { cancel_rec; exit 1; }; " +
                "[ -z \"$REGION\" ] && { cancel_rec; exit 1; }; " +
                "start_rec; gpu-screen-recorder -w region -region \"$REGION\"" + gsrSuffix + "; " +
                "else " +
                "start_rec; gpu-screen-recorder -w portal" + gsrSuffix + "; " +
                "fi";
        } else {
            scriptBody = "sleep 0.2; mkdir -p \"" + dir + "\"; gpu-screen-recorder -w \"$MONITOR\"" + gsrSuffix;
        }

        let finalCmd = prelude !== "" ? prelude + "; " + scriptBody : scriptBody;

        let deferRecordingUi = root.captureMode === "interactive";
        if (!deferRecordingUi) {
            root.isRecording = true;
            root.isPaused = false;
            root.recordingElapsed = 0;
        }
        root.close();

        Quickshell.execDetached(["bash", "-c", finalCmd]);

        if (root.showNotify && !deferRecordingUi) {
            Quickshell.execDetached(["notify-send", "Recording Started", "Saving to " + dir]);
        }
    }

    function stopRecording() {
        Quickshell.execDetached(["pkill", "-SIGINT", "-f", "^gpu-screen-recorder"]);
        root.isRecording = false;
        root.isPaused = false;
        root.recordingElapsed = 0;
        
        if (root.showNotify) {
            Quickshell.execDetached(["notify-send", "Recording Stopped", "Video saved to " + (root.customPath || "~/Videos")]);
        }
    }

    function pauseRecording() {
        Quickshell.execDetached(["pkill", "-SIGUSR2", "-f", "^gpu-screen-recorder"]);
        root.isPaused = true;
    }

    function resumeRecording() {
        Quickshell.execDetached(["pkill", "-SIGUSR2", "-f", "^gpu-screen-recorder"]);
        root.isPaused = false;
    }

    function formatTime(totalSeconds) {
        let h = Math.floor(totalSeconds / 3600);
        let m = Math.floor((totalSeconds % 3600) / 60);
        let s = totalSeconds % 60;
        if (h > 0) return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Recording elapsed timer
    Timer {
        id: recordingTimer
        interval: 1000
        repeat: true
        running: root.isRecording && !root.isPaused
        onTriggered: root.recordingElapsed++
    }

    // -- UI -------------------------------------------------------------------
    PanelWindow {
        id: overlay
        visible: false
        color: "transparent"

        WlrLayershell.namespace: "dms:plugins:screenCaptureToolbar"
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: overlay.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        Item {
            anchors.fill: parent
            focus: overlay.visible
            Keys.onEscapePressed: root.close()
            Keys.onSpacePressed: root.performCapture()
        }



        // Background Dim
        Rectangle {
            id: dim
            anchors.fill: parent
            color: "black"
            opacity: overlay.visible ? 0.15 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // Local Tooltip with "above icon" logic - inside the window
        Item {
            id: globalTooltip
            visible: false
            property string text: ""
            property Item targetItem: null
            z: 999
            
            // Positioning logic: centered above the targetItem
            x: targetItem ? targetItem.mapToItem(overlay.contentItem, 0, 0).x + (targetItem.width - width) / 2 : 0
            y: targetItem ? targetItem.mapToItem(overlay.contentItem, 0, 0).y - height - 8 : 0
            
            width: tooltipLabel.implicitWidth + 24
            height: 32
            
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Qt.rgba(Theme.surfaceContainerHighest.r || 0.1, Theme.surfaceContainerHighest.g || 0.1, Theme.surfaceContainerHighest.b || 0.1, root.toolbarOpacity)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.1)
                
                layer.enabled: true
                layer.effect: DropShadow {
                    transparentBorder: true; verticalOffset: 4; radius: 12; samples: 24; color: Qt.rgba(0,0,0,0.4)
                }
            }
            
            StyledText {
                id: tooltipLabel
                anchors.centerIn: parent
                text: globalTooltip.text
                color: Theme.surfaceText || "white"
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            
            Behavior on opacity { NumberAnimation { duration: 150 } }
            opacity: visible ? 1 : 0
        }
        


        // --- Content ---
        Item {
            id: mainCont
            anchors.fill: parent

            // Floating Settings Bubble
            Rectangle {
                id: settingsBubble
                width: 320
                height: root.settingsExpanded ? settingsCol.implicitHeight + 40 : 0
                radius: 24
                color: Qt.rgba(Theme.surfaceContainerHigh.r || Theme.surface.r, Theme.surfaceContainerHigh.g || Theme.surface.g, Theme.surfaceContainerHigh.b || Theme.surface.b, root.toolbarOpacity)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.1)
                clip: true
                
                // Position strictly above the right side of the pill
                anchors.bottom: pillContainer.top
                anchors.bottomMargin: 24
                anchors.right: pillContainer.right
                
                opacity: root.settingsExpanded ? 1 : 0
                scale: root.settingsExpanded ? 1 : 0.9
                transformOrigin: Item.BottomRight
                
                Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                Behavior on opacity { NumberAnimation { duration: 250 } }
                Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

                layer.enabled: true
                layer.effect: DropShadow {
                    transparentBorder: true; verticalOffset: 8; radius: 32; samples: 64; color: Qt.rgba(0,0,0,0.5)
                }

                // Triangle pointer
                Rectangle {
                    width: 16; height: 16
                    color: settingsBubble.color
                    rotation: 45
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -8
                    anchors.right: parent.right
                    anchors.rightMargin: 82 // Centered exactly above the settings button (90px from right edge - 8px half width)
                    border.width: 1; border.color: settingsBubble.border.color
                    z: -1
                }

                ColumnLayout {
                    id: settingsCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 20
                    spacing: 12
                    
                    RowLayout {
                        spacing: 8
                        DankIcon { name: "settings"; size: 16; color: Theme.surfaceText }
                        StyledText { text: "Options"; font.bold: true; font.pixelSize: 15; color: Theme.surfaceText; Layout.fillWidth: true }
                    }
                    
                    // Toggles Segment
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: togglesCol.implicitHeight
                        radius: 12
                        color: Qt.rgba(Theme.secondary.r || 1, Theme.secondary.g || 1, Theme.secondary.b || 1, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(Theme.secondary.r || 1, Theme.secondary.g || 1, Theme.secondary.b || 1, 0.15)
                        clip: true
                        
                        Column {
                            id: togglesCol
                            width: parent.width
                            
                            SettingToggle { 
                                label: "Copy to Clipboard"; iconName: "content_copy"; active: root.copyToClipboard
                                visible: !root.isVideoMode
                                onToggled: { root.copyToClipboard = active; root._save("copyToClipboard", root.copyToClipboard) }
                            }
                            SettingToggle { 
                                label: "Save to Disk"; iconName: "save"; active: root.saveToDisk
                                visible: !root.isVideoMode
                                onToggled: { root.saveToDisk = active; root._save("saveToDisk", root.saveToDisk) }
                            }
                            SettingToggle { 
                                label: "Record Audio"; iconName: "mic"; active: root.recordAudio
                                visible: root.isVideoMode
                                onToggled: { root.recordAudio = active; root._save("recordAudio", root.recordAudio) }
                            }
                            SettingToggle { 
                                label: "Show Mouse Pointer"; iconName: "mouse"; active: root.showPointer
                                onToggled: { root.showPointer = active; root._save("showPointer", root.showPointer) }
                            }
                            SettingToggle { 
                                label: "Show Notification"; iconName: "notifications"; active: root.showNotify
                                onToggled: { root.showNotify = active; root._save("showNotify", root.showNotify) }
                            }
                            SettingToggle { 
                                label: "Show Recording Pill"; iconName: "pill"; active: root.showRecPill
                                visible: root.isVideoMode
                                isLast: true
                                onToggled: { root.showRecPill = active; root._save("showRecPill", root.showRecPill) }
                            }
                        }
                    }
                    
                    // Format Segment
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: formatCol.implicitHeight + 24
                        radius: 12
                        color: Qt.rgba(Theme.secondary.r || 1, Theme.secondary.g || 1, Theme.secondary.b || 1, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(Theme.secondary.r || 1, Theme.secondary.g || 1, Theme.secondary.b || 1, 0.15)
                        
                        ColumnLayout {
                            id: formatCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8
                            
                            RowLayout {
                                spacing: 12
                                DankIcon { name: root.isVideoMode ? "movie" : "image"; size: 18; color: Theme.surfaceVariantText }
                                StyledText { text: root.isVideoMode ? "Video Format" : "Image Format"; font.pixelSize: 13; color: Theme.surfaceText; Layout.fillWidth: true }
                            }
                            DankButtonGroup {
                                Layout.fillWidth: true; buttonHeight: 30; minButtonWidth: 54
                                scale: 0.95; transformOrigin: Item.Left
                                model: root.isVideoMode ? ["MP4", "MKV", "FLV"] : ["PNG", "JPG", "PPM"]
                                currentIndex: {
                                    if (root.isVideoMode) {
                                        return root.videoFormat === "mp4" ? 0 : (root.videoFormat === "mkv" ? 1 : 2);
                                    } else {
                                        return root.format === "png" ? 0 : (root.format === "jpg" ? 1 : 2);
                                    }
                                }
                                onSelectionChanged: function(idx, sel) { 
                                    if (sel) { 
                                        if (root.isVideoMode) {
                                            var vfmts = ["mp4", "mkv", "flv"];
                                            root.videoFormat = vfmts[idx];
                                            root._save("videoFormat", root.videoFormat);
                                        } else {
                                            var fmts = ["png", "jpg", "ppm"];
                                            root.format = fmts[idx]; 
                                            root._save("format", root.format);
                                        }
                                    } 
                                }
                            }
                        }
                    }
                    
                    // JPG Quality Segment
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: qualityCol.implicitHeight + 24
                        radius: 12
                        color: Qt.rgba(Theme.secondary.r || 1, Theme.secondary.g || 1, Theme.secondary.b || 1, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(Theme.secondary.r || 1, Theme.secondary.g || 1, Theme.secondary.b || 1, 0.15)
                        visible: root.format === "jpg" && !root.isVideoMode
                        
                        ColumnLayout {
                            id: qualityCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8
                            
                            RowLayout {
                                spacing: 12
                                DankIcon { name: "high_quality"; size: 18; color: Theme.surfaceVariantText }
                                StyledText { text: "JPG Quality"; font.pixelSize: 13; color: Theme.surfaceText; Layout.fillWidth: true }
                            }
                            DankTextField {
                                Layout.fillWidth: true; height: 28
                                font.pixelSize: 12
                                text: root.quality.toString()
                                placeholderText: "90"
                                onEditingFinished: {
                                    var v = parseInt(text);
                                    if (!isNaN(v)) { root.quality = v; root._save("quality", v); }
                                }
                            }
                        }
                    }
                    
                    // Custom Directory Segment
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: pathCol.implicitHeight + 24
                        radius: 12
                        color: Qt.rgba(Theme.secondary.r || 1, Theme.secondary.g || 1, Theme.secondary.b || 1, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(Theme.secondary.r || 1, Theme.secondary.g || 1, Theme.secondary.b || 1, 0.15)
                        
                        ColumnLayout {
                            id: pathCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8
                            
                            RowLayout {
                                spacing: 12
                                DankIcon { name: "folder"; size: 18; color: Theme.surfaceVariantText }
                                StyledText { text: "Custom Directory"; font.pixelSize: 13; color: Theme.surfaceText; Layout.fillWidth: true }
                            }
                            DankTextField {
                                Layout.fillWidth: true; height: 28
                                font.pixelSize: 12
                                text: root.customPath
                                placeholderText: root.isVideoMode ? "~/Videos" : "~/Pictures"
                                onEditingFinished: {
                                    root.customPath = text; 
                                    root._save("customPath", text);
                                }
                            }
                        }
                    }
                }
            }

            // Pill Container
            Item {
                id: pillContainer
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 48
                width: contentRow.implicitWidth + 32
                height: 68
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

                scale: overlay.visible ? 1.0 : 0.95
                opacity: overlay.visible ? 1.0 : 0.0
                Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
                Behavior on opacity { NumberAnimation { duration: 250 } }

                Rectangle {
                    id: pillBg
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(Theme.surfaceContainerHigh.r || Theme.surface.r, Theme.surfaceContainerHigh.g || Theme.surface.g, Theme.surfaceContainerHigh.b || Theme.surface.b, root.toolbarOpacity)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    
                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true; verticalOffset: 8; radius: 24; samples: 64; color: Qt.rgba(0,0,0,0.3)
                    }
                }

                MouseArea {
                    id: toolbarMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: (mouse) => mouse.accepted = true
                }

                RowLayout {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: 16

                    // Mode Selection (Segmented)
                    Row {
                        spacing: 4
                        ToolbarBtn { 
                            isFirst: true; iconName: "photo_camera"; active: !root.isVideoMode
                            tooltipText: "Photo Mode"
                            onClicked: root.isVideoMode = false
                        }
                        ToolbarBtn { 
                            isLast: true; iconName: "videocam"; active: root.isVideoMode
                            tooltipText: "Video Mode"
                            onClicked: root.isVideoMode = true
                        }
                    }

                    Rectangle { width: 1; height: 28; color: Qt.rgba(0, 0, 0, 0.1); anchors.verticalCenter: parent.verticalCenter }

                    // Modes
                    Row {
                        id: modeRow
                        spacing: 4
                        ToolbarBtn { 
                            isFirst: true
                            iconName: "screenshot_region"
                            active: root.captureMode === "interactive"
                            tooltipText: "Interactive Region"
                            onClicked: { root.captureMode = "interactive"; }
                            
                        }
                        ToolbarBtn { 
                            iconName: "monitor"; 
                            active: root.captureMode === "full"
                            tooltipText: root.isVideoMode ? "Record Monitor" : "Focused Screen"
                            onClicked: { root.captureMode = "full"; } 
                        }
                        ToolbarBtn { 
                            isLast: true
                            iconName: "monitor_weight"; 
                            active: root.captureMode === "all"
                            tooltipText: root.isVideoMode ? "Record All" : "All Screens"
                            onClicked: { root.captureMode = "all"; } 
                        }
                    }

                    Rectangle { width: 1; height: 28; color: Qt.rgba(0, 0, 0, 0.1); anchors.verticalCenter: parent.verticalCenter }

                    // Actions
                    Row {
                        id: actionRow
                        spacing: 4
                        ToolbarBtn { isFirst: true; id: settingsBtn; iconName: "settings"; active: root.settingsExpanded; onClicked: root.settingsExpanded = !root.settingsExpanded }
                        ToolbarBtn { isLast: true; iconName: "close"; hoverColor: "#FF4444"; animateRotate: true; onClicked: root.close() }
                    }

                }
            }

            // Instruction Hint Pill
            Rectangle {
                width: hintText.implicitWidth + 32; height: 32; radius: 16
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                color: Qt.rgba(Theme.surfaceContainerHigh.r || Theme.surface.r, Theme.surfaceContainerHigh.g || Theme.surface.g, Theme.surfaceContainerHigh.b || Theme.surface.b, root.toolbarOpacity * 0.8)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.05)
                
                StyledText {
                    id: hintText
                    anchors.centerIn: parent
                    text: "Press Space To Capture"
                    font.pixelSize: 11; font.weight: Font.Medium
                    color: Theme.surfaceText || "#666666"
                }
                
                opacity: overlay.visible && !root.isRecording ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }
        
        Keys.onEscapePressed: root.close()
    }

    // -- Components -----------------------------------------------------------
    component ToolbarBtn: Item {
        property string iconName: ""
        property bool active: false
        property bool isFirst: false
        property bool isLast: false
        property bool animateRotate: false
        property string tooltipText: ""
        property color hoverColor: "transparent"
        property bool isDark: (Theme.surface.r + Theme.surface.g + Theme.surface.b < 1.5)
        signal clicked()
        width: 52; height: 40
        
        // Move scale to the root to avoid clipping artifacts
        scale: ma.pressed ? 0.92 : (ma.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

        Item {
            anchors.fill: parent
            clip: true // Clips the background geometry but scales with parent
            
            Rectangle {
                id: btnBg
                property real cornerOffset: 14
                x: active ? 0 : (isFirst ? 0 : (isLast ? -cornerOffset : -cornerOffset))
                width: active ? parent.width : (isFirst ? parent.width + cornerOffset : (isLast ? parent.width + cornerOffset : parent.width + cornerOffset * 2))
                height: parent.height
                radius: 20
                
                color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : 
                       (ma.containsMouse ? (hoverColor != "transparent" ? Qt.rgba(hoverColor.r, hoverColor.g, hoverColor.b, 0.2) : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.05)) : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.03))
                
                // Custom Ripple Effect
                Rectangle {
                    id: rippleObj
                    anchors.centerIn: parent
                    width: parent.width * 1.5; height: width
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.12)
                    opacity: 0; scale: 0
                    
                    states: State {
                        name: "pressed"; when: ma.pressed
                        PropertyChanges { target: rippleObj; opacity: 1; scale: 1 }
                    }
                    transitions: Transition {
                        NumberAnimation { properties: "opacity,scale"; duration: 400; easing.type: Easing.OutQuart }
                    }
                }

                Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 250 } }
                Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
            }
        }
        DankIcon { 
            id: icon
            name: parent.iconName; size: 20; anchors.centerIn: parent; 
            color: active ? (parent.isDark ? "white" : (Theme.primary || "#8D4D57")) : (Theme.primary || "#8D4D57")
            opacity: active ? 1 : (ma.containsMouse ? 1 : 0.7)
            
            // Interaction animations: Tilt for regular icons, full spin for close
            rotation: parent.animateRotate ? (ma.containsMouse ? 360 : 0) : (ma.containsMouse ? 12 : 0)
            y: (ma.containsMouse && !parent.animateRotate) ? -4 : 0
            
            Behavior on rotation { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
        }
        MouseArea { 
            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; 
            onClicked: parent.clicked() 
            onEntered: { 
                if (parent.tooltipText !== "") {
                    globalTooltip.text = parent.tooltipText;
                    globalTooltip.targetItem = parent;
                    globalTooltip.visible = true;
                }
            }
            onExited: globalTooltip.visible = false
        }
    }

    // Premium Action Button for the Recording Pill
    component PillActionBtn: Item {
        property string iconName: ""
        property real size: 40
        property real iconSize: 20
        property bool isDark: (Theme.surface.r + Theme.surface.g + Theme.surface.b < 1.5)
        signal clicked()
        
        width: size; height: size
        scale: ma.pressed ? 0.92 : (ma.containsMouse ? 1.08 : 1.0)
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
            clip: true
            
            // Hover glow
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: isDark ? "black" : "white"
                opacity: ma.containsMouse ? 0.1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            // DankRipple
            Rectangle {
                id: rippleObj
                anchors.centerIn: parent
                width: parent.width * 1.5; height: width
                radius: width / 2
                color: isDark ? "black" : "white"
                opacity: 0; scale: 0
                
                states: State {
                    name: "pressed"; when: ma.pressed
                    PropertyChanges { target: rippleObj; opacity: 0.2; scale: 1 }
                }
                transitions: Transition {
                    NumberAnimation { properties: "opacity,scale"; duration: 400; easing.type: Easing.OutQuart }
                }
            }
        }

        DankIcon {
            name: iconName; size: iconSize; 
            color: (ma.containsMouse || ma.pressed) ? "white" : Theme.primary
            anchors.centerIn: parent
            rotation: ma.containsMouse ? 8 : 0
            Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
        }

        MouseArea {
            id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
            onClicked: parent.clicked()
        }
    }



    component SettingToggle: Rectangle {
        id: toggleRoot
        property string label: ""
        property string iconName: ""
        property bool active: false
        property bool isLast: false
        signal toggled()
        
        width: parent.width; height: visible ? 44 : 0
        color: ma.containsMouse ? Qt.rgba(Theme.primary.r || 1, Theme.primary.g || 1, Theme.primary.b || 1, 0.08) : "transparent"
        clip: true
        radius: 12
        
        // Custom Ripple Effect
        Rectangle {
            id: toggleRipple
            anchors.centerIn: parent
            width: parent.width * 1.2; height: width
            radius: width / 2
            color: Qt.rgba(Theme.primary.r || 1, Theme.primary.g || 1, Theme.primary.b || 1, 0.12)
            opacity: 0; scale: 0
            
            states: State {
                name: "pressed"; when: ma.pressed
                PropertyChanges { target: toggleRipple; opacity: 1; scale: 1 }
            }
            transitions: Transition {
                NumberAnimation { properties: "opacity,scale"; duration: 400; easing.type: Easing.OutQuart }
            }
        }
        
        Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutQuart } }
        Behavior on opacity { NumberAnimation { duration: 400 } }
        opacity: visible ? 1 : 0
        Behavior on color { ColorAnimation { duration: 150 } }
        
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
            DankIcon { name: toggleRoot.iconName; size: 18; color: Theme.surfaceVariantText }
            StyledText { text: toggleRoot.label; font.pixelSize: 13; color: Theme.surfaceText; Layout.fillWidth: true }
            DankToggle { 
                scale: 0.85
                transformOrigin: Item.Right
                checked: toggleRoot.active
                onClicked: { toggleRoot.active = !toggleRoot.active; toggleRoot.toggled(); }
            }
        }
        
        Rectangle {
            width: parent.width; height: 1
            anchors.bottom: parent.bottom
            color: Qt.rgba(Theme.secondary.r || 1, Theme.secondary.g || 1, Theme.secondary.b || 1, 0.15)
            visible: !toggleRoot.isLast
        }
        
        MouseArea { 
            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { toggleRoot.active = !toggleRoot.active; toggleRoot.toggled(); }
        }
    }

    Component.onCompleted: {
        console.info("screenCaptureToolbar: daemon loaded — use 'dms ipc screenCaptureToolbar toggle' to open");
    }

    DankTooltipV2 {
        id: legacyTooltip
        visible: false
    }

    // Fullscreen transparent overlay for stable global dragging
    PanelWindow {
        id: dragOverlay
        visible: recPill.isDragging
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "dms-drag-overlay"
        color: "transparent"
        
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.ClosedHandCursor
            
            property int startX: 0
            property int startY: 0
            property int startMarginR: 0
            property int startMarginT: 0
            property bool firstEvent: true
            
            onVisibleChanged: { 
                if (visible) {
                    firstEvent = true;
                    startMarginR = recPill.recPillMarginRight;
                    startMarginT = recPill.recPillMarginTop;
                }
            }
            
            onPositionChanged: function(mouse) {
                if (recPill.isDragging) {
                    if (firstEvent) {
                        startX = mouse.x;
                        startY = mouse.y;
                        firstEvent = false;
                        return;
                    }
                    let dx = mouse.x - startX;
                    let dy = mouse.y - startY;
                    recPill.recPillMarginRight = Math.max(4, startMarginR - dx);
                    recPill.recPillMarginTop = Math.max(4, startMarginT + dy);
                }
            }
            onClicked: recPill.isDragging = false
        }
    }

    // =========================================================================
    // Recording Control Pill — top-right, collapsible with drag support
    // =========================================================================
    PanelWindow {
        id: recPill
        visible: root.isRecording && root.showRecPill
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "dms-rec-pill"
        
        anchors {
            top: true
            right: true
        }
        margins { 
            top: recPillMarginTop 
            right: recPillMarginRight
        }

        width: 460 
        height: 60 
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        // Local Tooltip for Recording Pill
        Item {
            id: pillTooltip
            visible: false
            property string text: ""
            property Item targetItem: null
            z: 999
            
            x: targetItem ? targetItem.mapToItem(recPill.contentItem, 0, 0).x + (targetItem.width - width) / 2 : 0
            y: targetItem ? targetItem.mapToItem(recPill.contentItem, 0, 0).y - height - 8 : 0
            
            width: pillTooltipLabel.implicitWidth + 20
            height: 28
            
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: Qt.rgba(0.1, 0.1, 0.1, 0.95)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.1)
                
                layer.enabled: true
                layer.effect: DropShadow {
                    transparentBorder: true; verticalOffset: 2; radius: 8; samples: 16; color: Qt.rgba(0,0,0,0.4)
                }
            }
            
            StyledText {
                id: pillTooltipLabel
                anchors.centerIn: parent
                text: pillTooltip.text
                color: "white"
                font.pixelSize: 11
                font.weight: Font.Medium
            }
            
            Behavior on opacity { NumberAnimation { duration: 150 } }
            opacity: visible ? 1 : 0
        }

        property bool recPillExpanded: false
        property int recPillMarginTop: 12
        property int recPillMarginRight: 12
        property bool isAnimating: widthAnim.running

        // Dragging state
        property bool isDragging: false
        readonly property bool isDark: (Theme.surface.r + Theme.surface.g + Theme.surface.b < 1.5)

        // width behavior handled by recPillBg now.

        // Timer removed. Using dragOverlay.

        Rectangle {
            id: recPillBg
            anchors.right: parent.right
            width: recPill.recPillExpanded ? 460 : 260
            height: parent.height
            radius: height / 2
            
            Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }

            // Fixed high opacity as requested, removing dependency on settings
            color: Qt.rgba(Theme.surface.r || 1, Theme.surface.g || 1, Theme.surface.b || 1, 0.98)
            border.width: recPill.isDragging ? 2 : 1
            border.color: recPill.isDragging ? Theme.primary : Qt.rgba(0, 0, 0, 0.1)
            
            layer.enabled: false // Shadows removed as requested
        }

        // ---- Collapsed State: [Dot] [Time] [Waveform] [Stop] ----
        Item {
            anchors.right: parent.right
            width: recPillBg.width
            height: parent.height
            opacity: !recPill.recPillExpanded ? 1 : 0
            visible: opacity > 0
            clip: true
            Behavior on opacity { NumberAnimation { duration: 300 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24; anchors.rightMargin: 16; anchors.topMargin: 6; anchors.bottomMargin: 6
                spacing: 16

                // Info block
                Row {
                    spacing: 10
                    Layout.fillWidth: true
                    
                    DankIcon { 
                        name: "chevron_left"; size: 16; color: Theme.surfaceText; opacity: 0.4
                        anchors.verticalCenter: parent.verticalCenter
                        rotation: 0 // Points Right to Expand
                    }

                    Rectangle {
                        width: 10; height: 10; radius: 5; anchors.verticalCenter: parent.verticalCenter
                        color: root.isPaused ? Theme.surfaceVariantText : "#FF4444"
                        SequentialAnimation on opacity {
                            running: root.isRecording && !root.isPaused
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                        }
                    }
                    StyledText {
                        id: collapsedTimer
                        text: root.formatTime(root.recordingElapsed)
                        font.pixelSize: 22; font.weight: Font.Medium; color: recPill.isDark ? "white" : "#333333"
                        font.family: "JetBrains Mono, monospace" // Monospace to prevent shifting
                        width: 70 // Fixed width to prevent shifting neighbors
                        horizontalAlignment: Text.AlignLeft
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    DankIcon { 
                        name: "graphic_eq"; size: 18; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on scale {
                            running: root.isRecording && !root.isPaused
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.8; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.1; duration: 600; easing.type: Easing.InOutSine }
                        }
                    }
                }

                // Squircle Stop Button
                PillActionBtn {
                    iconName: "stop"
                    onClicked: root.stopRecording()
                }
            }

            // Background MouseArea for dragging (RightButton)
            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.RightButton
                
                onClicked: function(mouse) {
                    recPill.isDragging = !recPill.isDragging;
                }
            }

            // Tap to expand
            TapHandler {
                onTapped: recPill.recPillExpanded = true
            }
        }

    // ---- Expanded State ----
    Item {
        anchors.right: parent.right
        width: recPillBg.width
        height: parent.height
        opacity: recPill.recPillExpanded ? 1 : 0
        visible: opacity > 0
        clip: true
        Behavior on opacity { NumberAnimation { duration: 300 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.topMargin: 6; anchors.bottomMargin: 6
            spacing: 12

            // Collapse Handle (Moved to left and rotated to point left)
            Rectangle {
                width: 36; height: 40; radius: 10
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                scale: collapseMa.pressed ? 0.92 : (collapseMa.containsMouse ? 1.08 : 1.0)
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                
                DankIcon { 
                    name: "chevron_left"; size: 18; 
                    color: (collapseMa.containsMouse || collapseMa.pressed) ? (recPill.isDark ? "white" : "black") : Theme.primary
                    anchors.centerIn: parent 
                    rotation: 180 + (collapseMa.containsMouse ? -12 : 0) // Points Left to Collapse + tilt
                    Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
                }
                MouseArea { id: collapseMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: recPill.recPillExpanded = false }
            }

            // Middle Info Block (Boxed)
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.margins: 4
                radius: 12
                color: "transparent"
                border.width: 1; border.color: Qt.rgba(0,0,0,0.05)
                
                Row {
                    anchors.centerIn: parent
                    spacing: 12
                    Rectangle {
                        width: 10; height: 10; radius: 5; anchors.verticalCenter: parent.verticalCenter
                        color: root.isPaused ? Theme.surfaceVariantText : "#FF4444"
                        SequentialAnimation on opacity {
                            running: root.isRecording && !root.isPaused
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                        }
                    }
                    StyledText {
                        id: expandedTimer
                        text: root.formatTime(root.recordingElapsed)
                        font.pixelSize: 22; font.weight: Font.Medium; color: recPill.isDark ? "white" : "#333333"
                        font.family: "JetBrains Mono, monospace"
                        width: 70
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    DankIcon { 
                        name: "graphic_eq"; size: 18; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5) 
                        SequentialAnimation on scale {
                            running: root.isRecording && !root.isPaused
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.8; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.1; duration: 600; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }

            // Action Block
            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter
                
                PillActionBtn {
                    iconName: "stop"
                    onClicked: root.stopRecording()
                }
                PillActionBtn {
                    iconName: root.isPaused ? "play_arrow" : "pause"
                    onClicked: root.isPaused ? root.resumeRecording() : root.pauseRecording()
                }
                PillActionBtn {
                    iconName: "photo_camera"
                    onClicked: {
                        let ssCmd = "dms screenshot";
                        ssCmd += root.showPointer ? " --cursor=on" : " --cursor=off";
                        ssCmd += " -f " + root.format;
                        Quickshell.execDetached(["bash", "-c", ssCmd]);
                    }
                }
            }

            // Drag Handle (Moved to right)
            Rectangle {
                width: 36; height: 40; 
                radius: recPill.isDragging ? 20 : 10
                color: recPill.isDragging ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                scale: moveMa.pressed ? 0.92 : (moveMa.containsMouse ? 1.08 : 1.0)
                
                Behavior on radius { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                DankIcon { 
                    name: "open_with"; size: 16; 
                    color: {
                        if (moveMa.pressed || recPill.isDragging) {
                            // When physically interacting (Pressed/Dragging), use inverted contrast
                            return recPill.isDark ? "black" : "white";
                        } else if (moveMa.containsMouse) {
                            // When just hovering, keep it the Primary accent color
                            return Theme.primary;
                        } else {
                            // Default idle state
                            return Theme.primary;
                        }
                    }                    anchors.centerIn: parent 
                    rotation: moveMa.containsMouse ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }
                }
                MouseArea { 
                    id: moveMa
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onClicked: function(mouse) {
                        recPill.isDragging = !recPill.isDragging;
                    }
                }
            }
        }
    }
    }
}
