import QtQuick
import QtQuick.Controls
import QtQuick.Window

SpinBox {
    id: control

    readonly property var app: Window.window

    editable: true
    font.pixelSize: 12
    implicitHeight: 28
    implicitWidth: 96

    contentItem: TextInput {
        z: 2
        text: control.displayText
        font: control.font
        color: control.app ? control.app.textColor : "#1f2328"
        selectionColor: control.app ? control.app.primary : "#0e7a68"
        selectedTextColor: "#ffffff"
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        readOnly: !control.editable
        validator: control.validator
        inputMethodHints: Qt.ImhDigitsOnly

        onTextEdited: function () {
            if (control.editable)
                control.value = control.valueFromText(text, control.locale)
        }
    }

    up.indicator: Rectangle {
        x: parent.width - width
        y: 0
        width: 26
        height: parent.height / 2
        radius: control.app ? control.app.cr : 6
        color: control.up.pressed
               ? (control.app ? control.app.buttonPress : "#d8dce0")
               : control.up.hovered
                 ? (control.app ? control.app.buttonHover : "#e4e8ec")
                 : (control.app ? control.app.buttonBg : "#f0f2f5")
        border.color: control.app ? control.app.controlBorder : "#d0d7de"

        Text {
            anchors.centerIn: parent
            text: "+"
            font.pixelSize: 12
            color: control.app ? control.app.textColor : "#1f2328"
        }
    }

    down.indicator: Rectangle {
        x: parent.width - width
        y: parent.height / 2
        width: 26
        height: parent.height / 2
        radius: control.app ? control.app.cr : 6
        color: control.down.pressed
               ? (control.app ? control.app.buttonPress : "#d8dce0")
               : control.down.hovered
                 ? (control.app ? control.app.buttonHover : "#e4e8ec")
                 : (control.app ? control.app.buttonBg : "#f0f2f5")
        border.color: control.app ? control.app.controlBorder : "#d0d7de"

        Text {
            anchors.centerIn: parent
            text: "-"
            font.pixelSize: 12
            color: control.app ? control.app.textColor : "#1f2328"
        }
    }

    background: Rectangle {
        radius: control.app ? control.app.cr : 6
        color: control.app ? control.app.controlBg : "#f6f8fa"
        border.color: control.app ? control.app.controlBorder : "#d0d7de"
    }
}

