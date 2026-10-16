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
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    // -- Internal State -------------------------------------------------------
    property string captureMode: (pluginData && pluginData.captureMode) || "interactive"
    property bool isVideoMode: (pluginData && pluginData.isVideoMode != null) ? pluginData.isVideoMode : (((pluginData && pluginData.mediaMode) || "photo") === "video")
    property bool settingsExpanded: false
    property bool delayExpanded: false
    property bool monitorExpanded: false
    property int monitorSelectedIndex: 0
    property int delaySelectedIndex: 0
    property bool enableController: (pluginData && pluginData.enableController !== undefined) ? pluginData.enableController : false
    property bool controllerConnected: false

    onSettingsExpandedChanged: {
        if (!settingsExpanded && !delayExpanded && !monitorExpanded) {
            globalKeyHandler.forceActiveFocus();
        }
    }
    onDelayExpandedChanged: {
        if (!settingsExpanded && !delayExpanded && !monitorExpanded) {
            globalKeyHandler.forceActiveFocus();
        }
    }
    onMonitorExpandedChanged: {
        if (!settingsExpanded && !delayExpanded && !monitorExpanded) {
            globalKeyHandler.forceActiveFocus();
        }
    }

    onVideoMonitorChanged: {
        for (var i = 0; i < monitorList.length; i++) {
            if (monitorList[i].value === videoMonitor) {
                monitorSelectedIndex = i;
                break;
            }
        }
    }

    onMonitorListChanged: {
        for (var i = 0; i < monitorList.length; i++) {
            if (monitorList[i].value === videoMonitor) {
                monitorSelectedIndex = i;
                return;
            }
        }
        monitorSelectedIndex = 0;
    }

    onDelaySecondsChanged: {
        var delays = [0, 3, 5, 10];
        var idx = delays.indexOf(delaySeconds);
        if (idx >= 0) {
            delaySelectedIndex = idx;
        }
    }

    onMonitorSelectedIndexChanged: {
        if (monitorSelectedIndex >= 0 && monitorSelectedIndex < monitorList.length) {
            var val = monitorList[monitorSelectedIndex].value;
            if (videoMonitor !== val) {
                videoMonitor = val;
                root._save("videoMonitor", videoMonitor);
            }
        }
    }

    onDelaySelectedIndexChanged: {
        var delays = [0, 3, 5, 10];
        if (delaySelectedIndex >= 0 && delaySelectedIndex < delays.length) {
            var val = delays[delaySelectedIndex];
            if (delaySeconds !== val) {
                delaySeconds = val;
                root._save("delaySeconds", delaySeconds);
            }
        }
    }

    // -- Screenshot Settings -------------------------------------------------
    property bool showPointer: (pluginData && pluginData.showPointer != null) ? pluginData.showPointer : true
    property bool saveToDisk: (pluginData && pluginData.saveToDisk != null) ? pluginData.saveToDisk : true
    property bool copyToClipboard: (pluginData && pluginData.copyToClipboard != null) ? pluginData.copyToClipboard : true
    property string format: (pluginData && pluginData.format) || "png"
    property int quality: (pluginData && pluginData.quality) || 90
    property string customPath: (pluginData && pluginData.customPath) || ""
    property string filename: (pluginData && pluginData.filename) || ""
    property int scrollInterval: (pluginData && pluginData.scrollInterval != null) ? pluginData.scrollInterval : 45
    property bool stdout: (pluginData && pluginData.stdout != null) ? pluginData.stdout : false
    property string pipeCommand: (pluginData && pluginData.pipeCommand) || ""
    readonly property string defaultPipeCommand: "{ mkdir -p \"$HOME/Pictures/Screenshots\"; satty --filename - --output-filename \"$HOME/Pictures/Screenshots/screenshot_$(date '+%Y-%m-%d_%H-%M-%S')_edit.png\"; }"

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

    readonly property string micTestFile: runtimeDir + "/dms_mic_test.wav"
    readonly property string micTestStopFile: runtimeDir + "/dms_mic_stop"

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

    Process {
        id: micTestStopProcess
        command: ["bash", "-c", "touch " + root.shellQuote(root.micTestStopFile)]
        running: false
    }

    property bool multiMonitorScreenshot: (pluginData && pluginData.multiMonitorScreenshot != null) ? pluginData.multiMonitorScreenshot : false

    // -- Video Settings ------------------------------------------------------
    property bool recordAudio: (pluginData && pluginData.recordAudio != null) ? pluginData.recordAudio : true
    property bool recordMic: (pluginData && pluginData.recordMic != null) ? pluginData.recordMic : false
    property string videoFormat: (pluginData && pluginData.videoFormat) || "mkv"
    property int videoFPS: (pluginData && pluginData.videoFPS) || 60
    property string videoCodec: (pluginData && pluginData.videoCodec) || "auto"
    property string audioCodec: (pluginData && pluginData.audioCodec) || "aac"
    property bool showAdvancedSettings: (pluginData && pluginData.showAdvancedSettings != null) ? pluginData.showAdvancedSettings : false
    property string videoCustomPath: (pluginData && pluginData.videoCustomPath) || ""
    property string videoFilename: (pluginData && pluginData.videoFilename) || ""
    property string videoQuality: (pluginData && pluginData.videoQuality) || "medium"
    property string videoMonitor: (pluginData && pluginData.videoMonitor === "default") ? "Focused" : ((pluginData && pluginData.videoMonitor) || "Focused")
    property string videoMic: (pluginData && pluginData.videoMic) || "default"
    property string lastSavedVideoPath: ""

    // -- Standalone Audio Recorder Settings ----------------------------------
    property bool enableAudioRecorder: (pluginData && pluginData.enableAudioRecorder != null) ? pluginData.enableAudioRecorder : false
    onEnableAudioRecorderChanged: {
        if (!enableAudioRecorder && mediaMode === "audio") {
            mediaMode = "photo";
            isVideoMode = false;
            _save("mediaMode", "photo");
            _save("isVideoMode", false);
        }
    }
    property string mediaMode: (!enableAudioRecorder && (pluginData && pluginData.mediaMode === "audio")) ? "photo" : ((pluginData && pluginData.mediaMode) ? pluginData.mediaMode : "photo") // "photo", "video", "audio"
    property string audioFormat: (pluginData && pluginData.audioFormat) || "mp3"
    property string audioSource: (pluginData && pluginData.audioSource) || "mic" // "mic", "system", "both"
    property string audioCustomPath: (pluginData && pluginData.audioCustomPath) || ""
    property string audioFilename: (pluginData && pluginData.audioFilename) || ""
    property string audioBitrate: (pluginData && pluginData.audioBitrate) || "192k"
    property string lastSavedAudioPath: ""
    property bool isAudioRecording: false

    property bool isRecording: false
    property bool isPaused: false
    property bool isMicCaptured: false
    property bool isMicMuted: false
    property int recordingElapsed: 0
    property int recorderPid: 0
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/" + (Quickshell.env("UID") || "1000")
    readonly property string recorderPidFile: runtimeDir + "/dms_recorder.pid"
    property var recordingProcess: null
    property bool showRecPill: (pluginData && pluginData.showRecPill !== undefined) ? pluginData.showRecPill : true
    property bool showNotify: (pluginData && pluginData.showNotify !== undefined) ? pluginData.showNotify : true
    property bool copyPathOnCapture: (pluginData && pluginData.copyPathOnCapture !== undefined) ? pluginData.copyPathOnCapture : true
    property bool copyVideoFile: (pluginData && pluginData.copyVideoFile !== undefined) ? pluginData.copyVideoFile : false
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
    property bool _isSavingDrag: false
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

        function debugCapture(): string {
            root.performCapture(false);
            return "triggered";
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

        /** Store PID of spawned recorder for targeted signal handling */
        function onRecorderStarted(pid: string): string {
            let parsed = parseInt(pid);
            if (!isNaN(parsed) && parsed > 0) {
                root.recorderPid = parsed;
            }
            return "pid_recorded";
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

        function controllerToggle(): string {
            if (!root.enableController) return "controller disabled";
            if (overlay.visible) {
                root.close();
                return "closed";
            } else {
                root.captureMode = "monitor";
                root.videoMonitor = "Focused";
                root._save("captureMode", "monitor");
                root._save("videoMonitor", "Focused");
                root.open();
                return "opened";
            }
        }

        function controllerConnectionChange(connectedStr): string {
            root.controllerConnected = (connectedStr === "true");
            return "status updated";
        }

        function controllerActionA(): string {
            if (!root.enableController) return "controller disabled";
            if (!overlay.visible) return "toolbar not open";
            
            if (root.settingsExpanded || root.delayExpanded || root.monitorExpanded) {
                Quickshell.execDetached(["wtype", "-k", "Return"]);
                return "A executed (selected popup item)";
            }
            
            root.performCapture(false);
            return "A executed";
        }

        function controllerActionB(): string {
            if (!root.enableController) return "controller disabled";
            if (!overlay.visible) return "toolbar not open";
            if (root.settingsExpanded) { root.settingsExpanded = false; return "settings closed"; }
            if (root.delayExpanded) { root.delayExpanded = false; return "delay closed"; }
            if (root.monitorExpanded) { root.monitorExpanded = false; return "monitor closed"; }
            root.close();
            return "B executed";
        }

        function controllerActionHOME(): string {
            if (!root.enableController) return "controller disabled";
            if (root.isRecording) {
                root.stopRecording();
                return "HOME executed (stopped recording)";
            }
            return "HOME executed";
        }

        function controllerActionUP(): string {
            if (!root.enableController || !overlay.visible) return "";
            if (root.settingsExpanded || root.delayExpanded || root.monitorExpanded) {
                if (root.monitorExpanded) {
                    root.monitorSelectedIndex = Math.max(0, root.monitorSelectedIndex - 1);
                } else if (root.delayExpanded) {
                    root.delaySelectedIndex = Math.max(0, root.delaySelectedIndex - 1);
                } else {
                    Quickshell.execDetached(["wtype", "-M", "shift", "-k", "Tab", "-m", "shift"]);
                }
                return "UP navigated";
            }
            root.settingsExpanded = false;
            root.delayExpanded = false;
            root.monitorExpanded = !root.monitorExpanded;
            root.monitorSelectedIndex = 0;
            return "UP executed";
        }

        function controllerActionDOWN(): string {
            if (!root.enableController || !overlay.visible) return "";
            if (root.settingsExpanded || root.delayExpanded || root.monitorExpanded) {
                if (root.monitorExpanded) {
                    root.monitorSelectedIndex = Math.min(root.monitorList.length - 1, root.monitorSelectedIndex + 1);
                } else if (root.delayExpanded) {
                    root.delaySelectedIndex = Math.min(3, root.delaySelectedIndex + 1); // 4 items (0 to 3)
                } else {
                    Quickshell.execDetached(["wtype", "-k", "Tab"]);
                }
                return "DOWN navigated";
            }
            root.monitorExpanded = false;
            root.delayExpanded = false;
            root.settingsExpanded = !root.settingsExpanded;
            return "DOWN executed";
        }

        function controllerActionRIGHT(): string {
            if (!root.enableController || !overlay.visible) return "";
            if (root.settingsExpanded || root.delayExpanded || root.monitorExpanded) {
                Quickshell.execDetached(["wtype", "-k", "Right"]);
                return "RIGHT navigated";
            }
            if (!root.isVideoMode) {
                root.settingsExpanded = false;
                root.monitorExpanded = false;
                root.delayExpanded = !root.delayExpanded;
            }
            return "RIGHT executed";
        }

        function controllerActionLEFT(): string {
            if (!root.enableController || !overlay.visible) return "";
            if (root.settingsExpanded || root.delayExpanded || root.monitorExpanded) {
                Quickshell.execDetached(["wtype", "-k", "Left"]);
                return "LEFT navigated";
            }
            return "LEFT executed";
        }

        function controllerActionRT(): string {
            if (!root.enableController) return "controller disabled";
            if (!overlay.visible) return "toolbar not open";
            root.isVideoMode = true;
            return "RT executed";
        }

        function controllerActionLT(): string {
            if (!root.enableController) return "controller disabled";
            if (!overlay.visible) return "toolbar not open";
            root.isVideoMode = false;
            return "LT executed";
        }

        function controllerActionRB(): string {
            if (!root.enableController) return "controller disabled";
            if (!overlay.visible) return "toolbar not open";
            let modes = root.isVideoMode ? ["interactive", "monitor", "all"] : ["interactive", "monitor", "window", "all", "scroll"];
            let idx = modes.indexOf(root.captureMode);
            if (idx === -1) idx = 0;
            idx = (idx + 1) % modes.length;
            root.captureMode = modes[idx];
            root._save("captureMode", root.captureMode);
            return "RB executed";
        }

        function controllerActionLB(): string {
            if (!root.enableController) return "controller disabled";
            if (!overlay.visible) return "toolbar not open";
            let modes = root.isVideoMode ? ["interactive", "monitor", "all"] : ["interactive", "monitor", "window", "all", "scroll"];
            let idx = modes.indexOf(root.captureMode);
            if (idx === -1) idx = 0;
            idx = (idx - 1 + modes.length) % modes.length;
            root.captureMode = modes[idx];
            root._save("captureMode", root.captureMode);
            return "LB executed";
        }
    }



    function open() {
        if (typeof PluginService !== "undefined" && PluginService && PluginService.loadPluginData) {
            root.enableAudioRecorder = PluginService.loadPluginData("screenCaptureToolbar", "enableAudioRecorder", false);
        }
        root.settingsExpanded = false;
        root.delayExpanded = false;
        root.monitorExpanded = false;
        overlay.visible = true;
        globalKeyHandler.forceActiveFocus();
    }

    function close() {
        overlay.visible = false;
        root.settingsExpanded = false;
        root.delayExpanded = false;
        root.monitorExpanded = false;
    }

    function toggle() {
        if (overlay.visible) close();
        else open();
    }

    Process {
        id: gamepadProcess
        command: ["python3", Qt.resolvedUrl("./gamepad_listener.py").toString().replace(/^file:\/\//, "")]
        running: root.enableController
    }

    function _save(key, value) {
        if (root.pluginService) {
            root.pluginService.savePluginData("screenCaptureToolbar", key, value);
            root.pluginService.setGlobalVar("screenCaptureToolbar", key, value);
        }
    }

    function getMonitorLabel(val) {
        for (let i = 0; i < root.monitorList.length; i++) {
            if (root.monitorList[i].value === val) return root.monitorList[i].label;
        }
        return val;
    }

    Connections {
        target: (typeof PluginService !== "undefined" && PluginService) ? PluginService : root.pluginService
        ignoreUnknownSignals: true
        function onGlobalVarChanged(plugin, key) {
            if (plugin === "screenCaptureToolbar") {
                const svc = (typeof PluginService !== "undefined" && PluginService) ? PluginService : root.pluginService;
                if (!svc) return;
                const value = svc.getGlobalVar(plugin, key, undefined);
                if (value === undefined) return;

                if (key === "copyToClipboard") root.copyToClipboard = value;
                else if (key === "saveToDisk") root.saveToDisk = value;
                else if (key === "stdout") root.stdout = value;
                else if (key === "recordAudio") root.recordAudio = value;
                else if (key === "recordMic") root.recordMic = value;
                else if (key === "showPointer") root.showPointer = value;
                else if (key === "showNotify") root.showNotify = value;
                else if (key === "showRecPill") root.showRecPill = value;
                else if (key === "copyPathOnCapture") root.copyPathOnCapture = value;
                else if (key === "copyVideoFile") root.copyVideoFile = value;
                else if (key === "enableController") root.enableController = value;
                else if (key === "captureMode") root.captureMode = value;
                else if (key === "format") root.format = value;
                else if (key === "quality") root.quality = value;
                else if (key === "customPath") root.customPath = value;
                else if (key === "scrollInterval") root.scrollInterval = value;
                else if (key === "enableEditorShortcut") root.enableEditorShortcut = value;
                else if (key === "swapCaptureKeys") root.swapCaptureKeys = value;
                else if (key === "delaySeconds") root.delaySeconds = value;
                else if (key === "videoFormat") root.videoFormat = value;
                else if (key === "videoFPS") root.videoFPS = value;
                else if (key === "videoCustomPath") root.videoCustomPath = value;
                else if (key === "videoFilename") root.videoFilename = value;
                else if (key === "videoQuality") root.videoQuality = value;
                else if (key === "videoMonitor") root.videoMonitor = value;
                else if (key === "videoMic") root.videoMic = value;
                else if (key === "showAdvancedSettings") root.showAdvancedSettings = value;
                else if (key === "enableAudioRecorder") root.enableAudioRecorder = value;
                else if (key === "audioFormat") root.audioFormat = value;
                else if (key === "audioSource") root.audioSource = value;
                else if (key === "audioCustomPath") root.audioCustomPath = value;
                else if (key === "audioFilename") root.audioFilename = value;
                else if (key === "audioBitrate") root.audioBitrate = value;
                else if (key === "mediaMode") {
                    root.mediaMode = value;
                    root.isVideoMode = (value === "video");
                }
                else if (key === "isVideoMode") {
                    root.isVideoMode = value;
                    if (value) root.mediaMode = "video";
                    else if (root.mediaMode === "video") root.mediaMode = "photo";
                }
                else if (key === "pipeCommand") root.pipeCommand = value;
                else if (key === "toolbarOpacity") root.toolbarOpacity = value;
                else if (key === "pillOpacity") root.pillOpacity = value;
            }
        }
        function onPluginDataChanged(pluginId) {
            if (pluginId === "screenCaptureToolbar") {
                const svc = (typeof PluginService !== "undefined" && PluginService) ? PluginService : root.pluginService;
                if (!svc || !svc.loadPluginData) return;
                root.enableAudioRecorder = svc.loadPluginData("screenCaptureToolbar", "enableAudioRecorder", false);
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

    function audioDir() {
        return root.audioCustomPath !== "" ? root.audioCustomPath : "~/Music";
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
        root._isSavingDrag = true;
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
        root._isSavingDrag = false;
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
        if (!overlay || !overlay.visible) {
            root.captureMode = pluginData.captureMode || "interactive";
            root.mediaMode = (!root.enableAudioRecorder && pluginData.mediaMode === "audio") ? "photo" : (pluginData.mediaMode || "photo");
            root.isVideoMode = pluginData.isVideoMode !== undefined ? pluginData.isVideoMode : (root.mediaMode === "video");
        }
        root.showPointer = pluginData.showPointer !== undefined ? pluginData.showPointer : true;
        root.saveToDisk = pluginData.saveToDisk !== undefined ? pluginData.saveToDisk : true;
        root.copyToClipboard = pluginData.copyToClipboard !== undefined ? pluginData.copyToClipboard : true;
        root.format = pluginData.format || "png";
        root.quality = pluginData.quality || 90;
        root.customPath = pluginData.customPath || "";
        root.scrollInterval = pluginData.scrollInterval !== undefined ? pluginData.scrollInterval : 45;
        root.stdout = pluginData.stdout !== undefined ? pluginData.stdout : false;
        root.pipeCommand = pluginData.pipeCommand || "";
        root.recordAudio = pluginData.recordAudio !== undefined ? pluginData.recordAudio : true;
        root.recordMic = pluginData.recordMic !== undefined ? pluginData.recordMic : false;
        root.videoFormat = pluginData.videoFormat || "mkv";
        root.videoFPS = pluginData.videoFPS || 60;
        root.videoCustomPath = pluginData.videoCustomPath || "";
        root.videoFilename = pluginData.videoFilename || "";
        root.videoQuality = pluginData.videoQuality || "medium";
        root.videoMonitor = (pluginData.videoMonitor === "default") ? "Focused" : (pluginData.videoMonitor || "Focused");
        root.videoMic = pluginData.videoMic || "default";
        root.showAdvancedSettings = pluginData.showAdvancedSettings !== undefined ? pluginData.showAdvancedSettings : false;
        root.copyVideoFile = pluginData.copyVideoFile !== undefined ? pluginData.copyVideoFile : false;
        root.copyPathOnCapture = pluginData.copyPathOnCapture !== undefined ? pluginData.copyPathOnCapture : true;

        root.enableAudioRecorder = pluginData.enableAudioRecorder !== undefined ? pluginData.enableAudioRecorder : false;
        root.audioFormat = pluginData.audioFormat || "mp3";
        root.audioSource = pluginData.audioSource || "mic";
        root.audioCustomPath = pluginData.audioCustomPath || "";
        root.audioFilename = pluginData.audioFilename || "";
        root.audioBitrate = pluginData.audioBitrate || "192k";

        root.showRecPill = pluginData.showRecPill !== undefined ? pluginData.showRecPill : true;
        root.enableController = pluginData.enableController !== undefined ? pluginData.enableController : false;
        root.showNotify = pluginData.showNotify !== undefined ? pluginData.showNotify : true;
        root.enableEditorShortcut = pluginData.enableEditorShortcut !== undefined ? pluginData.enableEditorShortcut : true;
        root.swapCaptureKeys = pluginData.swapCaptureKeys !== undefined ? pluginData.swapCaptureKeys : false;
        root.delaySeconds = pluginData.delaySeconds !== undefined ? pluginData.delaySeconds : 0;
        root.toolbarOpacity = pluginData.toolbarOpacity !== undefined ? pluginData.toolbarOpacity : 0.85;
        root.pillOpacity = pluginData.pillOpacity !== undefined ? pluginData.pillOpacity : 0.92;

        if (!root._isSavingDrag) {
            if (pluginData.recPillScreenName !== undefined) root.recPillScreenName = pluginData.recPillScreenName;
            if (pluginData.recPillX !== undefined) root.recPillX = pluginData.recPillX;
            if (pluginData.recPillY !== undefined) root.recPillY = pluginData.recPillY;
        }
    }

    function performCapture(forceEdit = false) {
        if (root.isRecording) {
            root.stopRecording();
            return;
        }

        // Apply delay for capture/recording modes
        let useDelay = root.delaySeconds > 0;
        
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

        if (root.mediaMode === "audio") {
            if (root.isRecording) {
                root.stopRecording();
            } else {
                root.startAudioRecording();
            }
        } else if (root.isVideoMode) {
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
        else if (root.captureMode === "monitor") {
            if (root.videoMonitor === "Focused" || root.videoMonitor === "default") {
                dmsStr += " full";
            } else {
                dmsStr += " output -o " + root.videoMonitor;
            }
        }
        else if (root.captureMode === "all") dmsStr += " all";
        else if (root.captureMode === "window") dmsStr += " window";
        else if (root.captureMode === "scroll") {
            dmsStr += " scroll";
            let interval = (root.scrollInterval && root.scrollInterval >= 30 && root.scrollInterval <= 1000) ? root.scrollInterval : 45;
            dmsStr += " --interval " + interval;
        }

        dmsStr += root.showPointer ? " --cursor=on" : " --cursor=off";
        if (!root.saveToDisk) dmsStr += " --no-file";
        if (!root.copyToClipboard) dmsStr += " --no-clipboard";
        if (!root.showNotify) dmsStr += " --no-notify";
        if (useStdout) dmsStr += " --stdout";
        
        let generatedName = root.filename !== "" ? root.filename : "screenshot_" + root.filenameTimestamp() + "." + root.format;
        dmsStr += " --filename \"" + generatedName + "\"";

        dmsStr += " -f " + root.format;
        if (root.format === "jpg") dmsStr += " -q " + root.quality;

        dmsStr += " --dir \"" + root.expandHome(dir) + "\"";

        if (useStdout && editorCommand !== "") {
            dmsStr = root.editorAvailabilityGuard(editorCommand) + dmsStr + " | " + editorCommand;
        }

        let cmd = "mkdir -p \"" + root.expandHome(dir) + "\" && " + dmsStr;
        if (root.copyPathOnCapture && root.saveToDisk) {
            let finalPath = root.expandHome(dir) + "/" + generatedName;
            cmd += " && if command -v wl-copy >/dev/null 2>&1; then FILE=" + root.shellQuote(finalPath) + "; FILE=\"${FILE/#\\$HOME/$HOME}\"; echo -n \"$FILE\" | wl-copy; fi";
        }
        return cmd;
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
            if (root.copyPathOnCapture) {
                script += "if command -v wl-copy >/dev/null 2>&1; then echo -n \"$OUT\" | wl-copy; fi; ";
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
        prepends.push("[ -z \"$XDG_RUNTIME_DIR\" ] && export XDG_RUNTIME_DIR=/run/user/$(id -u)");
        prepends.push("if [ -z \"$WAYLAND_DISPLAY\" ]; then W_SOCKET=$(ls /run/user/$(id -u)/wayland-[0-9]* 2>/dev/null | head -n 1); [ -n \"$W_SOCKET\" ] && export WAYLAND_DISPLAY=$(basename \"$W_SOCKET\"); fi");
        prepends.push("export NIRI_SOCKET=$(ls /run/user/$(id -u)/niri*.sock 2>/dev/null | head -n 1)");
        if (root.recordAudio) {
            prepends.push("SINK=$(pactl get-default-sink 2>/dev/null); if [ -n \"$SINK\" ]; then SYSTEM_AUDIO=\"$SINK.monitor\"; else SYSTEM_AUDIO=\"default_output\"; fi");
        }
        if (root.recordMic) {
            prepends.push("MIC_AUDIO=$(pactl get-default-source 2>/dev/null); if [ -z \"$MIC_AUDIO\" ]; then MIC_AUDIO=\"default_input\"; fi");
        }
        prepends.push("MONITOR=\"\"; if command -v niri >/dev/null 2>&1; then MONITOR=$(niri msg -j focused-output 2>/dev/null | jq -r '.name'); elif command -v hyprctl >/dev/null 2>&1; then MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name'); fi; if [ -z \"$MONITOR\" ] || [ \"$MONITOR\" = \"null\" ]; then MONITOR=\"portal\"; fi");

        let gsrSuffix = " -c " + root.videoFormat;
        if (root.videoQuality !== "" && root.videoQuality !== "default")
            gsrSuffix += " -q " + root.videoQuality;

        gsrSuffix += " -f " + root.videoFPS;
        gsrSuffix += " -ac " + root.audioCodec;

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
        let notifyStartPid = "command -v dms >/dev/null 2>&1 && ( dms ipc call screenCaptureToolbar onRecorderStarted \"$REC_PID\" 2>/dev/null || dms ipc screenCaptureToolbar onRecorderStarted \"$REC_PID\" 2>/dev/null ); ";
        let scriptBody = "";
        if (root.captureMode === "interactive") {
            // Portal alone is unreliable on niri / some Wayland compositors; use slurp + -w region when available.
            scriptBody =
                "cancel_rec() { command -v dms >/dev/null 2>&1 && ( dms ipc call screenCaptureToolbar cancelRecording 2>/dev/null || dms ipc screenCaptureToolbar cancelRecording 2>/dev/null ); }; " +
                "start_rec() { command -v dms >/dev/null 2>&1 && ( dms ipc call screenCaptureToolbar recordingStarted 2>/dev/null || dms ipc screenCaptureToolbar recordingStarted 2>/dev/null ); }; " +
                "mkdir -p \"" + dir + "\"; " +
                "if command -v slurp >/dev/null 2>&1; then " +
                "REGION=$(slurp -f '%wx%h+%x+%y') || { cancel_rec; exit 1; }; " +
                "[ -z \"$REGION\" ] && { cancel_rec; exit 1; }; " +
                "start_rec; gpu-screen-recorder -w region -region \"$REGION\"" + gsrSuffix + " & REC_PID=$!; " +
                "echo \"$REC_PID\" > " + root.shellQuote(root.recorderPidFile) + "; " + notifyStartPid + "wait $REC_PID; rm -f " + root.shellQuote(root.recorderPidFile) + "; " +
                "else " +
                "start_rec; gpu-screen-recorder -w portal" + gsrSuffix + " & REC_PID=$!; " +
                "echo \"$REC_PID\" > " + root.shellQuote(root.recorderPidFile) + "; " + notifyStartPid + "wait $REC_PID; rm -f " + root.shellQuote(root.recorderPidFile) + "; " +
                "fi";
        } else if (root.captureMode === "all") {
            scriptBody = "mkdir -p \"" + dir + "\"; " +
                "HAS_PORTAL=\"\"; " +
                "if command -v dbus-send >/dev/null 2>&1; then " +
                "dbus-send --dest=org.freedesktop.portal.Desktop --print-reply /org/freedesktop/portal/desktop org.freedesktop.DBus.Introspectable.Introspect 2>/dev/null | grep -q \"org.freedesktop.portal.ScreenCast\" && HAS_PORTAL=\"1\"; " +
                "elif command -v busctl >/dev/null 2>&1; then " +
                "busctl introspect org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop 2>/dev/null | grep -q \"org.freedesktop.portal.ScreenCast\" && HAS_PORTAL=\"1\"; " +
                "fi; " +
                "if [ -n \"$HAS_PORTAL\" ] && { [ \"$XDG_SESSION_TYPE\" = \"wayland\" ] || [ -n \"$WAYLAND_DISPLAY\" ]; }; then " +
                "gpu-screen-recorder -w portal" + gsrSuffix + " & REC_PID=$!; " +
                "elif [ \"$XDG_SESSION_TYPE\" = \"wayland\" ] || [ -n \"$WAYLAND_DISPLAY\" ]; then " +
                "notify-send \"Multi-Monitor Recording\" \"Recording focused screen. Install a desktop portal (e.g. xdg-desktop-portal-niri) to record all screens on Wayland.\" -t 5000; " +
                "gpu-screen-recorder -w \"$MONITOR\"" + gsrSuffix + " & REC_PID=$!; " +
                "else " +
                "gpu-screen-recorder -w screen" + gsrSuffix + " & REC_PID=$!; " +
                "fi; " +
                "echo \"$REC_PID\" > " + root.shellQuote(root.recorderPidFile) + "; " + notifyStartPid + "wait $REC_PID; rm -f " + root.shellQuote(root.recorderPidFile) + "; ";
        } else if (root.captureMode === "monitor") {
            let mon = (root.videoMonitor !== "Focused" && root.videoMonitor !== "default") ? root.videoMonitor : "\"$MONITOR\"";
            scriptBody = "mkdir -p \"" + dir + "\"; gpu-screen-recorder -w " + mon + gsrSuffix + " & REC_PID=$!; " +
                "echo \"$REC_PID\" > " + root.shellQuote(root.recorderPidFile) + "; " + notifyStartPid + "wait $REC_PID; rm -f " + root.shellQuote(root.recorderPidFile) + "; ";
        } else {
            scriptBody = "mkdir -p \"" + dir + "\"; gpu-screen-recorder -w \"$MONITOR\"" + gsrSuffix + " & REC_PID=$!; " +
                "echo \"$REC_PID\" > " + root.shellQuote(root.recorderPidFile) + "; " + notifyStartPid + "wait $REC_PID; rm -f " + root.shellQuote(root.recorderPidFile) + "; ";
        }

        let finalCmd = "sleep 0.5; " + (prelude !== "" ? prelude + "; " + scriptBody : scriptBody);

        let deferRecordingUi = root.captureMode === "interactive";
        if (!deferRecordingUi) {
            root.isRecording = true;
            root.isPaused = false;
            root.isAudioRecording = false;
            root.recordingElapsed = 0;
        }
        root.lastSavedVideoPath = path;
        root.close();

        Quickshell.execDetached(["bash", "-c", finalCmd]);

        if (root.showNotify && !deferRecordingUi) {
            Quickshell.execDetached(["notify-send", "Recording Started", "Saving to " + dir]);
        }
    }

    function startAudioRecording() {
        let parsedFilename = root.audioFilename !== "" ? root.parseDateTemplate(root.audioFilename) : "";
        if (parsedFilename !== "" && parsedFilename.indexOf(".") === -1) parsedFilename += "." + root.audioFormat;
        let filename = parsedFilename !== "" ? parsedFilename : "audio_" + root.filenameTimestamp() + "." + root.audioFormat;
        let dir = root.expandHome(root.audioDir());
        let path = dir + "/" + filename;

        let prepends = [];
        prepends.push("SINK=$(pactl get-default-sink 2>/dev/null); if [ -n \"$SINK\" ]; then SYSTEM_AUDIO=\"$SINK.monitor\"; else SYSTEM_AUDIO=\"@DEFAULT_SINK@.monitor\"; fi");
        let mic = root.videoMic && root.videoMic !== "default" ? root.videoMic : "$(pactl get-default-source 2>/dev/null)";
        prepends.push("MIC_AUDIO=\"" + mic + "\"; if [ -z \"$MIC_AUDIO\" ]; then MIC_AUDIO=\"@DEFAULT_SOURCE@\"; fi");
        // Bluetooth headset check: if recording mic and card is in a2dp profile without input stream, switch to headset-head-unit and restore on exit
        prepends.push("BT_CARD=\"\"; OLD_BT_PROFILE=\"\"; " +
                      "if [ -n \"$MIC_AUDIO\" ]; then " +
                      "BT_CARD=$(pactl list sources 2>/dev/null | awk -v mic=\"$MIC_AUDIO\" '$1 == \"Name:\" { cur = $2 } cur == mic && /device\\.name =/ { gsub(/\"/, \"\", $3); print $3; exit }'); " +
                      "if [ -n \"$BT_CARD\" ]; then " +
                      "CUR_P=$(pactl list cards 2>/dev/null | awk -v card=\"$BT_CARD\" '$1 == \"Name:\" { cur = $2 } cur == card && /Active Profile:/ { print $3; exit }'); " +
                      "if echo \"$CUR_P\" | grep -q \"a2dp\"; then " +
                      "OLD_BT_PROFILE=\"$CUR_P\"; pactl set-card-profile \"$BT_CARD\" headset-head-unit 2>/dev/null; sleep 0.5; " +
                      "fi; fi; fi");

        let prelude = prepends.join("; ");
        let cmd = "mkdir -p \"" + dir + "\"; ";
        if (prelude !== "") cmd += prelude + "; ";

        // Build command based on format
        let fmt = root.audioFormat;
        let bitrate = root.audioBitrate || "192k";

        let ffmpegArgs = "ffmpeg -y ";
        let sourceMode = root.audioSource;
        if (sourceMode === "system") {
            ffmpegArgs += "-f pulse -i \"$SYSTEM_AUDIO\" ";
        } else if (sourceMode === "mic") {
            ffmpegArgs += "-f pulse -i \"$MIC_AUDIO\" ";
        } else {
            // "both"
            ffmpegArgs += "-f pulse -i \"$MIC_AUDIO\" -f pulse -i \"$SYSTEM_AUDIO\" -filter_complex \"amix=inputs=2\" ";
        }

        if (fmt === "opus" || fmt === "ogg") {
            let acodec = fmt === "opus" ? "libopus" : "libvorbis";
            ffmpegArgs += "-c:a " + acodec + " -b:a " + bitrate + " \"" + path + "\"";
        } else if (fmt === "flac") {
            ffmpegArgs += "-c:a flac \"" + path + "\"";
        } else if (fmt === "wav") {
            ffmpegArgs += "-c:a pcm_s16le \"" + path + "\"";
        } else if (fmt === "m4a") {
            ffmpegArgs += "-c:a aac -b:a " + bitrate + " \"" + path + "\"";
        } else {
            // Default mp3
            ffmpegArgs += "-c:a libmp3lame -b:a " + bitrate + " \"" + path + "\"";
        }

        cmd += "cleanup() { [ -n \"$OLD_BT_PROFILE\" ] && [ -n \"$BT_CARD\" ] && pactl set-card-profile \"$BT_CARD\" \"$OLD_BT_PROFILE\" 2>/dev/null; rm -f " + root.shellQuote(root.recorderPidFile) + "; }; " +
               "trap cleanup EXIT INT TERM; " +
               ffmpegArgs + " & REC_PID=$!; echo \"$REC_PID\" > " + root.shellQuote(root.recorderPidFile) + "; " +
               "command -v dms >/dev/null 2>&1 && ( dms ipc call screenCaptureToolbar onRecorderStarted \"$REC_PID\" 2>/dev/null || dms ipc screenCaptureToolbar onRecorderStarted \"$REC_PID\" 2>/dev/null ); " +
               "wait $REC_PID; cleanup;";

        root.isRecording = true;
        root.isAudioRecording = true;
        root.isPaused = false;
        root.isMicCaptured = (root.audioSource === "mic" || root.audioSource === "both");
        root.isMicMuted = false;
        root.recordingElapsed = 0;
        root.lastSavedAudioPath = path;
        root.close();

        Quickshell.execDetached(["bash", "-c", cmd]);

        if (root.showNotify) {
            Quickshell.execDetached(["notify-send", "Audio Recording Started", "Saving to " + dir]);
        }
    }

    function stopRecording() {
        let pid = root.recorderPid;
        let pidFile = root.recorderPidFile;
        let stopCmd = "TARGET_PID=" + (pid > 0 ? pid : "\"\"");
        stopCmd += "; if [ -z \"$TARGET_PID\" ] && [ -f " + root.shellQuote(pidFile) + " ]; then TARGET_PID=$(cat " + root.shellQuote(pidFile) + " 2>/dev/null); fi";
        stopCmd += "; if [ -n \"$TARGET_PID\" ] && kill -0 \"$TARGET_PID\" 2>/dev/null; then kill -SIGINT \"$TARGET_PID\" 2>/dev/null; fi";
        Quickshell.execDetached(["bash", "-c", stopCmd]);

        Quickshell.execDetached(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "0"]);
        
        let savedPath = root.isAudioRecording ? root.lastSavedAudioPath : root.lastSavedVideoPath;
        let isAudio = root.isAudioRecording;

        root.isRecording = false;
        root.isAudioRecording = false;
        root.isPaused = false;
        root.isMicCaptured = false;
        root.isMicMuted = false;
        root.recordingElapsed = 0;
        root.recorderPid = 0;

        let cmdStr = "TARGET_PID=" + (pid > 0 ? pid : "\"\"");
        cmdStr += "; if [ -z \"$TARGET_PID\" ] && [ -f " + root.shellQuote(pidFile) + " ]; then TARGET_PID=$(cat " + root.shellQuote(pidFile) + " 2>/dev/null); fi; ";
        cmdStr += "if [ -n \"$TARGET_PID\" ]; then while kill -0 \"$TARGET_PID\" 2>/dev/null; do sleep 0.2; done; else sleep 0.4; fi; sleep 0.2; ";
        if (!isAudio && root.copyVideoFile) {
            cmdStr += "FILE=" + root.shellQuote(savedPath) + "; FILE=\"${FILE/#\\$HOME/$HOME}\"; echo -n \"file://$FILE\" | wl-copy -t text/uri-list; ";
        } else if (root.copyPathOnCapture) {
            cmdStr += "FILE=" + root.shellQuote(savedPath) + "; FILE=\"${FILE/#\\$HOME/$HOME}\"; echo -n \"$FILE\" | wl-copy; ";
        }
        if (cmdStr.indexOf("wl-copy") !== -1) {
            Quickshell.execDetached(["bash", "-c", cmdStr]);
        }

        if (root.showNotify) {
            let title = isAudio ? "Audio Recording Stopped" : "Recording Stopped";
            Quickshell.execDetached(["dms", "ipc", "call", "toast", "infoWith", title, "Saved to " + savedPath, "", "screencapture"]);
        }
    }

    function pauseRecording() {
        let pid = root.recorderPid;
        let pidFile = root.recorderPidFile;
        let isAudio = root.isAudioRecording;
        let sig = isAudio ? "-SIGSTOP" : "-SIGUSR2";
        let cmd = "TARGET_PID=" + (pid > 0 ? pid : "\"\"");
        cmd += "; if [ -z \"$TARGET_PID\" ] && [ -f " + root.shellQuote(pidFile) + " ]; then TARGET_PID=$(cat " + root.shellQuote(pidFile) + " 2>/dev/null); fi";
        cmd += "; if [ -n \"$TARGET_PID\" ] && kill -0 \"$TARGET_PID\" 2>/dev/null; then kill " + sig + " \"$TARGET_PID\" 2>/dev/null; fi";
        Quickshell.execDetached(["bash", "-c", cmd]);
        root.isPaused = true;
    }

    function resumeRecording() {
        let pid = root.recorderPid;
        let pidFile = root.recorderPidFile;
        let isAudio = root.isAudioRecording;
        let sig = isAudio ? "-SIGCONT" : "-SIGUSR2";
        let cmd = "TARGET_PID=" + (pid > 0 ? pid : "\"\"");
        cmd += "; if [ -z \"$TARGET_PID\" ] && [ -f " + root.shellQuote(pidFile) + " ]; then TARGET_PID=$(cat " + root.shellQuote(pidFile) + " 2>/dev/null); fi";
        cmd += "; if [ -n \"$TARGET_PID\" ] && kill -0 \"$TARGET_PID\" 2>/dev/null; then kill " + sig + " \"$TARGET_PID\" 2>/dev/null; fi";
        Quickshell.execDetached(["bash", "-c", cmd]);
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

    Timer {
        id: autoClosePopupTimer
        interval: 1500
        repeat: false
        onTriggered: {
            root.settingsExpanded = false;
            root.delayExpanded = false;
            root.monitorExpanded = false;
            globalKeyHandler.forceActiveFocus();
        }
    }


    // Backdrop / Dim Layer (Separate PanelWindow for blur support in Niri / Wayland compositors)
    PanelWindow {
        id: bgOverlay
        visible: overlay.visible
        color: "transparent"

        WlrLayershell.namespace: "dms:plugins:screenCaptureToolbar:dim"
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: bgOverlay.visible ? 0.15 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }
    }

    // -- UI -------------------------------------------------------------------
    PanelWindow {
        id: overlay
        visible: false
        color: "transparent"

        WlrLayershell.namespace: "dms:plugins:screenCaptureToolbar:bar"
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: overlay.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        onVisibleChanged: {
            if (visible) {
                globalKeyHandler.forceActiveFocus();
            }
        }

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        Item {
            id: globalKeyHandler
            anchors.fill: parent
            focus: overlay.visible
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Space) {
                    console.log("[dms-ss-toolbar] Space key pressed, captureMode =", root.captureMode);
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
                    if (root.settingsExpanded || root.delayExpanded || root.monitorExpanded) {
                        root.settingsExpanded = false;
                        root.delayExpanded = false;
                        root.monitorExpanded = false;
                        globalKeyHandler.forceActiveFocus();
                    } else {
                        root.close();
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Z) {
                    root.isVideoMode = !root.isVideoMode;
                    event.accepted = true;
                } else if (event.key === Qt.Key_X) {
                    if (root.captureMode !== "monitor") {
                        root.captureMode = "monitor";
                        root._save("captureMode", "monitor");
                    }
                    root.monitorExpanded = true;
                    root.settingsExpanded = false;
                    root.delayExpanded = false;
                    
                    let idx = 0;
                    for (let i = 0; i < root.monitorList.length; i++) {
                        if (root.monitorList[i].value === root.videoMonitor) {
                            idx = i;
                            break;
                        }
                    }
                    idx = (idx + 1) % root.monitorList.length;
                    root.videoMonitor = root.monitorList[idx].value;
                    root.monitorSelectedIndex = idx;
                    root._save("videoMonitor", root.videoMonitor);
                    
                    autoClosePopupTimer.restart();
                    event.accepted = true;
                } else if (event.key === Qt.Key_C) {
                    let modes = root.isVideoMode ? ["interactive", "monitor", "all"] : ["interactive", "monitor", "window", "all", "scroll"];
                    let idx = modes.indexOf(root.captureMode);
                    if (idx === -1) idx = 0;
                    root.captureMode = modes[(idx + 1) % modes.length];
                    root._save("captureMode", root.captureMode);
                    event.accepted = true;
                } else if (event.key === Qt.Key_A) {
                    root.delayExpanded = true;
                    root.settingsExpanded = false;
                    root.monitorExpanded = false;
                    
                    let delays = [0, 3, 5, 10];
                    let idx = delays.indexOf(root.delaySeconds);
                    idx = (idx + 1) % delays.length;
                    root.delaySeconds = delays[idx];
                    root.delaySelectedIndex = idx;
                    root._save("delaySeconds", root.delaySeconds);
                    
                    autoClosePopupTimer.restart();
                    event.accepted = true;
                } else if (event.key === Qt.Key_S) {
                    root.settingsExpanded = !root.settingsExpanded;
                    root.delayExpanded = false;
                    root.monitorExpanded = false;
                    event.accepted = true;
                } else if (root.enableController) {
                    if (event.key === Qt.Key_Right) {
                        root.isVideoMode = true;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left) {
                        root.isVideoMode = false;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                        let modes = root.isVideoMode ? ["interactive", "monitor", "all"] : ["interactive", "monitor", "window", "all", "scroll"];
                        let idx = modes.indexOf(root.captureMode);
                        if (idx === -1) idx = 0;
                        if (event.key === Qt.Key_Down) idx = (idx + 1) % modes.length;
                        else idx = (idx - 1 + modes.length) % modes.length;
                        root.captureMode = modes[idx];
                        root._save("captureMode", root.captureMode);
                        event.accepted = true;
                    }
                }
            }
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
                width: (root.showAdvancedSettings && root.isVideoMode) ? 660 : 340
                readonly property real maxAllowedHeight: (overlay ? overlay.height : 800) - pillContainer.height - 48 - 24 - 16
                height: root.settingsExpanded ? Math.min(settingsCol.implicitHeight + 40, maxAllowedHeight) : 0
                radius: 24
                color: Theme.withAlpha(Theme.surfaceContainerHigh || Theme.surfaceVariant || Theme.surface || "#252525", root.toolbarOpacity)
                border.width: 1
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                clip: true

                // Position strictly above the right side of the pill
                anchors.bottom: pillContainer.top
                anchors.bottomMargin: 24
                anchors.right: pillContainer.right

                visible: opacity > 0.01
                opacity: root.settingsExpanded ? 1 : 0
                scale: root.settingsExpanded ? 1 : 0.9
                transformOrigin: Item.BottomRight

                Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

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
                    x: {
                        let _trigger = pillContainer.width + (root.isVideoMode ? 1 : 0);
                        return settingsBubble.mapFromItem(settingsBtn, settingsBtn.width / 2, 0).x - width / 2;
                    }
                    border.width: 1; border.color: settingsBubble.border.color
                    z: -1
                }

                Flickable {
                    id: settingsFlick
                    anchors.fill: parent
                    anchors.margins: 20
                    contentWidth: width
                    contentHeight: settingsCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: settingsCol
                        width: settingsFlick.width
                        spacing: 12

                    RowLayout {
                        spacing: 8
                        DankIcon { name: "settings"; size: 16; color: Theme.surfaceText }
                        StyledText { text: "Options"; font.bold: true; font.pixelSize: 15; color: Theme.surfaceText; Layout.fillWidth: true }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        
                        ColumnLayout {
                            Layout.preferredWidth: (root.showAdvancedSettings && root.isVideoMode) ? Math.floor((settingsCol.width - 12) / 2) : settingsCol.width
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: 8

                            // Screenshot Toggles (Segmented Stack)
                            Column {
                                id: photoTogglesCol
                                Layout.fillWidth: true
                                spacing: 2
                                visible: root.mediaMode === "photo"

                                SettingToggle {
                                    label: "Copy to Clipboard"; iconName: "content_copy"; active: root.copyToClipboard
                                    isFirst: true
                                    onToggled: { root.copyToClipboard = !root.copyToClipboard; root._save("copyToClipboard", root.copyToClipboard) }
                                }
                                SettingToggle {
                                    label: "Save to Disk"; iconName: "save"; active: root.saveToDisk
                                    onToggled: { root.saveToDisk = !root.saveToDisk; root._save("saveToDisk", root.saveToDisk) }
                                }
                                SettingToggle { 
                                    label: "Screenshot Editor"; iconName: "output"; active: root.stdout
                                    onToggled: { root.stdout = !root.stdout; root._save("stdout", root.stdout) }
                                }
                                SettingToggle { 
                                    label: "Enable Editor Shortcut"; iconName: "keyboard"; active: root.enableEditorShortcut
                                    onToggled: { root.enableEditorShortcut = !root.enableEditorShortcut; root._save("enableEditorShortcut", root.enableEditorShortcut) }
                                }
                                SettingToggle { 
                                    label: "Swap Shortcuts"; iconName: "swap_horiz"; active: root.swapCaptureKeys
                                    onToggled: { root.swapCaptureKeys = !root.swapCaptureKeys; root._save("swapCaptureKeys", root.swapCaptureKeys) }
                                }
                                SettingToggle {
                                    label: "Show Mouse Pointer"; iconName: "mouse"; active: root.showPointer
                                    onToggled: { root.showPointer = !root.showPointer; root._save("showPointer", root.showPointer) }
                                }
                                SettingToggle {
                                    label: "Show Notification"; iconName: "notifications"; active: root.showNotify
                                    isLast: true
                                    onToggled: { root.showNotify = !root.showNotify; root._save("showNotify", root.showNotify) }
                                }
                            }

                            // Video & Audio Recording Toggles (Segmented Stack)
                            Column {
                                id: videoTogglesCol
                                Layout.fillWidth: true
                                spacing: 2
                                visible: root.isVideoMode || root.mediaMode === "audio"

                                SettingToggle {
                                    label: "Record System Audio"; iconName: "graphic_eq"; active: root.recordAudio
                                    visible: root.isVideoMode
                                    isFirst: true
                                    onToggled: { root.recordAudio = !root.recordAudio; root._save("recordAudio", root.recordAudio) }
                                }
                                SettingToggle {
                                    label: "Record Microphone"; iconName: "mic"; active: root.recordMic
                                    visible: root.isVideoMode
                                    onToggled: { root.recordMic = !root.recordMic; root._save("recordMic", root.recordMic) }
                                }
                                SettingToggle {
                                    label: "Copy Video File"; iconName: "content_copy"; active: root.copyVideoFile
                                    visible: root.isVideoMode
                                    onToggled: { root.copyVideoFile = !root.copyVideoFile; root._save("copyVideoFile", root.copyVideoFile) }
                                }
                                SettingToggle {
                                    label: "Show Mouse Pointer"; iconName: "mouse"; active: root.showPointer
                                    visible: root.isVideoMode
                                    onToggled: { root.showPointer = !root.showPointer; root._save("showPointer", root.showPointer) }
                                }
                                SettingToggle {
                                    label: "Show Notification"; iconName: "notifications"; active: root.showNotify
                                    isFirst: root.mediaMode === "audio"
                                    onToggled: { root.showNotify = !root.showNotify; root._save("showNotify", root.showNotify) }
                                }
                                SettingToggle { 
                                    label: "Show Recording Pill"; iconName: "smart_button"; active: root.showRecPill
                                    isLast: !root.isVideoMode
                                    onToggled: { root.showRecPill = !root.showRecPill; root._save("showRecPill", root.showRecPill) }
                                }
                                SettingToggle {
                                    label: "Show Advanced Settings"; iconName: "tune"; active: root.showAdvancedSettings
                                    visible: root.isVideoMode
                                    isLast: true
                                    onToggled: { 
                                        root.showAdvancedSettings = !root.showAdvancedSettings; 
                                        root._save("showAdvancedSettings", root.showAdvancedSettings);
                                    }
                                }
                            }

                    // Audio Source Segment (Audio Mode)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: audioSourceCol.implicitHeight + 20
                        radius: Theme.cornerRadius || 12
                        color: Theme.withAlpha(Theme.surfaceContainerHigh || "#303030", 0.5)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        visible: root.mediaMode === "audio"

                        ColumnLayout {
                            id: audioSourceCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.45)
                                    Layout.alignment: Qt.AlignVCenter
                                    DankIcon { anchors.centerIn: parent; name: "mic"; size: 16; color: Theme.surfaceVariantText }
                                }
                                StyledText { text: "Audio Source"; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.surfaceText; Layout.fillWidth: true }
                            }

                            SegmentedBar {
                                Layout.fillWidth: true
                                model: ["System", "Mic", "Both"]
                                currentIndex: {
                                    if (root.audioSource === "system") return 0;
                                    if (root.audioSource === "both") return 2;
                                    return 1;
                                }
                                onSelectionChanged: function(idx, val) {
                                    var sources = ["system", "mic", "both"];
                                    root.audioSource = sources[idx];
                                    root._save("audioSource", root.audioSource);
                                }
                            }
                        }
                    }

                    // Format Segment
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: formatCol.implicitHeight + 20
                        radius: Theme.cornerRadius || 12
                        color: Theme.withAlpha(Theme.surfaceContainerHigh || "#303030", 0.5)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        
                        ColumnLayout {
                            id: formatCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.45)
                                    Layout.alignment: Qt.AlignVCenter
                                    DankIcon { 
                                        anchors.centerIn: parent
                                        name: root.mediaMode === "audio" ? "audio_file" : (root.isVideoMode ? "movie" : "image")
                                        size: 16
                                        color: Theme.surfaceVariantText 
                                    }
                                }
                                StyledText { text: root.mediaMode === "audio" ? "Audio Format" : (root.isVideoMode ? "Video Format" : "Image Format"); font.pixelSize: 13; font.weight: Font.Medium; color: Theme.surfaceText; Layout.fillWidth: true }
                            }

                            DankDropdown {
                                visible: root.mediaMode === "audio"
                                Layout.fillWidth: true; height: 32
                                compactMode: true
                                currentValue: root.audioFormat.toUpperCase()
                                options: ["MP3", "OPUS", "FLAC", "WAV", "M4A", "OGG"]
                                onValueChanged: {
                                    root.audioFormat = String(value).toLowerCase();
                                    root._save("audioFormat", root.audioFormat);
                                }
                            }

                            SegmentedBar {
                                visible: root.mediaMode !== "audio"
                                Layout.fillWidth: true
                                model: root.isVideoMode ? ["MP4", "MKV", "FLV"] : ["PNG", "JPG", "PPM"]
                                currentIndex: {
                                    if (root.isVideoMode) {
                                        return root.videoFormat === "mp4" ? 0 : (root.videoFormat === "mkv" ? 1 : 2);
                                    } else {
                                        return root.format === "png" ? 0 : (root.format === "jpg" ? 1 : 2);
                                    }
                                }
                                onSelectionChanged: function(idx, val) {
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

                    // Audio Bitrate Segment (Audio Mode)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: audioBitrateCol.implicitHeight + 20
                        radius: Theme.cornerRadius || 12
                        color: Theme.withAlpha(Theme.surfaceContainerHigh || "#303030", 0.5)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        visible: root.mediaMode === "audio"

                        ColumnLayout {
                            id: audioBitrateCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.45)
                                    Layout.alignment: Qt.AlignVCenter
                                    DankIcon { anchors.centerIn: parent; name: "equalizer"; size: 16; color: Theme.surfaceVariantText }
                                }
                                StyledText { text: "Audio Bitrate"; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.surfaceText; Layout.fillWidth: true }
                            }

                            SegmentedBar {
                                Layout.fillWidth: true
                                model: ["128k", "192k", "256k", "320k"]
                                currentIndex: {
                                    var bitrates = ["128k", "192k", "256k", "320k"];
                                    var idx = bitrates.indexOf(root.audioBitrate);
                                    return idx >= 0 ? idx : 1;
                                }
                                onSelectionChanged: function(idx, val) {
                                    var bitrates = ["128k", "192k", "256k", "320k"];
                                    root.audioBitrate = bitrates[idx];
                                    root._save("audioBitrate", root.audioBitrate);
                                }
                            }
                        }
                    }

                    // Mic Selector & Test Segment
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: micCol.implicitHeight + 20
                        radius: Theme.cornerRadius || 12
                        color: Theme.withAlpha(Theme.surfaceContainerHigh || "#303030", 0.5)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        visible: (root.isVideoMode && root.recordMic) || (root.mediaMode === "audio" && (root.audioSource === "mic" || root.audioSource === "both"))

                        ColumnLayout {
                            id: micCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.45)
                                    Layout.alignment: Qt.AlignVCenter
                                    DankIcon { anchors.centerIn: parent; name: "mic"; size: 16; color: Theme.surfaceVariantText }
                                }
                                StyledText { text: "Mic Selector"; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.surfaceText; Layout.fillWidth: true }
                            }

                            DankDropdown {
                                Layout.fillWidth: true; height: 32
                                compactMode: true
                                currentValue: {
                                    for (var i = 0; i < root.micList.length; i++) {
                                        if (root.micList[i].value === root.videoMic) return root.micList[i].label;
                                    }
                                    return root.videoMic || "Default";
                                }
                                options: root.micList.map(function(item) { return item.label; })
                                onValueChanged: {
                                    for (var i = 0; i < root.micList.length; i++) {
                                        if (root.micList[i].label === value) {
                                            root.videoMic = root.micList[i].value;
                                            root._save("videoMic", root.videoMic);
                                            break;
                                        }
                                    }
                                }
                            }
                            
                            // Mic Testing Button
                            Rectangle {
                                id: testMicRect
                                Layout.fillWidth: true
                                height: 32
                                radius: (root.isTestingMic && !root.isPlayingMic && !root.isProcessingMic) ? 16 : 8
                                color: (root.isTestingMic && !root.isPlayingMic && !root.isProcessingMic) ? (Theme.primary || "#38bdf8") : (testMicMa2.containsMouse || testMicRect.activeFocus ? Theme.withAlpha(Theme.primary || "#38bdf8", 0.25) : "transparent")
                                border.color: Theme.primary || "#38bdf8"
                                border.width: 1
                                
                                focus: root.settingsExpanded
                                activeFocusOnTab: visible
                                Keys.onReturnPressed: testMicMa2.clicked(null)
                                Keys.onSpacePressed: testMicMa2.clicked(null)
                                
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on radius { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    DankIcon {
                                        id: testMicIcon
                                        name: root.isTestingMic ? (root.isProcessingMic ? "autorenew" : (root.isPlayingMic ? "volume_up" : (root.micTestCountdown > 0 ? "timer" : "stop"))) : "fiber_manual_record"
                                        size: 16
                                        color: (root.isTestingMic && !root.isPlayingMic && !root.isProcessingMic) ? (Theme.onPrimary || "#ffffff") : (Theme.primary || "#38bdf8")
                                        
                                        transformOrigin: Item.Center
                                        
                                        RotationAnimator on rotation {
                                            from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: root.isProcessingMic
                                        }
                                        
                                        SequentialAnimation on scale {
                                            id: pulseAnim
                                            loops: Animation.Infinite; running: root.isTestingMic && !root.isProcessingMic
                                            NumberAnimation { to: 1.25; duration: 500; easing.type: Easing.InOutQuad }
                                            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                                        }
                                        
                                        onNameChanged: {
                                            if (!root.isProcessingMic) rotation = 0;
                                            if (!pulseAnim.running) scale = 1.0;
                                        }
                                    }
                                    StyledText {
                                        text: root.isTestingMic ? (root.isProcessingMic ? "Processing..." : (root.isPlayingMic ? "Playing Test..." : (root.micTestCountdown > 0 ? "Starting in " + root.micTestCountdown + "..." : "Testing (Speak now...)"))) : "Test Microphone"
                                        color: (root.isTestingMic && !root.isPlayingMic && !root.isProcessingMic) ? (Theme.onPrimary || "#ffffff") : (Theme.primary || "#38bdf8")
                                        font.pixelSize: 12
                                    }
                                }
                                
                                MouseArea {
                                    id: testMicMa2
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (root.isTestingMic) {
                                            if (root.isPlayingMic || root.isProcessingMic || root.micTestCountdown > 0) {
                                                micTestProcess.running = false;
                                                root.isTestingMic = false;
                                            } else {
                                                micTestStopProcess.running = false;
                                                micTestStopProcess.running = true;
                                            }
                                        } else {
                                            root.isTestingMic = true;
                                            root.isPlayingMic = false;
                                            root.micTestCountdown = 3;
                                            var mic = root.videoMic;
                                            var testWav = root.shellQuote(root.micTestFile);
                                            var stopFile = root.shellQuote(root.micTestStopFile);
                                            var recordCmd = "rm -f " + testWav + " " + stopFile + "; ";
                                            recordCmd += "echo COUNTDOWN 3; sleep 1; echo COUNTDOWN 2; sleep 1; echo COUNTDOWN 1; sleep 1; echo RECORDING; ";
                                            if (mic && mic !== "default" && mic !== "default_input") {
                                                recordCmd += "pw-record --target " + mic + " " + testWav + " & REC_PID=$!; ";
                                            } else {
                                                recordCmd += "pw-record " + testWav + " & REC_PID=$!; ";
                                            }
                                            recordCmd += "for i in {1..50}; do if [ -f " + stopFile + " ]; then break; fi; sleep 0.1; done; ";
                                            recordCmd += "if kill -0 $REC_PID 2>/dev/null; then kill -INT $REC_PID 2>/dev/null; echo PROCESSING; wait $REC_PID 2>/dev/null; sleep 1; echo PLAYING; pw-play " + testWav + " & PLAY_PID=$!; wait $PLAY_PID 2>/dev/null; rm -f " + testWav + " " + stopFile + "; fi";
                                            micTestProcess.command = ["bash", "-c", recordCmd];
                                            micTestProcess.running = true;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // JPG Quality Segment
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: qualityCol.implicitHeight + 20
                        radius: Theme.cornerRadius || 12
                        color: Theme.withAlpha(Theme.surfaceContainerHigh || "#303030", 0.5)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        visible: root.format === "jpg" && root.mediaMode === "photo" && !root.isVideoMode

                        ColumnLayout {
                            id: qualityCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.45)
                                    Layout.alignment: Qt.AlignVCenter
                                    DankIcon { anchors.centerIn: parent; name: "high_quality"; size: 16; color: Theme.surfaceVariantText }
                                }
                                StyledText { text: "JPG Quality"; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.surfaceText; Layout.fillWidth: true }
                            }
                            DankTextField {
                                Layout.fillWidth: true; height: 32
                                font.pixelSize: 12
                                text: root.quality.toString()
                                placeholderText: "90"
                                activeFocusOnTab: false
                                onEditingFinished: {
                                    var v = parseInt(text);
                                    if (!isNaN(v)) { root.quality = v; root._save("quality", v); }
                                }
                            }
                        }
                    }

                    // Scroll Interval Segment (Scrolling Screenshot)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: scrollIntervalCol.implicitHeight + 20
                        radius: Theme.cornerRadius || 12
                        color: Theme.withAlpha(Theme.surfaceContainerHigh || "#303030", 0.5)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        visible: root.mediaMode === "photo" && !root.isVideoMode && root.captureMode === "scroll"

                        ColumnLayout {
                            id: scrollIntervalCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.45)
                                    Layout.alignment: Qt.AlignVCenter
                                    DankIcon { anchors.centerIn: parent; name: "swap_vert"; size: 16; color: Theme.surfaceVariantText }
                                }
                                StyledText { text: "Scroll Interval (ms)"; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.surfaceText; Layout.fillWidth: true }
                            }
                            DankTextField {
                                Layout.fillWidth: true; height: 32
                                font.pixelSize: 12
                                text: root.scrollInterval.toString()
                                placeholderText: "45"
                                activeFocusOnTab: false
                                onEditingFinished: {
                                    var v = parseInt(text);
                                    if (!isNaN(v)) {
                                        v = Math.max(30, Math.min(1000, v));
                                        root.scrollInterval = v;
                                        root._save("scrollInterval", v);
                                    }
                                }
                            }
                        }
                    }

                    // Custom Directory Segment
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: pathCol.implicitHeight + 20
                        radius: Theme.cornerRadius || 12
                        color: Theme.withAlpha(Theme.surfaceContainerHigh || "#303030", 0.5)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        
                        ColumnLayout {
                            id: pathCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.45)
                                    Layout.alignment: Qt.AlignVCenter
                                    DankIcon { anchors.centerIn: parent; name: "folder"; size: 16; color: Theme.surfaceVariantText }
                                }
                                StyledText { text: root.mediaMode === "audio" ? "Audio Directory" : (root.isVideoMode ? "Video Directory" : "Screenshot Directory"); font.pixelSize: 13; font.weight: Font.Medium; color: Theme.surfaceText; Layout.fillWidth: true }
                            }
                            DankTextField {
                                Layout.fillWidth: true; height: 32
                                font.pixelSize: 12
                                text: root.mediaMode === "audio" ? root.audioCustomPath : (root.isVideoMode ? root.videoCustomPath : root.customPath)
                                placeholderText: root.mediaMode === "audio" ? "~/Music" : (root.isVideoMode ? "~/Videos" : "~/Pictures/Screenshots")
                                activeFocusOnTab: false
                                onEditingFinished: {
                                    if (root.mediaMode === "audio") {
                                        root.audioCustomPath = text;
                                        root._save("audioCustomPath", text);
                                    } else if (root.isVideoMode) {
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

                        ColumnLayout {
                            Layout.preferredWidth: Math.floor((settingsCol.width - 12) / 2)
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: 8
                            visible: root.showAdvancedSettings && root.isVideoMode

                    // Video FPS Segment
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: videoFpsCol.implicitHeight + 20
                        radius: Theme.cornerRadius || 12
                        color: Theme.withAlpha(Theme.surfaceContainerHigh || "#303030", 0.5)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        visible: root.isVideoMode

                        ColumnLayout {
                            id: videoFpsCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.45)
                                    Layout.alignment: Qt.AlignVCenter
                                    DankIcon { anchors.centerIn: parent; name: "speed"; size: 16; color: Theme.surfaceVariantText }
                                }
                                StyledText { text: "Video FPS"; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.surfaceText; Layout.fillWidth: true }
                            }

                            SegmentedBar {
                                Layout.fillWidth: true
                                model: ["24 FPS", "30 FPS", "60 FPS"]
                                currentIndex: {
                                    if (root.videoFPS == 30) return 1;
                                    if (root.videoFPS == 60) return 2;
                                    return 0; // 24
                                }
                                onSelectionChanged: function(idx, val) {
                                    var fps = [24, 30, 60];
                                    root.videoFPS = fps[idx];
                                    root._save("videoFPS", root.videoFPS);
                                }
                            }
                        }
                    }

                    // Video Quality Segment
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: videoQualityCol.implicitHeight + 20
                        radius: Theme.cornerRadius || 12
                        color: Theme.withAlpha(Theme.surfaceContainerHigh || "#303030", 0.5)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        visible: root.isVideoMode

                        ColumnLayout {
                            id: videoQualityCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.45)
                                    Layout.alignment: Qt.AlignVCenter
                                    DankIcon { anchors.centerIn: parent; name: "high_quality"; size: 16; color: Theme.surfaceVariantText }
                                }
                                StyledText { text: "Video Quality (CRF/Preset)"; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.surfaceText; Layout.fillWidth: true }
                            }

                            SegmentedBar {
                                Layout.fillWidth: true
                                model: ["Med", "High", "V.High", "Ultra"]
                                currentIndex: {
                                    if (root.videoQuality === "high") return 1;
                                    if (root.videoQuality === "very_high") return 2;
                                    if (root.videoQuality === "ultra") return 3;
                                    return 0;
                                }
                                onSelectionChanged: function(idx, val) {
                                    var q = ["medium", "high", "very_high", "ultra"];
                                    root.videoQuality = q[idx];
                                    root._save("videoQuality", root.videoQuality);
                                }
                            }
                        }
                    }

                    // Video Codec Segment
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: videoCodecCol.implicitHeight + 20
                        radius: Theme.cornerRadius || 12
                        color: Theme.withAlpha(Theme.surfaceContainerHigh || "#303030", 0.5)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        visible: root.isVideoMode && root.showAdvancedSettings

                        ColumnLayout {
                            id: videoCodecCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.45)
                                    Layout.alignment: Qt.AlignVCenter
                                    DankIcon { anchors.centerIn: parent; name: "settings_applications"; size: 16; color: Theme.surfaceVariantText }
                                }
                                StyledText { text: "Video Codec"; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.surfaceText; Layout.fillWidth: true }
                            }

                            DankDropdown {
                                Layout.fillWidth: true; height: 32
                                compactMode: true
                                currentValue: {
                                    var codes = {"auto": "Auto (Recomended)", "av1": "AV1", "av1_10bit": "AV1 (10 Bit)", "av1_hdr": "AV1 (HDR)", "h264": "H.264 SE (Not Recomended)"};
                                    return codes[root.videoCodec] || "Auto (Recomended)";
                                }
                                options: ["Auto (Recomended)", "AV1", "AV1 (10 Bit)", "AV1 (HDR)", "H.264 SE (Not Recomended)"]
                                onValueChanged: {
                                    var opts = ["Auto (Recomended)", "AV1", "AV1 (10 Bit)", "AV1 (HDR)", "H.264 SE (Not Recomended)"];
                                    var vals = ["auto", "av1", "av1_10bit", "av1_hdr", "h264"];
                                    for (var i = 0; i < opts.length; i++) {
                                        if (opts[i] === String(value)) {
                                            root.videoCodec = vals[i];
                                            root._save("videoCodec", root.videoCodec);
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Audio Codec Segment
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: audioCodecCol.implicitHeight + 20
                        radius: Theme.cornerRadius || 12
                        color: Theme.withAlpha(Theme.surfaceContainerHigh || "#303030", 0.5)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        visible: root.isVideoMode && root.showAdvancedSettings

                        ColumnLayout {
                            id: audioCodecCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: 8

                            RowLayout {
                                spacing: 10
                                Rectangle {
                                    width: 28; height: 28; radius: 14
                                    color: Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.45)
                                    Layout.alignment: Qt.AlignVCenter
                                    DankIcon { anchors.centerIn: parent; name: "audio_file"; size: 16; color: Theme.surfaceVariantText }
                                }
                                StyledText { text: "Audio Codec"; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.surfaceText; Layout.fillWidth: true }
                            }

                            DankDropdown {
                                Layout.fillWidth: true; height: 32
                                compactMode: true
                                currentValue: {
                                    var codes = {"opus": "Opus (Recomended)", "aac": "AAC"};
                                    return codes[root.audioCodec] || "AAC";
                                }
                                options: ["Opus (Recomended)", "AAC"]
                                onValueChanged: {
                                    var opts = ["Opus (Recomended)", "AAC"];
                                    var vals = ["opus", "aac"];
                                    for (var i = 0; i < opts.length; i++) {
                                        if (opts[i] === String(value)) {
                                            root.audioCodec = vals[i];
                                            root._save("audioCodec", root.audioCodec);
                                            break;
                                        }
                                    }
                                }
                            }
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
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                clip: true
                
                anchors.bottom: pillContainer.top
                anchors.bottomMargin: 24
                anchors.right: pillContainer.right
                anchors.rightMargin: 0 // Flush right to match settingsBubble
                
                visible: opacity > 0.01
                opacity: root.delayExpanded ? 1 : 0
                scale: root.delayExpanded ? 1 : 0.9
                transformOrigin: Item.BottomRight
                
                Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

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
                    x: {
                        let _trigger = pillContainer.width + (root.isVideoMode ? 1 : 0);
                        return delayBubble.mapFromItem(delayBtn, delayBtn.width / 2, 0).x - width / 2;
                    }
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

                    // Selection Segment Stack
                    Column {
                        id: delayOptionsCol
                        Layout.fillWidth: true
                        spacing: 2
                        
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
                                isOption: true // Shows a radio/check dot
                                isFirst: index === 0
                                isLast: index === 3
                                isHighlighted: root.delayExpanded && index === root.delaySelectedIndex
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

            // Monitor Selection Bubble
            Rectangle {
                id: monitorBubble
                width: 320
                height: root.monitorExpanded ? monitorBubbleCol.implicitHeight + 40 : 0
                radius: 24
                color: Theme.withAlpha(Theme.surfaceContainerHigh || Theme.surfaceVariant || Theme.surface || "#252525", root.toolbarOpacity)
                border.width: 1
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                clip: true
                
                anchors.bottom: pillContainer.top
                anchors.bottomMargin: 24
                anchors.horizontalCenter: pillContainer.horizontalCenter
                
                visible: opacity > 0.01
                opacity: root.monitorExpanded ? 1 : 0
                scale: root.monitorExpanded ? 1 : 0.9
                transformOrigin: Item.Bottom
                
                Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

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
                    color: monitorBubble.color
                    rotation: 45
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -8
                    x: {
                        let _trigger = pillContainer.width + (root.isVideoMode ? 1 : 0);
                        return monitorBubble.mapFromItem(monitorBtn, monitorBtn.width / 2, 0).x - width / 2;
                    }
                    border.width: 1; border.color: monitorBubble.border.color
                    z: -1
                }

                ColumnLayout {
                    id: monitorBubbleCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 20
                    spacing: 12
                    
                    RowLayout {
                        spacing: 8
                        DankIcon { name: "desktop_windows"; size: 16; color: Theme.surfaceText }
                        StyledText { text: "Select Monitor"; font.bold: true; font.pixelSize: 15; color: Theme.surfaceText; Layout.fillWidth: true }
                    }

                    // Selection Segment Stack
                    Column {
                        id: monitorBubbleOptionsCol
                        Layout.fillWidth: true
                        spacing: 2
                        
                        Repeater {
                            model: root.monitorList
                            delegate: SettingToggle {
                                label: modelData.label
                                iconName: "monitor"
                                active: root.videoMonitor === modelData.value
                                isOption: true
                                isFirst: index === 0
                                isLast: index === root.monitorList.length - 1
                                isHighlighted: root.monitorExpanded && index === root.monitorSelectedIndex
                                onToggled: {
                                    root.videoMonitor = modelData.value;
                                    root._save("videoMonitor", root.videoMonitor);
                                    root.monitorExpanded = false;
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
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Rectangle {
                    id: pillBg
                    anchors.fill: parent
                    radius: height / 2
                    color: Theme.withAlpha(Theme.surfaceContainerHigh || Theme.surfaceVariant || Theme.surface || "#252525", root.toolbarOpacity)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                    
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
                            isFirst: true; iconName: "photo_camera"; active: root.mediaMode === "photo"
                            tooltipText: "Photo Mode"
                            onClicked: { 
                                root.mediaMode = "photo"; 
                                root.isVideoMode = false; 
                                root._save("mediaMode", "photo");
                                root._save("isVideoMode", false);
                            }
                        }
                        ToolbarBtn {
                            isLast: !root.enableAudioRecorder; iconName: "videocam"; active: root.mediaMode === "video"
                            tooltipText: "Video Mode"
                            onClicked: { 
                                root.mediaMode = "video"; 
                                root.isVideoMode = true; 
                                root._save("mediaMode", "video");
                                root._save("isVideoMode", true);
                            }
                        }
                        ToolbarBtn {
                            visible: root.enableAudioRecorder
                            isLast: true; iconName: "graphic_eq"; active: root.mediaMode === "audio"
                            tooltipText: "Audio Recorder Mode"
                            onClicked: { 
                                root.mediaMode = "audio"; 
                                root.isVideoMode = false; 
                                root._save("mediaMode", "audio");
                                root._save("isVideoMode", false);
                            }
                        }
                    }

                    // Modes / Capture Group (Segmented)
                    Row {
                        id: modeRow
                        spacing: 4

                        // In Audio Mode: Show Record Audio button here in group 2
                        ToolbarBtn {
                            id: audioRecordBtn
                            visible: root.mediaMode === "audio"
                            isSegmented: true
                            isFirst: true
                            isLast: true
                            iconName: "fiber_manual_record"
                            tooltipText: "Record Audio"
                            hoverColor: Theme.error || "#FF4444"
                            onClicked: root.performCapture(false)
                        }

                        // Photo & Video Modes
                        ToolbarBtn {
                            visible: root.mediaMode !== "audio"
                            isFirst: true
                            iconName: "screenshot_region"
                            active: root.captureMode === "interactive"
                            tooltipText: "Interactive Region"
                            onClicked: {
                                root.captureMode = "interactive";
                                root._save("captureMode", "interactive");
                            }
                        }
                        ToolbarBtn {
                            visible: root.mediaMode !== "audio"
                            id: monitorBtn
                            iconName: "monitor";
                            active: root.captureMode === "monitor"
                            tooltipText: (root.isVideoMode ? "Record Monitor - " : "Capture Monitor - ") + root.getMonitorLabel(root.videoMonitor)
                            onClicked: { 
                                if (root.captureMode !== "monitor") {
                                    root.captureMode = "monitor";
                                    root._save("captureMode", "monitor");
                                    root.settingsExpanded = false;
                                    root.delayExpanded = false;
                                    root.monitorExpanded = false;
                                } else {
                                    root.monitorExpanded = !root.monitorExpanded;
                                    root.settingsExpanded = false;
                                    root.delayExpanded = false;
                                }
                            }
                        }
                        ToolbarBtn {
                            visible: root.mediaMode !== "audio" && !root.isVideoMode
                            iconName: "picture_in_picture"
                            active: root.captureMode === "window"
                            tooltipText: "Window Capture"
                            onClicked: {
                                root.captureMode = "window";
                                root._save("captureMode", "window");
                            }
                        }
                        ToolbarBtn {
                            visible: root.mediaMode !== "audio"
                            isLast: root.isVideoMode
                            iconName: "monitor_weight"
                            active: root.captureMode === "all"
                            tooltipText: root.isVideoMode ? "Record All" : "All Screens"
                            onClicked: {
                                root.captureMode = "all";
                                root._save("captureMode", "all");
                            }
                        }
                        ToolbarBtn {
                            visible: root.mediaMode !== "audio" && !root.isVideoMode
                            isLast: true
                            iconName: "swap_vert"
                            active: root.captureMode === "scroll"
                            tooltipText: "Scrolling Screenshot"
                            onClicked: {
                                root.captureMode = "scroll";
                                root._save("captureMode", "scroll");
                            }
                        }
                    }

                    // Actions / Utilities Group (Segmented)
                    Row {
                        id: actionRow
                        spacing: 4

                        ToolbarBtn { 
                            id: delayBtn
                            visible: true
                            isSegmented: true
                            isFirst: true
                            isLast: false
                            iconName: "timer"
                            tooltipText: "Delay: " + root.delaySeconds + "s"
                            active: root.delayExpanded
                            onClicked: {
                                root.delayExpanded = !root.delayExpanded;
                                root.settingsExpanded = false;
                                root.monitorExpanded = false;
                            }
                            
                            // Indicator Badge for Delay
                            Rectangle {
                                visible: root.delaySeconds > 0
                                width: 16; height: 16; radius: 8
                                color: Theme.primary
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                                anchors.right: parent.right; anchors.rightMargin: 2
                                border.width: 1.5; border.color: delayBtn.isDark ? (Theme.surface || "black") : (Theme.onSurface || "white")
                                z: 100
                                
                                StyledText {
                                    text: root.delaySeconds
                                    anchors.centerIn: parent
                                    font.pixelSize: 10; font.bold: true
                                    color: (Theme.surface.r + Theme.surface.g + Theme.surface.b < 1.5) ? (Theme.surface || "black") : (Theme.onSurface || "white")
                                }
                            }
                        }

                        ToolbarBtn { 
                            id: settingsBtn
                            isSegmented: true
                            isFirst: false
                            isLast: false
                            iconName: "settings"
                            active: root.settingsExpanded
                            onClicked: { 
                                root.settingsExpanded = !root.settingsExpanded; 
                                root.delayExpanded = false; 
                                root.monitorExpanded = false; 
                            } 
                        }

                        ToolbarBtn { 
                            id: closeBtn
                            isSegmented: true
                            isFirst: false
                            isLast: true
                            iconName: "close"
                            tooltipText: "Close"
                            hoverColor: Theme.error || "#FF4444"
                            animateRotate: true
                            onClicked: root.close() 
                        }
                    }

                }
            }

            // Instruction Hint Pill
            Rectangle {
                width: hintText.implicitWidth + 32; height: 32; radius: 16
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                color: Theme.withAlpha(Theme.surfaceContainerHigh || Theme.surfaceVariant || Theme.surface || "#252525", root.toolbarOpacity * 0.85)
                border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                
                StyledText {
                    id: hintText
                    anchors.centerIn: parent
                    text: {
                        if (root.controllerConnected && root.enableController) {
                            if (root.isRecording) return "Press (Home/Guide) To Stop Recording";
                            if (root.mediaMode === "audio") return "Press (A) To Record Audio  •  (B) To Close";
                            if (root.isVideoMode) return "Press (A) To Record  •  (B) To Close";
                            return "Press (A) To Capture  •  (B) To Close";
                        }
                        
                        if (root.mediaMode === "audio") return "Press Space To Record Audio";
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
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }

        Keys.onEscapePressed: {
            if (root.settingsExpanded || root.delayExpanded || root.monitorExpanded) {
                root.settingsExpanded = false;
                root.delayExpanded = false;
                root.monitorExpanded = false;
            } else {
                root.close();
            }
        }
    }

    // -- Components -----------------------------------------------------------
    // -- Components -----------------------------------------------------------
    component ToolbarBtn: Item {
        id: tbBtnRoot
        property string iconName: ""
        property bool active: false
        property bool isFirst: false
        property bool isLast: false
        property bool isSegmented: true
        property bool animateRotate: false
        property string tooltipText: ""
        property color hoverColor: "transparent"
        property bool isDark: (Theme.surface.r + Theme.surface.g + Theme.surface.b < 1.5)
        signal clicked()
        width: visible ? 52 : 0; height: visible ? 40 : 0

        scale: ma.pressed ? 0.94 : (ma.containsMouse ? 1.03 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        readonly property real outerR: isSegmented ? 12 : 20
        readonly property real innerR: isSegmented ? 4 : 20

        readonly property bool hasCustomHoverColor: {
            if (!hoverColor || hoverColor === "transparent") return false;
            let c = String(hoverColor);
            return c !== "#00000000" && c !== "rgba(0,0,0,0)" && c !== "#000000" && hoverColor.a > 0;
        }

        Rectangle {
            id: btnBg
            anchors.fill: parent

            topLeftRadius: isSegmented ? ((active || ma.containsMouse) ? (height / 2) : (isFirst ? outerR : innerR)) : outerR
            bottomLeftRadius: isSegmented ? ((active || ma.containsMouse) ? (height / 2) : (isFirst ? outerR : innerR)) : outerR
            topRightRadius: isSegmented ? ((active || ma.containsMouse) ? (height / 2) : (isLast ? outerR : innerR)) : outerR
            bottomRightRadius: isSegmented ? ((active || ma.containsMouse) ? (height / 2) : (isLast ? outerR : innerR)) : outerR

            Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

            color: active 
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                : (ma.containsMouse 
                    ? (tbBtnRoot.hasCustomHoverColor ? Theme.withAlpha(hoverColor, 0.22) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12))
                    : (isSegmented ? Theme.withAlpha(Theme.surfaceContainerHighest || "#303030", 0.35) : Theme.withAlpha(Theme.onSurface || "#ffffff", 0.04)))

            border.width: 1
            border.color: active
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.50)
                : (ma.containsMouse 
                    ? (tbBtnRoot.hasCustomHoverColor ? Theme.withAlpha(hoverColor, 0.45) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30))
                    : (isSegmented ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)))

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            DankRipple {
                id: rippleObj
                anchors.fill: parent
                cornerRadius: btnBg.topLeftRadius
                rippleColor: Theme.primary
            }
        }

        DankIcon {
            id: icon
            name: parent.iconName; size: 20; anchors.centerIn: parent;
            color: active 
                ? (Theme.primary || "#8D4D57") 
                : (ma.containsMouse 
                    ? (tbBtnRoot.hasCustomHoverColor ? hoverColor : (Theme.surfaceText || Theme.onSurface || (tbBtnRoot.isDark ? "#ffffff" : "#000000"))) 
                    : (Theme.surfaceVariantText || Theme.outline || (tbBtnRoot.isDark ? "#bbbbbb" : "#555555")))
            opacity: active ? 1.0 : (ma.containsMouse ? 1.0 : 0.8)

            rotation: parent.animateRotate ? (ma.containsMouse ? 360 : 0) : (ma.containsMouse ? 12 : 0)
            y: (ma.containsMouse && !parent.animateRotate) ? -3 : 0

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on rotation { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
        }

        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor;
            onPressed: mouse => {
                let mapped = mapToItem(parent, mouse.x, mouse.y);
                rippleObj.trigger(mapped.x, mapped.y);
            }
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

    // Premium Action Button for the Recording Pill (Segmented UI)
    component PillActionBtn: Item {
        id: pillBtnRoot
        property string iconName: ""
        property real size: 40
        property real iconSize: 20
        property bool isDark: (Theme.surface.r + Theme.surface.g + Theme.surface.b < 1.5)
        property bool isActive: false
        property bool isFirst: false
        property bool isLast: false
        property bool isSegmented: true
        property color customHoverColor: "transparent"
        signal clicked()

        width: visible ? size : 0; height: visible ? size : 0
        scale: ma.pressed ? 0.94 : (ma.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        readonly property real outerR: isSegmented ? 12 : 20
        readonly property real innerR: isSegmented ? 4 : 20

        readonly property bool hasCustomHover: {
            if (!customHoverColor || customHoverColor === "transparent") return false;
            let c = String(customHoverColor);
            return c !== "#00000000" && c !== "rgba(0,0,0,0)" && customHoverColor.a > 0;
        }

        Rectangle {
            id: pillBtnBg
            anchors.fill: parent

            topLeftRadius: isSegmented ? ((isActive || ma.containsMouse) ? (height / 2) : (isFirst ? outerR : innerR)) : (isActive ? height / 2 : outerR)
            bottomLeftRadius: isSegmented ? ((isActive || ma.containsMouse) ? (height / 2) : (isFirst ? outerR : innerR)) : (isActive ? height / 2 : outerR)
            topRightRadius: isSegmented ? ((isActive || ma.containsMouse) ? (height / 2) : (isLast ? outerR : innerR)) : (isActive ? height / 2 : outerR)
            bottomRightRadius: isSegmented ? ((isActive || ma.containsMouse) ? (height / 2) : (isLast ? outerR : innerR)) : (isActive ? height / 2 : outerR)

            Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

            color: isActive 
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                : (ma.containsMouse 
                    ? (pillBtnRoot.hasCustomHover ? Theme.withAlpha(customHoverColor, 0.22) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12))
                    : (isSegmented ? Theme.withAlpha(Theme.surfaceContainerHighest || "#303030", 0.35) : Theme.withAlpha(Theme.onSurface || "#ffffff", 0.05)))

            border.width: 1
            border.color: isActive
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.50)
                : (ma.containsMouse 
                    ? (pillBtnRoot.hasCustomHover ? Theme.withAlpha(customHoverColor, 0.45) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30))
                    : (isSegmented ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)))

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            DankRipple {
                id: rippleObj
                anchors.fill: parent
                cornerRadius: pillBtnBg.topLeftRadius
                rippleColor: Theme.primary
            }
        }

        DankIcon {
            name: iconName; size: iconSize;
            color: isActive
                ? (Theme.primary || "#8D4D57")
                : (ma.containsMouse 
                    ? (pillBtnRoot.hasCustomHover ? customHoverColor : (Theme.surfaceText || Theme.onSurface || (pillBtnRoot.isDark ? "#ffffff" : "#000000"))) 
                    : (Theme.surfaceVariantText || Theme.outline || (pillBtnRoot.isDark ? "#bbbbbb" : "#555555")))
            anchors.centerIn: parent
            rotation: (ma.containsMouse ? (iconName === "stop" ? -360 : 8) : 0) + (isActive ? 360 : 0)
            Behavior on rotation { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
            onPressed: mouse => {
                let mapped = mapToItem(parent, mouse.x, mouse.y);
                rippleObj.trigger(mapped.x, mapped.y);
            }
            onClicked: parent.clicked()
        }
    }



    // Segmented Option Bar for popup option choices (matching SegmentedSetting in Settings.qml)
    component SegmentedBar: Item {
        id: segBarRoot
        property var model: []
        property int currentIndex: 0
        property real buttonHeight: 34
        signal selectionChanged(int idx, string val)

        width: parent.width
        implicitHeight: buttonHeight
        readonly property int count: model ? model.length : 0

        RowLayout {
            anchors.fill: parent
            spacing: 2

            Repeater {
                model: segBarRoot.model

                delegate: Rectangle {
                    id: segBtn
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    readonly property bool isSelected: index === segBarRoot.currentIndex
                    readonly property bool isHovered: segBtnMa.containsMouse
                    readonly property real outerR: Theme.cornerRadius || 12
                    readonly property real innerR: 4

                    topLeftRadius: (isSelected || isHovered) ? (height / 2) : (index === 0 ? outerR : innerR)
                    bottomLeftRadius: (isSelected || isHovered) ? (height / 2) : (index === 0 ? outerR : innerR)
                    topRightRadius: (isSelected || isHovered) ? (height / 2) : (index === segBarRoot.count - 1 ? outerR : innerR)
                    bottomRightRadius: (isSelected || isHovered) ? (height / 2) : (index === segBarRoot.count - 1 ? outerR : innerR)

                    Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                    Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                    Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                    Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                    color: isSelected
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                        : (isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10) : Theme.withAlpha(Theme.surfaceContainerHigh || "#303030", 0.5))

                    border.width: 1
                    border.color: isSelected
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5)
                        : (isHovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10))

                    scale: segBtnMa.pressed ? 0.96 : (isHovered ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    DankRipple {
                        id: segRip
                        anchors.fill: parent
                        cornerRadius: (segBtn.isSelected || segBtn.isHovered) ? (segBtn.height / 2) : (index === 0 || index === segBarRoot.count - 1 ? segBtn.outerR : segBtn.innerR)
                        rippleColor: Theme.primary
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: typeof modelData === "object" ? (modelData.label || modelData.title || "") : String(modelData)
                        font.pixelSize: 12
                        font.weight: isSelected ? Font.Bold : Font.Normal
                        color: isSelected ? Theme.primary : (isHovered ? Theme.surfaceText : Theme.surfaceVariantText)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: segBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => {
                            let mapped = mapToItem(parent, mouse.x, mouse.y);
                            segRip.trigger(mapped.x, mapped.y);
                        }
                        onClicked: {
                            segBarRoot.currentIndex = index;
                            var val = typeof modelData === "object" ? (modelData.value !== undefined ? modelData.value : modelData.val) : modelData;
                            segBarRoot.selectionChanged(index, val);
                        }
                    }
                }
            }
        }
    }

    component SettingToggle: Rectangle {
        id: toggleRoot
        property string label: ""
        property string iconName: ""
        property bool active: false
        property bool isOption: false // If true, shows a radio/check dot instead of a switch
        property bool isFirst: false
        property bool isLast: false
        property bool isHighlighted: false
        property real outerR: Theme.cornerRadius || 12
        property real innerR: 4
        signal toggled()

        width: parent.width; height: visible ? 46 : 0
        color: (toggleRoot.isHighlighted || toggleRoot.activeFocus) 
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
            : (ma.containsMouse 
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                : Theme.withAlpha(Theme.surfaceContainerHigh || "#303030", 0.5))

        border.width: 1
        border.color: (toggleRoot.isHighlighted || toggleRoot.activeFocus)
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
            : (ma.containsMouse 
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10))

        clip: true
        
        topLeftRadius: (isFirst && isLast) ? outerR : (isFirst ? outerR : innerR)
        topRightRadius: (isFirst && isLast) ? outerR : (isFirst ? outerR : innerR)
        bottomLeftRadius: (isFirst && isLast) ? outerR : (isLast ? outerR : innerR)
        bottomRightRadius: (isFirst && isLast) ? outerR : (isLast ? outerR : innerR)
        
        focus: false
        activeFocusOnTab: false
        Keys.onReturnPressed: toggleRoot.toggled()
        Keys.onEscapePressed: {
            if (root.settingsExpanded || root.delayExpanded || root.monitorExpanded) {
                root.settingsExpanded = false;
                root.delayExpanded = false;
                root.monitorExpanded = false;
                globalKeyHandler.forceActiveFocus();
            } else {
                root.close();
            }
        }

        // DankRipple with matching corner radii
        DankRipple {
            id: toggleRip
            anchors.fill: parent
            cornerRadius: (toggleRoot.isFirst || toggleRoot.isLast) ? toggleRoot.outerR : toggleRoot.innerR
            rippleColor: Theme.primary
        }

        Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutQuart } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
        opacity: visible ? 1 : 0
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12

            // Circular badge container for icon matching Settings.qml
            Rectangle {
                width: 32; height: 32; radius: 16
                color: toggleRoot.active 
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) 
                    : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.45)
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: 150 } }

                DankIcon { 
                    name: toggleRoot.iconName
                    size: 18
                    color: toggleRoot.active ? Theme.primary : Theme.surfaceVariantText
                    anchors.centerIn: parent
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            StyledText { 
                text: toggleRoot.label
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Theme.surfaceText
                Layout.fillWidth: true 
            }
            
            // Toggle Switch
            DankToggle { 
                visible: !toggleRoot.isOption
                scale: 0.85
                transformOrigin: Item.Right
                checked: toggleRoot.active
                onClicked: toggleRoot.toggled()
            }
            
            // Radio/Option Indicator
            Rectangle {
                visible: toggleRoot.isOption
                width: 20; height: 20; radius: 10
                border.width: 1.5
                border.color: toggleRoot.active ? Theme.primary : Theme.withAlpha(Theme.outline || "#ffffff", 0.3)
                color: toggleRoot.active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Rectangle {
                    anchors.centerIn: parent
                    width: 10; height: 10; radius: 5
                    color: Theme.primary
                    visible: toggleRoot.active
                }
            }
        }

        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onPressed: mouse => {
                let mapped = mapToItem(parent, mouse.x, mouse.y);
                toggleRip.trigger(mapped.x, mapped.y);
            }
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
        WlrLayershell.namespace: "dms:plugins:screenCaptureToolbar:pill"

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
                color: Theme.surfaceText || "white"
                font.pixelSize: Theme.fontSizeSmall || 11
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

            color: Theme.withAlpha(Theme.surface || "#252525", root.pillOpacity)
            border.width: root.recPillDragging ? 3 : 1
            border.color: root.recPillDragging ? (Theme.primary || "#38bdf8") : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
            
            Behavior on border.width { NumberAnimation { duration: 300 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
            
            layer.enabled: false
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
            Behavior on opacity { NumberAnimation { duration: 150 } }

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
                        color: root.isPaused ? Theme.surfaceVariantText : (Theme.error || "#FF4444")
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
                        font.pixelSize: Theme.fontSizeLarge ? Theme.fontSizeLarge + 6 : 22
                        font.weight: Font.Medium
                        color: Theme.surfaceText || (recPill.isDark ? "white" : "#333333")
                        font.family: Theme.monoFontFamily || "JetBrains Mono, monospace" // Monospace to prevent shifting
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

                // Stop Button
                PillActionBtn {
                    iconName: "stop"
                    isSegmented: false
                    customHoverColor: Theme.error || "#FF4444"
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
        Behavior on opacity { NumberAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.topMargin: 6; anchors.bottomMargin: 6
            spacing: 12

            // Collapse Handle (Moved to left and rotated to point left)
            Rectangle {
                width: 36; height: 40; radius: 10
                color: Theme.withAlpha(Theme.primary || "#ffffff", 0.1)
                scale: collapseMa.pressed ? 0.92 : (collapseMa.containsMouse ? 1.08 : 1.0)
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                DankIcon {
                    name: "chevron_left"; size: 18;
                    color: (collapseMa.containsMouse || collapseMa.pressed) ? (recPill.isDark ? (Theme.onSurface || "white") : (Theme.surface || "black")) : Theme.primary
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
                radius: Theme.cornerRadius || 12
                color: "transparent"
                border.width: 1; border.color: Qt.rgba(0,0,0,0.05)

                Row {
                    anchors.centerIn: parent
                    spacing: 12
                    Rectangle {
                        width: 10; height: 10; radius: 5; anchors.verticalCenter: parent.verticalCenter
                        color: root.isPaused ? Theme.surfaceVariantText : (Theme.error || "#FF4444")
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
                        font.pixelSize: Theme.fontSizeLarge ? Theme.fontSizeLarge + 6 : 22
                        font.weight: Font.Medium
                        color: Theme.surfaceText || (recPill.isDark ? "white" : "#333333")
                        font.family: Theme.monoFontFamily || "JetBrains Mono, monospace"
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

            // Action Block (Segmented)
            Row {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                PillActionBtn {
                    iconName: "stop"
                    isSegmented: true
                    isFirst: true
                    isLast: false
                    customHoverColor: Theme.error || "#FF4444"
                    onClicked: root.stopRecording()
                }
                PillActionBtn {
                    iconName: root.isPaused ? "play_arrow" : "pause"
                    isSegmented: true
                    isFirst: false
                    isLast: false
                    onClicked: root.isPaused ? root.resumeRecording() : root.pauseRecording()
                }
                PillActionBtn {
                    iconName: root.isMicMuted ? "mic_off" : "mic"
                    visible: root.isMicCaptured
                    isActive: !root.isMicMuted
                    isSegmented: true
                    isFirst: false
                    isLast: false
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
                    isSegmented: true
                    isFirst: false
                    isLast: true
                    onClicked: {
                        root.takeScreenshot();
                    }
                }
            }

            // Drag Handle (Moved to right)
            Rectangle {
                id: moveBtnRoot
                width: 40; height: 40; 
                radius: root.recPillDragging ? 20 : (Theme.cornerRadius || 12)
                color: root.recPillDragging ? (Theme.primary || "#38bdf8") : Theme.withAlpha(Theme.primary || "#ffffff", 0.25)
                scale: moveMa.pressed ? 0.92 : (moveMa.containsMouse ? 1.08 : 1.0)
                clip: true

                Behavior on radius { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 150 } }

                // Hover glow
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: recPill.isDark ? (Theme.surface || "black") : (Theme.onSurface || "white")
                    opacity: moveMa.containsMouse ? 0.1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on radius { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                }

                // DankRipple
                Rectangle {
                    id: moveRippleObj
                    anchors.centerIn: parent
                    width: parent.width * 1.5; height: width
                    radius: width / 2
                    color: recPill.isDark ? (Theme.surface || "black") : (Theme.onSurface || "white")
                    opacity: 0; scale: 0

                    states: State {
                        name: "pressed"; when: moveMa.pressed
                        PropertyChanges { target: moveRippleObj; opacity: 0.2; scale: 1 }
                    }
                    transitions: Transition {
                        NumberAnimation { properties: "opacity,scale"; duration: 150; easing.type: Easing.OutBack }
                    }
                }

                DankIcon {
                    name: "open_with"; size: 16;
                    color: root.recPillDragging
                        ? (recPill.isDark ? (Theme.surface || "black") : (Theme.onPrimary || "white"))
                        : ((moveMa.containsMouse || moveMa.pressed) ? (Theme.onPrimary || "white") : Theme.primary)
                    anchors.centerIn: parent
                    rotation: (moveMa.containsMouse ? 90 : 0) + (root.recPillDragging ? 360 : 0)
                    Behavior on rotation { NumberAnimation { duration: 600; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 150 } }
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
