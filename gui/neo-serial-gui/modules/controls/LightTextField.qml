import QtQuick
import QtQuick.Controls
import QtQuick.Window

TextField {
    id: control

    readonly property var app: Window.window

    font.pixelSize: 12
    color: app ? app.textColor : "#1f2328"
    placeholderTextColor: app ? app.subText : "#656d76"
    leftPadding: 6
    rightPadding: 6
    topPadding: 4
    bottomPadding: 4
    opacity: enabled ? 1.0 : 0.5

    background: Rectangle {
        implicitHeight: 26
        radius: control.app ? control.app.cr : 6
        color: control.app ? control.app.controlBg : "#f6f8fa"
        border.color: control.app ? control.app.controlBorder : "#d0d7de"
    }
}

