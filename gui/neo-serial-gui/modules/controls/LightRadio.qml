import QtQuick
import QtQuick.Controls
import QtQuick.Window

RadioButton {
    id: control

    readonly property var app: Window.window

    font.pixelSize: 11
    opacity: enabled ? 1.0 : 0.5

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.app ? control.app.textColor : "#1f2328"
        leftPadding: control.indicator.width + control.spacing
        verticalAlignment: Text.AlignVCenter
    }

    indicator: Rectangle {
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 8
        color: control.app ? control.app.controlBg : "#f6f8fa"
        border.color: control.checked
                      ? (control.app ? control.app.primary : "#0e7a68")
                      : (control.app ? control.app.controlBorder : "#d0d7de")

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: control.app ? control.app.primary : "#0e7a68"
            visible: control.checked
        }
    }
}

