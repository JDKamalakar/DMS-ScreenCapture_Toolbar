import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
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
    property string captureMode: (pluginData && pluginData.captureMode) || "interactive"
    property bool isVideoMode: false
    property bool settingsExpanded: false
    property bool delayExpanded: false

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
    readonly property string defaultPipeCommand: "{ mkdir -p \"$HOME/Pictures/Screenshots\"; satty --filename - --output-filename \"$HOME/Pictures/Screenshots/screenshot_$(date '+%Y-%m-%d_%H-%M-%S')_edit.png\"; }"
    property bool multiMonitorScreenshot: (pluginData && pluginData.multiMonitorScreenshot != null) ? pluginData.multiMonitorScreenshot : false

    // -- Video Settings ------------------------------------------------------
    property bool recordAudio: (pluginData && pluginData.recordAudio != null) ? pluginData.recordAudio : true
    property bool recordMic: (pluginData && pluginData.recordMic != null) ? pluginData.recordMic : false
    property string videoFormat: (pluginData && pluginData.videoFormat) || "mkv"
    property int videoFPS: (pluginData && pluginData.videoFPS) || 60
    property string videoCodec: (pluginData && pluginData.videoCodec) || "auto"
    property string videoCustomPath: (pluginData && pluginData.videoCustomPath) || ""
    property string videoFilename: (pluginData && pluginData.videoFilename) || ""
    property bool isRecording: false
    property bool isPaused: false
    property bool isMicCaptured: false
    property bool isMicMuted: false
    property int recordingElapsed: 0
    property var recordingProcess: null
    property bool showRecPill: (pluginData && pluginData.showRecPill !== undefined) ? pluginData.showRecPill : true
    property bool showNotify: (pluginData && pluginData.showNotify !== undefined) ? pluginData.showNotify : true
    property bool enableEditorShortcut: (pluginData && pluginData.enableEditorShortcut != null) ? pluginData.enableEditorShortcut : true
    property bool swapCaptureKeys: (pluginData && pluginData.swapCaptureKeys != null) ? pluginData.swapCaptureKeys : false
    property int delaySeconds: (pluginData && pluginData.delaySeconds != null) ? pluginData.delaySeconds : 0
    property real toolbarOpacity: (pluginData && pluginData.toolbarOpacity != null) ? pluginData.toolbarOpacity : 0.85
    property real pillOpacity: (pluginData && pluginData.pillOpacity != null) ? pluginData.pillOpacity : 0.92
    property string recPillScreenName: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    property int recPillX: -1
    property int recPillY: 12
    property bool recPillExpanded: false
    property bool recPillDragging: false
    property real recPillDragStartMouseX: 0
    property real recPillDragStartMouseY: 0
    property real recPillDragStartPillX: 0
    property real recPillDragStartPillY: 0
    property bool recPillDragStarted: false
    readonly property int recPillWindowWidth: 460
    readonly property int recPillWindowHeight: 60

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
            root.isMicCaptured = false;
            root.isMicMuted = false;
            root.recordingElapsed = 0;
            return "cancelled";
        }

        /** Show pill + timer only after region selection / portal begins recording (interactive video). Called from bash. */
        function recordingStarted(): string {
            root.isRecording = true;
            root.isPaused = false;
            root.recordingElapsed = 0;
            if (root.showNotify) {
                let dirMsg = root.videoCustomPath !== "" ? root.videoCustomPath : "~/Videos";
                Quickshell.execDetached(["notify-send", "Recording Started", "Saving to " + dirMsg]);
            }
            return "started";
        }
    }



    function open() {
        root.settingsExpanded = false;
        root.delayExpanded = false;
        overlay.visible = true;
        overlay.forceActiveFocus();
    }

    function close() {
        overlay.visible = false;
        root.settingsExpanded = false;
        root.delayExpanded = false;
    }

    function toggle() {
        if (overlay.visible) root.close();
        else root.open();
    }

    function _save(key, value) {
        if (typeof PluginService !== "undefined" && PluginService) {
            PluginService.savePluginData("screenCaptureToolbar", key, value);
            PluginService.setGlobalVar("screenCaptureToolbar", key, value);
        }
    }

    Connections {
        target: PluginService
        function onGlobalVarChanged(plugin, key, value) {
            if (plugin === "screenCaptureToolbar") {
                if (key === "copyToClipboard") root.copyToClipboard = value;
                else if (key === "saveToDisk") root.saveToDisk = value;
                else if (key === "stdout") root.stdout = value;
                else if (key === "recordAudio") root.recordAudio = value;
                else if (key === "recordMic") root.recordMic = value;
                else if (key === "showPointer") root.showPointer = value;
                else if (key === "showNotify") root.showNotify = value;
                else if (key === "showRecPill") root.showRecPill = value;
                else if (key === "captureMode") root.captureMode = value;
                else if (key === "format") root.format = value;
                else if (key === "quality") root.quality = value;
                else if (key === "customPath") root.customPath = value;
                else if (key === "enableEditorShortcut") root.enableEditorShortcut = value;
                else if (key === "swapCaptureKeys") root.swapCaptureKeys = value;
                else if (key === "delaySeconds") root.delaySeconds = value;
                else if (key === "videoFormat") root.videoFormat = value;
                else if (key === "videoFPS") root.videoFPS = value;
                else if (key === "videoCustomPath") root.videoCustomPath = value;
                else if (key === "videoFilename") root.videoFilename = value;
                else if (key === "pipeCommand") root.pipeCommand = value;
                else if (key === "toolbarOpacity") root.toolbarOpacity = value;
                else if (key === "pillOpacity") root.pillOpacity = value;
            }
        }
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function screenshotDir() {
        return root.customPath !== "" ? root.customPath : "~/Pictures/Screenshots";
    }

    function videoDir() {
        return root.videoCustomPath !== "" ? root.videoCustomPath : "~/Videos";
    }

    function expandHome(path) {
        return String(path).replace(/^~/, "$HOME");
    }

    function effectivePipeCommand() {
        return root.pipeCommand !== "" ? root.pipeCommand : root.defaultPipeCommand;
    }

    function editorExecutableName(command) {
        if (root.pipeCommand === "" && command === root.defaultPipeCommand) return "satty";
        let trimmed = String(command).trim();
        if (trimmed === "") return "";
        return trimmed.split(/\s+/)[0];
    }

    function editorAvailabilityGuard(command) {
        let executable = root.editorExecutableName(command);
        if (executable === "") return "";
        return "if ! command -v " + root.shellQuote(executable) + " >/dev/null 2>&1; then " +
               "notify-send " + root.shellQuote("Screenshot Editor Missing") + " " +
               root.shellQuote("Install " + executable + " or set Editor Pipe Command") + " 2>/dev/null || true; exit 1; fi; ";
    }

    function parseDateTemplate(template) {
        let now = new Date();
        function pad(value) { return value < 10 ? "0" + value : "" + value; }
        return String(template)
            .replace(/%Y/g, now.getFullYear())
            .replace(/%m/g, pad(now.getMonth() + 1))
            .replace(/%d/g, pad(now.getDate()))
            .replace(/%H/g, pad(now.getHours()))
            .replace(/%M/g, pad(now.getMinutes()))
            .replace(/%S/g, pad(now.getSeconds()));
    }

    function filenameTimestamp() {
        return root.parseDateTemplate("%Y-%m-%d_%H-%M-%S");
    }

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(value, maxValue));
    }

    function screenByName(name) {
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name) return Quickshell.screens[i];
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function recPillLocalX(screen) {
        if (!screen) return 12;
        let defaultX = Math.max(4, screen.width - root.recPillWindowWidth - 12);
        let x = root.recPillX >= 0 ? root.recPillX : defaultX;
        return clamp(x, 4, Math.max(4, screen.width - root.recPillWindowWidth - 4));
    }

    function recPillLocalY(screen) {
        if (!screen) return 12;
        return clamp(root.recPillY, 4, Math.max(4, screen.height - root.recPillWindowHeight - 4));
    }

    function screenForGlobalPoint(globalX, globalY) {
        for (let i = 0; i < Quickshell.screens.length; i++) {
            let candidate = Quickshell.screens[i];
            if (globalX >= candidate.x && globalX < candidate.x + candidate.width &&
                globalY >= candidate.y && globalY < candidate.y + candidate.height) {
                return candidate;
            }
        }
        return screenByName(root.recPillScreenName);
    }

    function beginRecPillDrag() {
        root.recPillDragging = true;
        root.recPillDragStarted = false;
    }

    function endRecPillDrag() {
        root.recPillDragging = false;
        root.recPillDragStarted = false;

        let screen = screenByName(root.recPillScreenName);
        if (screen) {
            let snapThreshold = 40;
            let leftLimit = 4;
            let rightLimit = Math.max(4, screen.width - root.recPillWindowWidth - 4);

            let isNearLeft = root.recPillX < (leftLimit + snapThreshold);
            let isNearRight = root.recPillX > (rightLimit - snapThreshold);

            if (isNearLeft || isNearRight) {
                root.recPillExpanded = false;
                if (isNearLeft) root.recPillX = leftLimit;
                if (isNearRight) root.recPillX = rightLimit;
            }

            root._save("recPillScreenName", root.recPillScreenName);
            root._save("recPillX", root.recPillX);
            root._save("recPillY", root.recPillY);
        }
    }

    function ensureRecPillScreen() {
        if (!screenByName(root.recPillScreenName) && Quickshell.screens.length > 0) {
            root.recPillScreenName = Quickshell.screens[0].name;
            root.recPillX = -1;
            root.recPillY = 12;
        }
    }

    function updateRecPillDrag(screen, localMouseX, localMouseY) {
        if (!screen) return;

        let globalMouseX = screen.x + localMouseX;
        let globalMouseY = screen.y + localMouseY;

        if (!root.recPillDragStarted) {
            let currentScreen = screenByName(root.recPillScreenName) || screen;
            root.recPillDragStartMouseX = globalMouseX;
            root.recPillDragStartMouseY = globalMouseY;
            root.recPillDragStartPillX = currentScreen.x + root.recPillLocalX(currentScreen);
            root.recPillDragStartPillY = currentScreen.y + root.recPillLocalY(currentScreen);
            root.recPillDragStarted = true;
            return;
        }

        let desiredGlobalX = root.recPillDragStartPillX + (globalMouseX - root.recPillDragStartMouseX);
        let desiredGlobalY = root.recPillDragStartPillY + (globalMouseY - root.recPillDragStartMouseY);
        let targetScreen = screenForGlobalPoint(globalMouseX, globalMouseY) || screen;

        root.recPillScreenName = targetScreen.name;
        root.recPillX = clamp(Math.round(desiredGlobalX - targetScreen.x), 4, Math.max(4, targetScreen.width - root.recPillWindowWidth - 4));
        root.recPillY = clamp(Math.round(desiredGlobalY - targetScreen.y), 4, Math.max(4, targetScreen.height - root.recPillWindowHeight - 4));
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.ensureRecPillScreen();
        }
    }

    onPluginDataChanged: {
        if (!pluginData) return;
        root.captureMode = pluginData.captureMode || "interactive";
        root.showPointer = pluginData.showPointer !== undefined ? pluginData.showPointer : true;
        root.saveToDisk = pluginData.saveToDisk !== undefined ? pluginData.saveToDisk : true;
        root.copyToClipboard = pluginData.copyToClipboard !== undefined ? pluginData.copyToClipboard : true;
        root.format = pluginData.format || "png";
        root.quality = pluginData.quality || 90;
        root.customPath = pluginData.customPath || "";
        root.stdout = pluginData.stdout !== undefined ? pluginData.stdout : false;
        root.pipeCommand = pluginData.pipeCommand || "";
        root.recordAudio = pluginData.recordAudio !== undefined ? pluginData.recordAudio : true;
        root.recordMic = pluginData.recordMic !== undefined ? pluginData.recordMic : false;
        root.videoFormat = pluginData.videoFormat || "mkv";
        root.videoFPS = pluginData.videoFPS || 60;
        root.videoCustomPath = pluginData.videoCustomPath || "";
        root.videoFilename = pluginData.videoFilename || "";
        root.showRecPill = pluginData.showRecPill !== undefined ? pluginData.showRecPill : true;
        root.showNotify = pluginData.showNotify !== undefined ? pluginData.showNotify : true;
        root.enableEditorShortcut = pluginData.enableEditorShortcut !== undefined ? pluginData.enableEditorShortcut : true;
        root.swapCaptureKeys = pluginData.swapCaptureKeys !== undefined ? pluginData.swapCaptureKeys : false;
        root.delaySeconds = pluginData.delaySeconds !== undefined ? pluginData.delaySeconds : 0;
        root.toolbarOpacity = pluginData.toolbarOpacity !== undefined ? pluginData.toolbarOpacity : 0.85;
        root.pillOpacity = pluginData.pillOpacity !== undefined ? pluginData.pillOpacity : 0.92;

        if (pluginData.recPillScreenName !== undefined) root.recPillScreenName = pluginData.recPillScreenName;
        if (pluginData.recPillX !== undefined) root.recPillX = pluginData.recPillX;
        if (pluginData.recPillY !== undefined) root.recPillY = pluginData.recPillY;
    }

    function performCapture(forceEdit = false) {
        if (root.isRecording) {
            root.stopRecording();
            return;
        }

        // Apply delay only for non-interactive screenshot modes
        let useDelay = !root.isVideoMode && root.captureMode !== "interactive" && root.delaySeconds > 0;
        
        if (useDelay) {
            root.close(); // Close immediately so it's not in the shot
            captureDelayTimer.forceEdit = forceEdit;
            captureDelayTimer.start();
        } else {
            root.handleCapture(root.captureMode, forceEdit);
        }
    }

    Timer {
        id: captureDelayTimer
        interval: root.delaySeconds * 1000
        repeat: false
        property bool forceEdit: false
        onTriggered: root.handleCapture(root.captureMode, forceEdit)
    }

    function handleCapture(mode, forceEdit = false) {
        if (mode) root.captureMode = mode;

        if (root.isVideoMode) {
            if (root.isRecording) {
                root.stopRecording();
            } else {
                root.startVideoRecording();
            }
        } else {
            root.takeScreenshot(forceEdit);
        }
    }

    function buildDmsScreenshotCommand(forceEditor) {
        let useStdout = forceEditor || (root.stdout && !root.enableEditorShortcut);
        let editorCommand = root.effectivePipeCommand();
        let dir = root.screenshotDir();
        let dmsStr = "dms screenshot";
        if (root.captureMode === "full") dmsStr += " full";
        else if (root.captureMode === "all") dmsStr += " all";
        else if (root.captureMode === "window") dmsStr += " window";

        dmsStr += root.showPointer ? " --cursor=on" : " --cursor=off";
        if (!root.saveToDisk) dmsStr += " --no-file";
        if (!root.copyToClipboard) dmsStr += " --no-clipboard";
        if (!root.showNotify) dmsStr += " --no-notify";
        if (useStdout) dmsStr += " --stdout";
        if (root.filename !== "") dmsStr += " --filename \"" + root.filename + "\"";

        dmsStr += " -f " + root.format;
        if (root.format === "jpg") dmsStr += " -q " + root.quality;

        dmsStr += " --dir \"" + root.expandHome(dir) + "\"";

        if (useStdout && editorCommand !== "") {
            dmsStr = root.editorAvailabilityGuard(editorCommand) + dmsStr + " | " + editorCommand;
        }

        return "mkdir -p \"" + root.expandHome(dir) + "\"; " + dmsStr;
    }

    function buildMultiMonitorScreenshotCommand(forceEditor) {
        let useStdout = forceEditor || (root.stdout && !root.enableEditorShortcut);
        let editorCommand = root.effectivePipeCommand();
        let dir = root.screenshotDir();
        let selectedFormat = root.format === "jpg" ? "jpeg" : root.format;
        let outputName = root.filename !== "" ? root.filename : "screenshot_" + root.filenameTimestamp() + "." + root.format;
        let outputPath = dir + "/" + outputName;
        let mimeType = root.format === "jpg" ? "image/jpeg" : (root.format === "ppm" ? "image/x-portable-pixmap" : "image/png");
        let grimArgs = "-g \"$REGION\" -t " + selectedFormat;

        if (root.showPointer) grimArgs += " -c";
        if (root.format === "jpg") grimArgs += " -q " + root.quality;

        let captureToFile = "grim " + grimArgs + " \"$OUT\"";
        let captureToStdout = "grim " + grimArgs + " -";
        let script =
            "sleep 0.2; " +
            (useStdout && editorCommand !== "" ? root.editorAvailabilityGuard(editorCommand) : "") +
            "if ! command -v slurp >/dev/null 2>&1 || ! command -v grim >/dev/null 2>&1; then " +
            root.buildDmsScreenshotCommand(forceEditor) + "; exit $?; " +
            "fi; " +
            "REGION=$(slurp -f '%x,%y %wx%h') || exit 1; " +
            "[ -z \"$REGION\" ] && exit 1; ";

        if (root.saveToDisk || (useStdout && editorCommand !== "")) {
            script += "DIR=" + root.shellQuote(dir) + "; OUT=" + root.shellQuote(outputPath) + "; DIR=\"${DIR/#\\~/$HOME}\"; OUT=\"${OUT/#\\~/$HOME}\"; mkdir -p \"$DIR\"; " + captureToFile + "; ";
            if (root.copyToClipboard) {
                script += "if command -v wl-copy >/dev/null 2>&1; then wl-copy -t " + root.shellQuote(mimeType) + " < \"$OUT\"; fi; ";
            }
            if (useStdout) {
                if (editorCommand !== "") script += "cat \"$OUT\" | " + editorCommand + "; ";
                else script += "cat \"$OUT\"; ";
            }
        } else if (useStdout && root.copyToClipboard) {
            script += "TMP=$(mktemp); trap 'rm -f \"$TMP\"' EXIT; OUT=\"$TMP\"; " + captureToFile + "; ";
            script += "if command -v wl-copy >/dev/null 2>&1; then wl-copy -t " + root.shellQuote(mimeType) + " < \"$TMP\"; fi; ";
            if (editorCommand !== "") script += "cat \"$TMP\" | " + editorCommand + "; ";
            else script += "cat \"$TMP\"; ";
        } else if (useStdout) {
            if (editorCommand !== "") script += captureToStdout + " | " + editorCommand + "; ";
            else script += captureToStdout + "; ";
        } else if (root.copyToClipboard) {
            script += "if command -v wl-copy >/dev/null 2>&1; then " + captureToStdout + " | wl-copy -t " + root.shellQuote(mimeType) + "; else " + captureToStdout + " >/dev/null; fi; ";
        } else {
            script += captureToStdout + " >/dev/null; ";
        }
        
        return script;
    }

    function takeScreenshot(forceEditor) {
        let screenshotCmd = (root.captureMode === "interactive" && root.multiMonitorScreenshot)
            ? root.buildMultiMonitorScreenshotCommand(forceEditor)
            : "sleep 0.2; " + root.buildDmsScreenshotCommand(forceEditor);

        // Close overlay immediately so interactive region selection works
        root.close();
        Quickshell.execDetached(["bash", "-c", screenshotCmd]);
    }

    function startVideoRecording() {
        root.isMicCaptured = root.recordMic;
        root.isMicMuted = false;
        if (root.recordMic) {
            Quickshell.execDetached(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "0"]);
        }
        let parsedFilename = root.videoFilename !== "" ? root.parseDateTemplate(root.videoFilename) : "";
        if (parsedFilename !== "" && parsedFilename.indexOf(".") === -1) parsedFilename += "." + root.videoFormat;
        let filename = parsedFilename !== "" ? parsedFilename : "recording_" + root.filenameTimestamp() + "." + root.videoFormat;
        let dir = root.expandHome(root.videoDir());
        let path = dir + "/" + filename;

        let prepends = [];
        prepends.push("export NIRI_SOCKET=$(ls /run/user/$(id -u)/niri*.sock 2>/dev/null | head -n 1)");
        if (root.recordAudio) {
            prepends.push("SINK=$(pactl get-default-sink 2>/dev/null); if [ -n \"$SINK\" ]; then SYSTEM_AUDIO=\"$SINK.monitor\"; else SYSTEM_AUDIO=\"default_output\"; fi");
        }
        if (root.recordMic) {
            prepends.push("MIC_AUDIO=$(pactl get-default-source 2>/dev/null); if [ -z \"$MIC_AUDIO\" ]; then MIC_AUDIO=\"default_input\"; fi");
        }
        prepends.push("MONITOR=\"\"; if command -v niri >/dev/null 2>&1; then MONITOR=$(niri msg -j outputs 2>/dev/null | jq -r 'keys[0]'); elif command -v hyprctl >/dev/null 2>&1; then MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name'); fi; if [ -z \"$MONITOR\" ] || [ \"$MONITOR\" = \"null\" ]; then MONITOR=\"portal\"; fi");

        let gsrSuffix = " -c " + root.videoFormat;
        gsrSuffix += " -f " + root.videoFPS;
        gsrSuffix += " -ac aac";

        let audioArgs = [];
        if (root.recordAudio) audioArgs.push("$SYSTEM_AUDIO");
        if (root.recordMic) audioArgs.push("$MIC_AUDIO");
        if (audioArgs.length > 0) {
            gsrSuffix += " -a \"" + audioArgs.join("|") + "\"";
        }

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
        Quickshell.execDetached(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "0"]);
        root.isRecording = false;
        root.isPaused = false;
        root.isMicCaptured = false;
        root.isMicMuted = false;
        root.recordingElapsed = 0;

        if (root.showNotify) {
            Quickshell.execDetached(["notify-send", "Recording Stopped", "Video saved to " + (root.videoCustomPath || "~/Videos")]);
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
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Space) {
                    event.accepted = true;
                    let isCtrl = !!(event.modifiers & Qt.ControlModifier);
                    let isSwap = !!root.swapCaptureKeys;
                    let editorOn = !!root.stdout;
                    let editorShortcutEnabled = !!root.enableEditorShortcut;
                    
                    if (!isSwap) {
                        // Standard: Space=Capture, Ctrl+Space=Edit
                        if (!isCtrl) {
                            root.performCapture(false);
                        } else if (editorOn && editorShortcutEnabled) {
                            root.performCapture(true);
                        }
                    } else {
                        // Swapped: Space=Edit, Ctrl+Space=Capture
                        if (isCtrl) {
                            root.performCapture(false);
                        } else if (editorOn && editorShortcutEnabled) {
                            root.performCapture(true);
                        }
                    }
                } else if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                }
            }
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
                color: Theme.withAlpha(Theme.surfaceContainerHighest || Theme.surfaceVariant || Theme.surface || "#303030", root.toolbarOpacity)
                border.width: 1
                border.color: Theme.withAlpha(Theme.outline || "#ffffff", 0.1)
                
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowVerticalOffset: 4
                    shadowBlur: 0.3
                    shadowColor: Qt.rgba(0,0,0,0.4)
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
                width: 340
                height: root.settingsExpanded ? settingsCol.implicitHeight + 40 : 0
                radius: 24
                color: Theme.withAlpha(Theme.surfaceContainerHigh || Theme.surfaceVariant || Theme.surface || "#252525", root.toolbarOpacity)
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
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowVerticalOffset: 8
                    shadowBlur: 0.5
                    shadowColor: Qt.rgba(0,0,0,0.5)
                }

                // Triangle pointer
                Rectangle {
                    width: 16; height: 16
                    color: settingsBubble.color
                    rotation: 45
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -8
                    anchors.right: parent.right
                    anchors.rightMargin: 92 // Adjusted for 340px width
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
                        color: Theme.withAlpha(Theme.secondary || "#404040", 0.06)
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.secondary || "#ffffff", 0.15)
                        clip: true

                        Column {
                            id: togglesCol
                            width: parent.width

                            SettingToggle {
                                label: "Copy to Clipboard"; iconName: "content_copy"; active: root.copyToClipboard
                                visible: !root.isVideoMode
                                onToggled: { root.copyToClipboard = !root.copyToClipboard; root._save("copyToClipboard", root.copyToClipboard) }
                            }
                            SettingToggle {
                                label: "Save to Disk"; iconName: "save"; active: root.saveToDisk
                                visible: !root.isVideoMode
                                onToggled: { root.saveToDisk = !root.saveToDisk; root._save("saveToDisk", root.saveToDisk) }
                            }
                            SettingToggle { 
                                label: "Screenshot Editor"; iconName: "output"; active: root.stdout
                                visible: !root.isVideoMode
                                onToggled: { root.stdout = !root.stdout; root._save("stdout", root.stdout) }
                            }
                            SettingToggle { 
                                label: "Enable Editor Shortcut"; iconName: "keyboard"; active: root.enableEditorShortcut
                                visible: !root.isVideoMode
                                onToggled: { root.enableEditorShortcut = !root.enableEditorShortcut; root._save("enableEditorShortcut", root.enableEditorShortcut) }
                            }
                            SettingToggle { 
                                label: "Swap Shortcuts"; iconName: "swap_horiz"; active: root.swapCaptureKeys
                                visible: !root.isVideoMode
                                onToggled: { root.swapCaptureKeys = !root.swapCaptureKeys; root._save("swapCaptureKeys", root.swapCaptureKeys) }
                            }
                            SettingToggle {
                                label: "Record System Audio"; iconName: "graphic_eq"; active: root.recordAudio
                                visible: root.isVideoMode
                                onToggled: { root.recordAudio = !root.recordAudio; root._save("recordAudio", root.recordAudio) }
                            }
                            SettingToggle {
                                label: "Record Microphone"; iconName: "mic"; active: root.recordMic
                                visible: root.isVideoMode
                                onToggled: { root.recordMic = !root.recordMic; root._save("recordMic", root.recordMic) }
                            }
                            SettingToggle {
                                label: "Show Mouse Pointer"; iconName: "mouse"; active: root.showPointer
                                onToggled: { root.showPointer = !root.showPointer; root._save("showPointer", root.showPointer) }
                            }
                            SettingToggle {
                                label: "Show Notification"; iconName: "notifications"; active: root.showNotify
                                onToggled: { root.showNotify = !root.showNotify; root._save("showNotify", root.showNotify) }
                            }
                            SettingToggle { 
                                label: "Show Recording Pill"; iconName: "smart_button"; active: root.showRecPill
                                visible: root.isVideoMode
                                isLast: true
                                onToggled: { root.showRecPill = !root.showRecPill; root._save("showRecPill", root.showRecPill) }
                            }
                        }
                    }

                    // Format Segment
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: formatCol.implicitHeight + 24
                        radius: 12
                        color: Theme.withAlpha(Theme.secondary || "#404040", 0.06)
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.secondary || "#ffffff", 0.15)
                        
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
                        color: Theme.withAlpha(Theme.secondary || "#404040", 0.06)
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.secondary || "#ffffff", 0.15)
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
                        color: Theme.withAlpha(Theme.secondary || "#404040", 0.06)
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.secondary || "#ffffff", 0.15)
                        
                        ColumnLayout {
                            id: pathCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8

                            RowLayout {
                                spacing: 12
                                DankIcon { name: "folder"; size: 18; color: Theme.surfaceVariantText }
                                StyledText { text: root.isVideoMode ? "Video Directory" : "Screenshot Directory"; font.pixelSize: 13; color: Theme.surfaceText; Layout.fillWidth: true }
                            }
                            DankTextField {
                                Layout.fillWidth: true; height: 28
                                font.pixelSize: 12
                                text: root.isVideoMode ? root.videoCustomPath : root.customPath
                                placeholderText: root.isVideoMode ? "~/Videos" : "~/Pictures/Screenshots"
                                onEditingFinished: {
                                    if (root.isVideoMode) {
                                        root.videoCustomPath = text;
                                        root._save("videoCustomPath", text);
                                    } else {
                                        root.customPath = text;
                                        root._save("customPath", text);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Delay Selection Bubble
            Rectangle {
                id: delayBubble
                width: 320
                height: root.delayExpanded ? delayCol.implicitHeight + 40 : 0
                radius: 24
                color: Theme.withAlpha(Theme.surfaceContainerHigh || Theme.surfaceVariant || Theme.surface || "#252525", root.toolbarOpacity)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.1)
                clip: true
                
                anchors.bottom: pillContainer.top
                anchors.bottomMargin: 24
                anchors.right: pillContainer.right
                anchors.rightMargin: 0 // Flush right to match settingsBubble
                
                opacity: root.delayExpanded ? 1 : 0
                scale: root.delayExpanded ? 1 : 0.9
                transformOrigin: Item.BottomRight
                
                Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                Behavior on opacity { NumberAnimation { duration: 250 } }
                Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowVerticalOffset: 8
                    shadowBlur: 0.5
                    shadowColor: Qt.rgba(0,0,0,0.5)
                }

                // Triangle pointer
                Rectangle {
                    width: 16; height: 16
                    color: delayBubble.color
                    rotation: 45
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -8
                    anchors.right: parent.right
                    anchors.rightMargin: 138 // Perfectly centered above the delay button
                    border.width: 1; border.color: delayBubble.border.color
                    z: -1
                }

                ColumnLayout {
                    id: delayCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 20
                    spacing: 12
                    
                    RowLayout {
                        spacing: 8
                        DankIcon { name: "timer"; size: 16; color: Theme.surfaceText }
                        StyledText { text: "Capture Delay"; font.bold: true; font.pixelSize: 15; color: Theme.surfaceText; Layout.fillWidth: true }
                    }

                    // Selection Segment
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: delayOptionsCol.implicitHeight
                        radius: 12
                        color: Theme.withAlpha(Theme.secondary || "#404040", 0.06)
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.secondary || "#ffffff", 0.15)
                        clip: true
                        
                        Column {
                            id: delayOptionsCol
                            width: parent.width
                            
                            Repeater {
                                model: [
                                    {label: "No Delay", value: 0, icon: "timer_off"},
                                    {label: "3 Seconds", value: 3, icon: "timer_3"},
                                    {label: "5 Seconds", value: 5, icon: "timer_5"},
                                    {label: "10 Seconds", value: 10, icon: "timer_10"}
                                ]
                                delegate: SettingToggle {
                                    label: modelData.label; iconName: modelData.icon
                                    active: root.delaySeconds === modelData.value
                                    isOption: true // Shows a checkmark instead of a switch
                                    isLast: index === 3
                                    onToggled: {
                                        root.delaySeconds = modelData.value;
                                        root._save("delaySeconds", root.delaySeconds);
                                        root.delayExpanded = false;
                                    }
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
                    color: Theme.withAlpha(Theme.surfaceContainerHigh || Theme.surfaceVariant || Theme.surface || "#252525", root.toolbarOpacity)
                    border.width: 1
                    border.color: Theme.withAlpha(Theme.outline || "#ffffff", 0.1)
                    
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowVerticalOffset: 8
                        shadowBlur: 0.4
                        shadowColor: Qt.rgba(0,0,0,0.3)
                    }
                }

                MouseArea {
                    id: toolbarMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: function(mouse) { mouse.accepted = true; }
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
                        
                        ToolbarBtn { 
                            id: delayBtn
                            visible: !root.isVideoMode && root.captureMode !== "interactive"
                            isFirst: true
                            iconName: "timer"
                            tooltipText: "Delay: " + root.delaySeconds + "s"
                            active: root.delayExpanded
                            onClicked: {
                                root.delayExpanded = !root.delayExpanded;
                                root.settingsExpanded = false;
                            }
                            
                            // Indicator Badge for Delay
                            Rectangle {
                                visible: root.delaySeconds > 0
                                width: 16; height: 16; radius: 8
                                color: Theme.primary
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                                anchors.right: parent.right; anchors.rightMargin: 2
                                border.width: 1.5; border.color: delayBtn.isDark ? "black" : "white"
                                z: 100
                                
                                StyledText {
                                    text: root.delaySeconds
                                    anchors.centerIn: parent
                                    font.pixelSize: 10; font.bold: true
                                    color: (Theme.surface.r + Theme.surface.g + Theme.surface.b < 1.5) ? "black" : "white"
                                }
                            }
                        }

                        ToolbarBtn { isFirst: !delayBtn.visible; id: settingsBtn; iconName: "settings"; active: root.settingsExpanded; onClicked: { root.settingsExpanded = !root.settingsExpanded; root.delayExpanded = false; } }
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
                color: Theme.withAlpha(Theme.surfaceContainerHigh || Theme.surfaceVariant || Theme.surface || "#252525", root.toolbarOpacity * 0.8)
                border.width: 1; border.color: Theme.withAlpha(Theme.outline || "#ffffff", 0.1)
                
                StyledText {
                    id: hintText
                    anchors.centerIn: parent
                    text: {
                        if (root.isVideoMode) return "Press Space To Record";
                        
                        let isSwap = !!root.swapCaptureKeys;
                        let editorOn = !!root.stdout;
                        let editorShortcutEnabled = !!root.enableEditorShortcut;
                        
                        let canEdit = editorOn && editorShortcutEnabled;
                        let spaceAction = isSwap ? (canEdit ? "Edit" : "") : "Capture";
                        let ctrlSpaceAction = isSwap ? "Capture" : (canEdit ? "Edit" : "");
                        
                        if (spaceAction && ctrlSpaceAction) 
                            return "Space: " + spaceAction + "  •  Ctrl+Space: " + ctrlSpaceAction;
                        
                        if (spaceAction) return "Space: " + spaceAction;
                        if (ctrlSpaceAction) return "Ctrl+Space: " + ctrlSpaceAction;
                        
                        return "No Actions Assigned";
                    }
                    font.pixelSize: 11; font.weight: Font.Medium
                    color: Theme.surfaceText || "#666666"
                }

                opacity: overlay.visible ? 1 : 0
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
                
                color: active ? Theme.withAlpha(Theme.primary || "#ffffff", 0.25) : 
                       (ma.containsMouse ? (hoverColor != "transparent" ? Theme.withAlpha(hoverColor, 0.2) : Theme.withAlpha(Theme.onSurface || "#ffffff", 0.05)) : Theme.withAlpha(Theme.onSurface || "#ffffff", 0.03))
                
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
        id: pillBtnRoot
        property string iconName: ""
        property real size: 40
        property real iconSize: 20
        property bool isDark: (Theme.surface.r + Theme.surface.g + Theme.surface.b < 1.5)
        property bool isActive: false
        signal clicked()

        width: visible ? size : 0; height: visible ? size : 0
        scale: ma.pressed ? 0.92 : (ma.containsMouse ? 1.08 : 1.0)
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

        Rectangle {
            anchors.fill: parent
            radius: isActive ? size / 2 : 12
            color: isActive ? (Theme.primary || "#38bdf8") : Theme.withAlpha(Theme.primary || "#ffffff", 0.25)
            clip: true

            Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
            Behavior on color { ColorAnimation { duration: 300 } }

            // Hover glow
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: isDark ? "black" : "white"
                opacity: ma.containsMouse ? 0.1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
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
            color: isActive
                ? (isDark ? "black" : "white")
                : ((ma.containsMouse || ma.pressed) ? "white" : Theme.primary)
            anchors.centerIn: parent
            rotation: (ma.containsMouse ? 8 : 0) + (isActive ? 360 : 0)
            Behavior on rotation { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 250 } }
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
        property bool isOption: false // If true, shows a dot instead of a switch
        property bool isLast: false
        signal toggled()

        width: parent.width; height: visible ? 44 : 0
        color: ma.containsMouse ? Theme.withAlpha(Theme.primary || "#ffffff", 0.08) : "transparent"
        clip: true
        radius: 12

        // Custom Ripple Effect
        Rectangle {
            id: toggleRipple
            anchors.centerIn: parent
            width: parent.width * 1.2; height: width
            radius: width / 2
            color: Theme.withAlpha(Theme.primary || "#ffffff", 0.12)
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
            DankIcon { name: toggleRoot.iconName; size: 18; color: toggleRoot.active ? Theme.primary : Theme.surfaceVariantText }
            StyledText { text: toggleRoot.label; font.pixelSize: 13; color: Theme.surfaceText; Layout.fillWidth: true }
            
            // Toggle Switch
            DankToggle { 
                visible: !toggleRoot.isOption
                scale: 0.85
                transformOrigin: Item.Right
                checked: toggleRoot.active
                onClicked: toggleRoot.toggled() // Ensure clicking the switch itself also works
            }
            
            // Radio/Option Indicator
            Rectangle {
                visible: toggleRoot.isOption
                width: 16; height: 16; radius: 8
                border.width: 1.5
                border.color: toggleRoot.active ? Theme.primary : Theme.withAlpha(Theme.outline || "#ffffff", 0.2)
                color: "transparent"
                
                Rectangle {
                    anchors.centerIn: parent
                    width: 8; height: 8; radius: 4
                    color: Theme.primary
                    visible: toggleRoot.active
                }
            }
        }

        Rectangle {
            width: parent.width; height: 1
            anchors.bottom: parent.bottom
            color: Theme.withAlpha(Theme.secondary || "#ffffff", 0.15)
            visible: !toggleRoot.isLast
        }

        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { toggleRoot.toggled(); }
        }
    }

    Component.onCompleted: {
        root.ensureRecPillScreen();
        console.info("screenCaptureToolbar: daemon loaded — use 'dms ipc screenCaptureToolbar toggle' to open");
    }

    DankTooltipV2 {
        id: legacyTooltip
        visible: false
    }

    // =========================================================================
    // Recording Control Pill — top-right, collapsible with drag support
    // =========================================================================
    // Fullscreen transparent overlays on every screen for cross-monitor dragging.
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: dragOverlay
            required property var modelData
            property var targetScreen: modelData

            screen: targetScreen
            visible: root.recPillDragging
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "dms-drag-overlay-" + targetScreen.name
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            MouseArea {
                anchors.fill: parent
                z: 3
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.ClosedHandCursor

                onPositionChanged: function(mouse) {
                    if (root.recPillDragging) {
                        root.updateRecPillDrag(dragOverlay.targetScreen, mouse.x, mouse.y);
                    }
                }
                onClicked: root.endRecPillDrag()
            }
        }
    }

    PanelWindow {
        id: recPill
        property var targetScreen: root.screenByName(root.recPillScreenName)

        screen: targetScreen
        visible: root.isRecording && root.showRecPill
        WlrLayershell.layer: root.recPillDragging ? WlrLayer.Top : WlrLayer.Overlay
        WlrLayershell.namespace: "dms-rec-pill"

        anchors {
            top: true
            left: true
        }
        margins {
            top: root.recPillLocalY(recPill.targetScreen)
            left: root.recPillLocalX(recPill.targetScreen)
        }

        width: root.recPillWindowWidth
        height: root.recPillWindowHeight
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
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowVerticalOffset: 2
                    shadowBlur: 0.2
                    shadowColor: Qt.rgba(0,0,0,0.4)
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

        property bool recPillExpanded: root.recPillExpanded
        readonly property bool isDark: (Theme.surface.r + Theme.surface.g + Theme.surface.b < 1.5)

        // width behavior handled by recPillBg now.

        // Timer handled by root state; drag is driven by the mouse areas below.

        Rectangle {
            id: recPillBg
            anchors.right: parent.right
            width: recPill.recPillExpanded ? (root.isMicCaptured ? 460 : 414) : 260
            height: parent.height
            radius: height / 2

            Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }

            // Fixed high opacity as requested, removing dependency on settings
            color: Theme.withAlpha(Theme.surface || "#ffffff", 0.98)
            border.width: root.recPillDragging ? 3 : 1
            border.color: root.recPillDragging ? (Theme.primary || "#38bdf8") : Qt.rgba(0, 0, 0, 0.1)
            
            Behavior on border.width { NumberAnimation { duration: 300 } }
            Behavior on border.color { ColorAnimation { duration: 300 } }
            
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
            enabled: !root.recPillDragging
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
                        name: "graphic_eq"; size: 18; color: Theme.withAlpha(Theme.primary || "#ffffff", 0.4)
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
                    root.recPillDragging ? root.endRecPillDrag() : root.beginRecPillDrag();
                }
            }

            // Tap to expand
            TapHandler {
                onTapped: root.recPillExpanded = true
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
                color: Theme.withAlpha(Theme.primary || "#ffffff", 0.1)
                scale: collapseMa.pressed ? 0.92 : (collapseMa.containsMouse ? 1.08 : 1.0)
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                DankIcon {
                    name: "chevron_left"; size: 18;
                    color: (collapseMa.containsMouse || collapseMa.pressed) ? (recPill.isDark ? "white" : "black") : Theme.primary
                    anchors.centerIn: parent
                    rotation: 180 + (collapseMa.containsMouse ? -12 : 0) // Points Left to Collapse + tilt
                    Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
                }
                MouseArea { id: collapseMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.recPillExpanded = false }
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
                        name: "graphic_eq"; size: 18; color: Theme.withAlpha(Theme.primary || "#ffffff", 0.5) 
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
                    iconName: root.isMicMuted ? "mic_off" : "mic"
                    visible: root.isMicCaptured
                    isActive: !root.isMicMuted
                    onClicked: {
                        root.isMicMuted = !root.isMicMuted;
                        if (root.isRecording) {
                            let muteVal = root.isMicMuted ? "1" : "0";
                            Quickshell.execDetached(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", muteVal]);
                        }
                    }
                }
                PillActionBtn {
                    iconName: "photo_camera"
                    onClicked: {
                        root.takeScreenshot();
                    }
                }
            }

            // Drag Handle (Moved to right)
            Rectangle {
                id: moveBtnRoot
                width: 40; height: 40; 
                radius: root.recPillDragging ? 20 : 12
                color: root.recPillDragging ? (Theme.primary || "#38bdf8") : Theme.withAlpha(Theme.primary || "#ffffff", 0.25)
                scale: moveMa.pressed ? 0.92 : (moveMa.containsMouse ? 1.08 : 1.0)
                clip: true

                Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 300 } }

                // Hover glow
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: recPill.isDark ? "black" : "white"
                    opacity: moveMa.containsMouse ? 0.1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
                }

                // DankRipple
                Rectangle {
                    id: moveRippleObj
                    anchors.centerIn: parent
                    width: parent.width * 1.5; height: width
                    radius: width / 2
                    color: recPill.isDark ? "black" : "white"
                    opacity: 0; scale: 0

                    states: State {
                        name: "pressed"; when: moveMa.pressed
                        PropertyChanges { target: moveRippleObj; opacity: 0.2; scale: 1 }
                    }
                    transitions: Transition {
                        NumberAnimation { properties: "opacity,scale"; duration: 400; easing.type: Easing.OutQuart }
                    }
                }

                DankIcon {
                    name: "open_with"; size: 16;
                    color: root.recPillDragging
                        ? (recPill.isDark ? "black" : "white")
                        : ((moveMa.containsMouse || moveMa.pressed) ? "white" : Theme.primary)
                    anchors.centerIn: parent
                    rotation: (moveMa.containsMouse ? 90 : 0) + (root.recPillDragging ? 360 : 0)
                    Behavior on rotation { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                MouseArea {
                    id: moveMa
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                    onClicked: function(mouse) {
                        root.recPillDragging ? root.endRecPillDrag() : root.beginRecPillDrag();
                    }
                }
            }
        }
    }
}
}
