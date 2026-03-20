import QtQuick
import QtQuick.Controls
import QtQuick.Window

CheckBox {
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
        radius: 3
        color: control.checked
               ? (control.app ? control.app.primary : "#0e7a68")
               : (control.app ? control.app.controlBg : "#f6f8fa")
        border.color: control.checked
                      ? (control.app ? control.app.primary : "#0e7a68")
                      : (control.app ? control.app.controlBorder : "#d0d7de")

        Text {
            anchors.centerIn: parent
            text: "✓"
            font.pixelSize: 11
            color: "#ffffff"
            visible: control.checked
        }
    }
}

