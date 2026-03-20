import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

RowLayout {
    id: control

    readonly property var app: Window.window

    property string label: ""
    property string targetKey: ""
    property string value: "#000000"

    spacing: 6
    Layout.fillWidth: true
    implicitHeight: 30

    Label {
        text: control.label
        font.pixelSize: 11
        color: control.app ? control.app.subText : "#656d76"
        Layout.preferredWidth: 84
    }

    Rectangle {
        width: 16
        height: 16
        radius: 4
        color: control.value
        border.color: control.app ? control.app.controlBorder : "#d0d7de"
    }

    LightTextField {
        id: colorInput
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        text: control.value

        onEditingFinished: {
            if (!control.app || !control.app.setSettingColor(control.targetKey, text)) {
                text = control.value
                if (control.app && control.app.showToast)
                    control.app.showToast("颜色格式错误，请输入十六进制值，例如 #1f2328")
            }
        }
    }

    LightButton {
        text: "选择"
        Layout.preferredHeight: 28
        onClicked: {
            colorDialog.targetKey = control.targetKey
            colorDialog.selectedColor = control.value
            colorDialog.open()
        }
    }

    onValueChanged: {
        if (!colorInput.activeFocus)
            colorInput.text = control.value
    }

    ColorDialog {
        id: colorDialog
        property string targetKey: ""
        title: "选择颜色"
        onAccepted: {
            if (control.app && control.app.setSettingColor)
                control.app.setSettingColor(targetKey, String(selectedColor))
        }
    }
}

