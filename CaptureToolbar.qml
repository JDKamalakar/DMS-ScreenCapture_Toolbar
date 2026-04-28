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
    property string videoFormat: (pluginData && pluginData.videoFormat) || "mp4"
    property int videoFPS: (pluginData && pluginData.videoFPS) || 60
    property string videoCodec: (pluginData && pluginData.videoCodec) || "auto"
    property bool isRecording: false
    property bool isPaused: false
    property int recordingElapsed: 0
    property var recordingProcess: null
    property bool showNotify: (pluginData && pluginData.showNotify != null) ? pluginData.showNotify : true

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
    }



    function open() {
        overlay.visible = true;
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

        let gsrCmd = "gpu-screen-recorder";
        gsrCmd += " -w \"$MONITOR\"";
        gsrCmd += " -c " + root.videoFormat;
        gsrCmd += " -f " + root.videoFPS;
        if (root.recordAudio) gsrCmd += " -a \"$AUDIO\"";
        gsrCmd += root.showPointer ? " -cursor yes" : " -cursor no";
        gsrCmd += " -o \"" + path + "\"";
        if (root.videoCodec !== "auto") gsrCmd += " -k " + root.videoCodec;
        
        let finalCmd = prepends.join("; ");
        if (finalCmd !== "") finalCmd += "; ";
        finalCmd += gsrCmd;
        
        root.isRecording = true;
        root.isPaused = false;
        root.recordingElapsed = 0;
        root.close();
        
        Quickshell.execDetached(["bash", "-c", "sleep 0.2; mkdir -p \"" + dir + "\"; " + finalCmd]);
        
        if (root.showNotify) {
            Quickshell.execDetached(["notify-send", "Recording Started", "Saving to " + dir]);
        }
    }

    function stopRecording() {
        Quickshell.execDetached(["pkill", "-SIGINT", "gpu-screen-recorder"]);
        root.isRecording = false;
        root.isPaused = false;
        root.recordingElapsed = 0;
        
        if (root.showNotify) {
            Quickshell.execDetached(["notify-send", "Recording Stopped", "Video saved to " + (root.customPath || "~/Videos")]);
        }
    }

    function pauseRecording() {
        Quickshell.execDetached(["bash", "-c", "killall -SIGUSR2 gpu-screen-recorder"]);
        root.isPaused = true;
    }

    function resumeRecording() {
        Quickshell.execDetached(["bash", "-c", "killall -SIGUSR2 gpu-screen-recorder"]);
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
        WlrLayershell.keyboardFocus: overlay.visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        // Background Dim
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: overlay.visible ? 0.15 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            MouseArea { anchors.fill: parent; onClicked: root.close() }
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
                color: Qt.rgba(Theme.surfaceContainerHigh.r || Theme.surface.r, Theme.surfaceContainerHigh.g || Theme.surface.g, Theme.surfaceContainerHigh.b || Theme.surface.b, 0.85)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
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
                                label: "Screenshot Editor"; iconName: "output"; active: root.stdout
                                visible: !root.isVideoMode
                                onToggled: { root.stdout = active; root._save("stdout", root.stdout) }
                            }
                            SettingToggle { 
                                label: "Show Notification"; iconName: "notifications"; active: root.showNotify
                                isLast: true
                                onToggled: { root.showNotify = active; root._save("showNotify", root.showNotify) }
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
                    color: Qt.rgba(Theme.surfaceContainerHigh.r || Theme.surface.r, Theme.surfaceContainerHigh.g || Theme.surface.g, Theme.surfaceContainerHigh.b || Theme.surface.b, 0.85)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    
                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true; verticalOffset: 6; radius: 24; samples: 48; color: Qt.rgba(0,0,0,0.4)
                    }
                }

                RowLayout {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: 16

                    // Photo/Video Toggle
                    Rectangle {
                        width: 88; height: 40; radius: 20
                        color: Qt.rgba(1, 1, 1, 0.08)
                        
                        Rectangle {
                            width: 42; height: 36; radius: 18
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.isVideoMode ? 44 : 2
                            color: Theme.primary
                            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                        }

                        Row {
                            anchors.fill: parent
                            Item {
                                width: 44; height: 40
                                DankIcon { name: "photo_camera"; size: 20; anchors.centerIn: parent; color: !root.isVideoMode ? Theme.onPrimary : Theme.surfaceText }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.isVideoMode = false }
                            }
                            Item {
                                width: 44; height: 40
                                DankIcon { name: "videocam"; size: 20; anchors.centerIn: parent; color: root.isVideoMode ? Theme.onPrimary : Theme.surfaceText }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.isVideoMode = true }
                            }
                        }
                    }

                    Rectangle { width: 1; height: 28; color: Qt.rgba(1, 1, 1, 0.15) }

                    // Modes
                    Row {
                        spacing: 8
                        ToolbarBtn { 
                            iconName: "screenshot_region"
                            active: root.captureMode === "interactive"
                            tooltipText: "Interactive Region"
                            visible: !root.isVideoMode
                            onClicked: { root.handleCapture("interactive"); } 
                        }
                        ToolbarBtn { 
                            iconName: root.isRecording && root.captureMode === "full" ? "stop_circle" : "monitor"; 
                            active: root.captureMode === "full"
                            tooltipText: root.isRecording && root.captureMode === "full" ? "Stop Recording" : (root.isVideoMode ? "Record Monitor" : "Focused Screen")
                            onClicked: { root.handleCapture("full"); } 
                        }
                        ToolbarBtn { 
                            iconName: root.isRecording && root.captureMode === "all" ? "stop_circle" : "monitor_weight"; 
                            active: root.captureMode === "all"
                            tooltipText: root.isRecording && root.captureMode === "all" ? "Stop Recording" : (root.isVideoMode ? "Record All" : "All Screens")
                            onClicked: { root.handleCapture("all"); } 
                        }
                    }

                    Rectangle { width: 1; height: 28; color: Qt.rgba(1, 1, 1, 0.15) }

                    // Actions
                    Row {
                        spacing: 8
                        ToolbarBtn { id: settingsBtn; iconName: "settings"; active: root.settingsExpanded; onClicked: root.settingsExpanded = !root.settingsExpanded }
                        ToolbarBtn { iconName: "close"; onClicked: root.close() }
                    }
                }
            }
        }
        
        Keys.onEscapePressed: root.close()
    }

    // -- Components -----------------------------------------------------------
    component ToolbarBtn: Item {
        property string iconName: ""
        property bool active: false
        property string tooltipText: ""
        signal clicked()
        width: 44; height: 44
        
        Rectangle {
            anchors.fill: parent; radius: 22
            color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3) : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
            border.width: active ? 1 : 0; border.color: Theme.primary
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        DankIcon { name: parent.iconName; size: 22; anchors.centerIn: parent; color: active ? Theme.primary : Theme.surfaceText }
        MouseArea { 
            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; 
            onClicked: parent.clicked() 
            onEntered: { if (parent.tooltipText !== "") globalTooltip.show(parent.tooltipText, parent) }
            onExited: globalTooltip.hide()
        }
    }

    component SettingToggle: Rectangle {
        id: toggleRoot
        property string label: ""
        property string iconName: ""
        property bool active: false
        property bool isLast: false
        signal toggled()
        width: parent.width; height: 44
        color: ma.containsMouse ? Qt.rgba(Theme.primary.r || 1, Theme.primary.g || 1, Theme.primary.b || 1, 0.08) : "transparent"
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
        id: globalTooltip
    }

    // =========================================================================
    // Recording Control Pill — top-right, collapsible with drag support
    // =========================================================================
    PanelWindow {
        id: recPill
        visible: root.isRecording
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "dms-rec-pill"
        anchors { top: true; right: true }
        margins { top: recPillMarginTop; right: recPillMarginRight }
        width: recPillExpanded ? 310 : 64
        height: 44
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        property bool recPillExpanded: false
        property int recPillMarginTop: 12
        property int recPillMarginRight: 12

        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

        // Shadow (separate rect behind to avoid layer clipping issues)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: (parent.height + 4) / 2
            color: "transparent"
            border.width: 0

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: recPill.height / 2
                color: Qt.rgba(0, 0, 0, 0.35)
                anchors.verticalCenterOffset: 3
            }
        }

        Rectangle {
            id: recPillBg
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(Theme.surfaceContainerHigh.r || Theme.surface.r, Theme.surfaceContainerHigh.g || Theme.surface.g, Theme.surfaceContainerHigh.b || Theme.surface.b, 0.92)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
        }

        // ---- Collapsed: dot + timer + arrow (click or right-drag to reposition) ----
        Item {
            anchors.fill: parent
            visible: !recPill.recPillExpanded
            clip: true

            Row {
                anchors.centerIn: parent
                spacing: 6

                // Pulsing dot
                Rectangle {
                    width: 10; height: 10; radius: 5; anchors.verticalCenter: parent.verticalCenter
                    color: root.isPaused ? Theme.surfaceVariantText : "#FF4444"
                    SequentialAnimation on opacity {
                        running: root.isRecording && !root.isPaused
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 800 }
                        NumberAnimation { to: 1.0; duration: 800 }
                    }
                }

                // Expand arrow
                DankIcon { name: "chevron_left"; size: 16; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property int startX: 0
                property int startY: 0
                property int startMarginR: 0
                property int startMarginT: 0
                property bool dragging: false

                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton && !dragging) {
                        recPill.recPillExpanded = true;
                    }
                }
                onPressed: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        dragging = true;
                        startX = mouse.x;
                        startY = mouse.y;
                        startMarginR = recPill.recPillMarginRight;
                        startMarginT = recPill.recPillMarginTop;
                        cursorShape = Qt.ClosedHandCursor;
                    }
                }
                onPositionChanged: function(mouse) {
                    if (dragging) {
                        let dx = mouse.x - startX;
                        let dy = mouse.y - startY;
                        recPill.recPillMarginRight = Math.max(4, startMarginR - dx);
                        recPill.recPillMarginTop = Math.max(4, startMarginT + dy);
                    }
                }
                onReleased: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        dragging = false;
                        cursorShape = Qt.PointingHandCursor;
                    }
                }
            }
        }

        // ---- Expanded: all controls + collapse arrow on right ----
        Item {
            anchors.fill: parent
            visible: recPill.recPillExpanded
            clip: true

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                // Pulsing red recording dot
                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: root.isPaused ? Theme.surfaceVariantText : "#FF4444"
                    SequentialAnimation on opacity {
                        running: root.isRecording && !root.isPaused
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 800 }
                        NumberAnimation { to: 1.0; duration: 800 }
                    }
                }

                // Timer
                StyledText {
                    text: root.formatTime(root.recordingElapsed)
                    font.pixelSize: 13
                    font.family: "monospace"
                    color: root.isPaused ? Theme.surfaceVariantText : Theme.surfaceText
                }

                Rectangle { width: 1; height: 24; color: Qt.rgba(1, 1, 1, 0.15) }

                // Pause / Resume
                Item {
                    width: 28; height: 28
                    Rectangle {
                        anchors.fill: parent; radius: 14
                        color: recPauseMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    DankIcon {
                        name: root.isPaused ? "play_arrow" : "pause"
                        size: 18; anchors.centerIn: parent; color: Theme.surfaceText
                    }
                    MouseArea {
                        id: recPauseMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.isPaused ? root.resumeRecording() : root.pauseRecording()
                    }
                }

                // Stop
                Item {
                    width: 28; height: 28
                    Rectangle {
                        anchors.fill: parent; radius: 14
                        color: recStopMa.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.25) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    DankIcon { name: "stop"; size: 18; anchors.centerIn: parent; color: "#FF4444" }
                    MouseArea {
                        id: recStopMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.stopRecording()
                    }
                }

                Rectangle { width: 1; height: 24; color: Qt.rgba(1, 1, 1, 0.15) }

                // Quick Screenshot
                Item {
                    width: 28; height: 28
                    Rectangle {
                        anchors.fill: parent; radius: 14
                        color: recSsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    DankIcon { name: "photo_camera"; size: 18; anchors.centerIn: parent; color: Theme.surfaceText }
                    MouseArea {
                        id: recSsMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let ssCmd = "dms screenshot";
                            ssCmd += root.showPointer ? " --cursor=on" : " --cursor=off";
                            ssCmd += " -f " + root.format;
                            Quickshell.execDetached(["bash", "-c", ssCmd]);
                        }
                    }
                }

                // Drag handle
                Item {
                    width: 28; height: 28
                    Rectangle {
                        anchors.fill: parent; radius: 14
                        color: recDragMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    DankIcon { name: "drag_indicator"; size: 18; anchors.centerIn: parent; color: Theme.surfaceVariantText }
                    MouseArea {
                        id: recDragMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property int startX: 0
                        property int startY: 0
                        property int startMarginR: 0
                        property int startMarginT: 0

                        onPressed: function(mouse) {
                            startX = mouse.x;
                            startY = mouse.y;
                            startMarginR = recPill.recPillMarginRight;
                            startMarginT = recPill.recPillMarginTop;
                        }
                        onPositionChanged: function(mouse) {
                            if (pressed) {
                                let dx = mouse.x - startX;
                                let dy = mouse.y - startY;
                                recPill.recPillMarginRight = Math.max(4, startMarginR - dx);
                                recPill.recPillMarginTop = Math.max(4, startMarginT + dy);
                            }
                        }
                    }
                }

                Rectangle { width: 1; height: 24; color: Qt.rgba(1, 1, 1, 0.15) }

                // Collapse arrow
                Item {
                    width: 24; height: 24
                    DankIcon { name: "chevron_right"; size: 16; anchors.centerIn: parent; color: Theme.surfaceVariantText }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: recPill.recPillExpanded = false
                    }
                }
            }
        }
    }
}
