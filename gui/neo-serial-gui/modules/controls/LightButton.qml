import QtQuick
import QtQuick.Controls
import QtQuick.Window

Button {
    id: control

    readonly property var app: Window.window

    font.pixelSize: 11
    topPadding: 4
    bottomPadding: 4
    leftPadding: 10
    rightPadding: 10
    opacity: enabled ? 1.0 : 0.4

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.app ? control.app.textColor : "#1f2328"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: control.app ? control.app.cr : 6
        color: control.pressed
               ? (control.app ? control.app.buttonPress : "#d8dce0")
               : control.hovered
                 ? (control.app ? control.app.buttonHover : "#e4e8ec")
                 : (control.app ? control.app.buttonBg : "#f0f2f5")
        border.color: control.app ? control.app.controlBorder : "#d0d7de"
    }
}

