import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Services

Column {
    id: root
    width: parent ? parent.width : 0
    spacing: 4

    property string label: ""
    property string text: ""

    StyledText {
        width: parent.width
        text: root.label
        font.pixelSize: Theme.fontSizeSmall
        font.bold: true
        color: Theme.surfaceVariantText
        visible: text !== ""
    }

    Rectangle {
        width: parent.width
        implicitHeight: Math.max(40, cmdRow.implicitHeight + 16)
        color: Theme.surfaceContainer
        radius: 4

        RowLayout {
            id: cmdRow
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.text
                font.family: "Monospace"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondary
                wrapMode: Text.WrapAnywhere
            }

            DankButton {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                iconName: "content_copy"
                backgroundColor: "transparent"
                textColor: Theme.primary
                onClicked: {
                    Proc.runCommand("copy-ipc", ["wl-copy", "--", root.text], function() {
                        ToastService.showInfo("Copied to clipboard");
                    });
                }
            }
        }
    }
}
