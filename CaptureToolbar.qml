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
                                onToggled: { root.copyToClipboard = active; root._save("copyToClipboard", root.copyToClipboard) }
                            }
                            SettingToggle { 
                                label: "Save to Disk"; iconName: "save"; active: root.saveToDisk
                                onToggled: { root.saveToDisk = active; root._save("saveToDisk", root.saveToDisk) }
                            }
                            SettingToggle { 
                                label: "Show Mouse Pointer"; iconName: "mouse"; active: root.showPointer
                                onToggled: { root.showPointer = active; root._save("showPointer", root.showPointer) }
                            }
                            SettingToggle { 
                                label: "Screenshot Editor"; iconName: "output"; active: root.stdout
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
                                DankIcon { name: "image"; size: 18; color: Theme.surfaceVariantText }
                                StyledText { text: "Image Format"; font.pixelSize: 13; color: Theme.surfaceText; Layout.fillWidth: true }
                            }
                            DankButtonGroup {
                                Layout.fillWidth: true; buttonHeight: 30; minButtonWidth: 54
                                scale: 0.95; transformOrigin: Item.Left
                                model: ["PNG", "JPG", "PPM"]
                                currentIndex: root.format === "png" ? 0 : (root.format === "jpg" ? 1 : 2)
                                onSelectionChanged: function(idx, sel) { 
                                    if (sel) { 
                                        var fmts = ["png", "jpg", "ppm"];
                                        root.format = fmts[idx]; 
                                        root._save("format", root.format);
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
                        visible: root.format === "jpg"
                        
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
                                placeholderText: "~/Pictures"
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
                            iconName: "screenshot_region"; active: root.captureMode === "interactive"
                            tooltipText: "Interactive Region"
                            onClicked: { root.captureMode = "interactive"; root.takeScreenshot(); } 
                        }
                        ToolbarBtn { 
                            iconName: "monitor"; active: root.captureMode === "full"
                            tooltipText: "Focused Screen"
                            onClicked: { root.captureMode = "full"; root.takeScreenshot(); } 
                        }
                        ToolbarBtn { 
                            iconName: "monitor_weight"; active: root.captureMode === "all"
                            tooltipText: "All Screens"
                            onClicked: { root.captureMode = "all"; root.takeScreenshot(); } 
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
}





