import QtQuick
import QtQuick.Controls
import QtQuick.Window

ComboBox {
    id: control

    readonly property var app: Window.window

    font.pixelSize: 12
    topPadding: 3
    bottomPadding: 3
    opacity: enabled ? 1.0 : 0.5

    contentItem: Text {
        leftPadding: 6
        text: control.displayText
        font: control.font
        color: control.app ? control.app.textColor : "#1f2328"
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        implicitHeight: 26
        radius: control.app ? control.app.cr : 6
        color: control.app ? control.app.controlBg : "#f6f8fa"
        border.color: control.app ? control.app.controlBorder : "#d0d7de"
    }

    indicator: Text {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: "▾"
        font.pixelSize: 10
        color: control.app ? control.app.subText : "#656d76"
    }
}

