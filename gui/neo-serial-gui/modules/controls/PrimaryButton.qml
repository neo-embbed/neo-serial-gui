import QtQuick
import QtQuick.Controls
import QtQuick.Window

Button {
    id: control

    readonly property var app: Window.window

    font.pixelSize: 11
    topPadding: 4
    bottomPadding: 4
    leftPadding: 12
    rightPadding: 12
    opacity: enabled ? 1.0 : 0.4

    contentItem: Text {
        text: control.text
        font: control.font
        color: "#ffffff"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: control.app ? control.app.cr : 6
        color: control.pressed ? "#055f51"
             : control.hovered ? "#0a6d5e"
             : (control.app ? control.app.primary : "#0e7a68")
    }
}

