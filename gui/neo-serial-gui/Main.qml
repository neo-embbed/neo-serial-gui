import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: root
    width: 900
    height: 600
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    title: SessionBridge.connected
           ? qsTr("Neo UART Assistant - %1").arg(SessionBridge.detail)
           : qsTr("Neo UART Assistant")
    color: "#f0f2f5"

    readonly property color panelBg: "#ffffff"
    readonly property color panelBorder: "#d0d7de"
    readonly property color textColor: "#1f2328"
    readonly property color subText: "#656d76"
    readonly property color primary: "#0e7a68"
    readonly property color controlBg: "#f6f8fa"
    readonly property color controlBorder: "#d0d7de"
    readonly property color buttonBg: "#f0f2f5"
    readonly property color buttonHover: "#e4e8ec"
    readonly property color buttonPress: "#d8dce0"
    readonly property color dangerText: "#dc6969"

    readonly property int cr: 6

    // ── Reusable components ──────────────────────────────────

    component LightButton: Button {
        id: _btn
        font.pixelSize: 11
        topPadding: 4; bottomPadding: 4
        leftPadding: 10; rightPadding: 10
        opacity: enabled ? 1.0 : 0.4
        contentItem: Text {
            text: _btn.text
            font: _btn.font
            color: root.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: root.cr
            color: _btn.pressed ? root.buttonPress
                 : _btn.hovered ? root.buttonHover
                 : root.buttonBg
            border.color: root.controlBorder
        }
    }

    component PrimaryButton: Button {
        id: _pbtn
        font.pixelSize: 11
        topPadding: 4; bottomPadding: 4
        leftPadding: 12; rightPadding: 12
        opacity: enabled ? 1.0 : 0.4
        contentItem: Text {
            text: _pbtn.text
            font: _pbtn.font
            color: "#ffffff"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: root.cr
            color: _pbtn.pressed ? "#055f51"
                 : _pbtn.hovered ? "#0a6d5e"
                 : root.primary
        }
    }

    component LightComboBox: ComboBox {
        id: _combo
        font.pixelSize: 12
        topPadding: 3; bottomPadding: 3
        opacity: enabled ? 1.0 : 0.5
        contentItem: Text {
            leftPadding: 6
            text: _combo.displayText
            font: _combo.font
            color: root.textColor
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            implicitHeight: 26
            radius: root.cr
            color: root.controlBg
            border.color: root.controlBorder
        }
        indicator: Text {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "▾"
            font.pixelSize: 10
            color: root.subText
        }
    }

    component LightTextField: TextField {
        font.pixelSize: 12
        color: root.textColor
        placeholderTextColor: root.subText
        leftPadding: 6; rightPadding: 6
        topPadding: 4; bottomPadding: 4
        opacity: enabled ? 1.0 : 0.5
        background: Rectangle {
            implicitHeight: 26
            radius: root.cr
            color: root.controlBg
            border.color: root.controlBorder
        }
    }

    component LightRadio: RadioButton {
        id: _radio
        font.pixelSize: 11
        opacity: enabled ? 1.0 : 0.5
        contentItem: Text {
            text: _radio.text
            font: _radio.font
            color: root.textColor
            leftPadding: _radio.indicator.width + _radio.spacing
            verticalAlignment: Text.AlignVCenter
        }
        indicator: Rectangle {
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            radius: 8
            color: root.controlBg
            border.color: _radio.checked ? root.primary : root.controlBorder
            Rectangle {
                anchors.centerIn: parent
                width: 8; height: 8
                radius: 4
                color: root.primary
                visible: _radio.checked
            }
        }
    }

    component LightCheckBox: CheckBox {
        id: _chk
        font.pixelSize: 11
        opacity: enabled ? 1.0 : 0.5
        contentItem: Text {
            text: _chk.text
            font: _chk.font
            color: root.textColor
            leftPadding: _chk.indicator.width + _chk.spacing
            verticalAlignment: Text.AlignVCenter
        }
        indicator: Rectangle {
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            radius: 3
            color: _chk.checked ? root.primary : root.controlBg
            border.color: _chk.checked ? root.primary : root.controlBorder
            Text {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 11
                color: "#ffffff"
                visible: _chk.checked
            }
        }
    }

    // ── Toast notification ───────────────────────────────────

    Rectangle {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        radius: root.cr
        color: "#1f2328"
        opacity: 0
        implicitWidth: toastLabel.implicitWidth + 24
        implicitHeight: toastLabel.implicitHeight + 12
        z: 100

        Label {
            id: toastLabel
            anchors.centerIn: parent
            color: "#ffffff"
            font.pixelSize: 12
        }

        SequentialAnimation {
            id: toastAnim
            NumberAnimation { target: toast; property: "opacity"; to: 0.9; duration: 150 }
            PauseAnimation { duration: 2000 }
            NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 300 }
        }
    }

    function showToast(msg) {
        toastLabel.text = msg
        toastAnim.restart()
    }

    // ── Layout ───────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // Top bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: "Neo UART Assistant"
                font.pixelSize: 16
                font.bold: true
                color: root.textColor
            }
            Item { Layout.fillWidth: true }

            // Detail label (connection info or error)
            Label {
                visible: SessionBridge.detail.length > 0
                text: SessionBridge.detail
                font.pixelSize: 11
                color: root.subText
            }

            Rectangle {
                radius: 10
                color: SessionBridge.connected ? "#e6f4f1" : "#fef2f2"
                border.color: SessionBridge.connected ? root.primary : root.dangerText
                implicitHeight: 22
                implicitWidth: statusLabel.implicitWidth + 16
                Label {
                    id: statusLabel
                    anchors.centerIn: parent
                    text: SessionBridge.connected ? "已连接" : "未连接"
                    color: SessionBridge.connected ? root.primary : root.dangerText
                    font.pixelSize: 11
                }
            }
        }

        // Main content
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            // Left: cards area placeholder
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.panelBg
                border.color: root.panelBorder
                radius: root.cr
                Label {
                    anchors.centerIn: parent
                    text: "卡片区域"
                    color: root.subText
                }
            }

            // Right: serial panel
            ColumnLayout {
                Layout.preferredWidth: 320
                Layout.maximumWidth: 380
                Layout.fillHeight: true
                spacing: 6

                // ── Serial connection panel ──────────────────

                Rectangle {
                    Layout.fillWidth: true
                    color: root.panelBg
                    border.color: root.panelBorder
                    radius: root.cr
                    implicitHeight: connCol.implicitHeight + 16

                    ColumnLayout {
                        id: connCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            spacing: 6
                            Label { text: "串口"; font.pixelSize: 11; color: root.subText }
                            LightComboBox {
                                id: portCombo
                                Layout.preferredWidth: 90
                                model: SessionBridge.portList
                                enabled: !SessionBridge.connected
                            }
                            Label { text: "波特率"; font.pixelSize: 11; color: root.subText }
                            LightComboBox {
                                id: baudCombo
                                Layout.preferredWidth: 90
                                model: ["9600", "57600", "115200", "230400", "921600"]
                                currentIndex: 2
                                enabled: !SessionBridge.connected
                            }
                        }
                        RowLayout {
                            spacing: 4
                            LightTextField {
                                id: manualPort
                                Layout.fillWidth: true
                                placeholderText: "手动端口，如 COM5"
                                enabled: !SessionBridge.connected
                                Keys.onReturnPressed: doConnect()
                            }
                            LightButton {
                                text: "刷新"
                                enabled: !SessionBridge.connected
                                onClicked: {
                                    SessionBridge.refreshPorts()
                                    showToast("已刷新，发现 %1 个端口".arg(SessionBridge.portList.length))
                                }
                            }
                            PrimaryButton {
                                text: SessionBridge.connected ? "已连接" : "连接"
                                enabled: !SessionBridge.connected
                                onClicked: doConnect()
                            }
                            LightButton {
                                text: "断开"
                                enabled: SessionBridge.connected
                                onClicked: {
                                    SessionBridge.disconnectPort()
                                    showToast("已断开连接")
                                }
                            }
                        }
                    }
                }

                // ── Log panel ────────────────────────────────

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.panelBg
                    border.color: root.panelBorder
                    radius: root.cr

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "通信日志"
                                font.pixelSize: 12
                                font.bold: true
                                color: root.textColor
                            }
                            Item { Layout.fillWidth: true }
                            LightCheckBox {
                                id: autoScrollCheck
                                text: "自动滚动"
                                checked: true
                                font.pixelSize: 10
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 4
                            color: "#fafbfc"
                            border.color: root.controlBorder

                            Flickable {
                                id: logFlick
                                anchors.fill: parent
                                anchors.margins: 4
                                contentWidth: width
                                contentHeight: logArea.implicitHeight
                                clip: true
                                flickableDirection: Flickable.VerticalFlick
                                boundsBehavior: Flickable.StopAtBounds

                                TextArea {
                                    id: logArea
                                    width: logFlick.width
                                    readOnly: true
                                    color: root.textColor
                                    font.family: "Consolas"
                                    font.pixelSize: 11
                                    text: SessionBridge.log
                                    wrapMode: TextArea.Wrap
                                    background: null
                                    textFormat: TextEdit.PlainText

                                    onTextChanged: {
                                        if (autoScrollCheck.checked) {
                                            Qt.callLater(function() {
                                                logFlick.contentY = Math.max(0, logFlick.contentHeight - logFlick.height)
                                            })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Send panel ───────────────────────────────

                Rectangle {
                    Layout.fillWidth: true
                    color: root.panelBg
                    border.color: root.panelBorder
                    radius: root.cr
                    implicitHeight: sendCol.implicitHeight + 16

                    ColumnLayout {
                        id: sendCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        RowLayout {
                            spacing: 6
                            LightRadio {
                                id: modeText
                                text: "Text"
                                checked: true
                            }
                            LightRadio {
                                id: modeHex
                                text: "Hex"
                            }
                            LightCheckBox {
                                id: autoNewline
                                text: "自动换行"
                                checked: true
                                visible: modeText.checked
                            }
                        }
                        TextArea {
                            id: sendInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            font.pixelSize: 12
                            color: root.textColor
                            placeholderTextColor: root.subText
                            enabled: SessionBridge.connected
                            placeholderText: modeText.checked
                                ? "输入要发送的文本..."
                                : "输入十六进制，如 48 65 6C 6C 6F"
                            leftPadding: 6; rightPadding: 6
                            topPadding: 4; bottomPadding: 4
                            background: Rectangle {
                                radius: root.cr
                                color: root.controlBg
                                border.color: root.controlBorder
                            }
                            Keys.onReturnPressed: function(event) {
                                if (event.modifiers & Qt.ControlModifier) {
                                    doSend()
                                }
                            }
                        }
                        RowLayout {
                            spacing: 4
                            Label {
                                visible: modeText.checked
                                text: "Ctrl+Enter 发送"
                                font.pixelSize: 10
                                color: root.subText
                            }
                            Item { Layout.fillWidth: true }
                            LightButton {
                                text: "清空日志"
                                onClicked: {
                                    SessionBridge.clearLog()
                                    showToast("日志已清空")
                                }
                            }
                            PrimaryButton {
                                text: "发送"
                                enabled: SessionBridge.connected && sendInput.text.length > 0
                                onClicked: doSend()
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Functions ────────────────────────────────────────────

    function doConnect() {
        var port = manualPort.text.length > 0
                 ? manualPort.text
                 : portCombo.currentText
        if (port.length === 0) {
            showToast("请选择或输入串口")
            return
        }
        var baud = parseInt(baudCombo.currentText)
        var ok = SessionBridge.connectPort(port, baud)
        if (ok) {
            showToast("连接 %1 @ %2".arg(port).arg(baud))
        } else {
            showToast("连接失败，请检查端口是否被占用")
        }
    }

    function doSend() {
        var data = sendInput.text
        if (data.length === 0) return

        var ok
        if (modeHex.checked) {
            ok = SessionBridge.sendHex(data)
            if (!ok) {
                showToast("Hex 格式错误，请使用如 48 65 6C 格式")
                return
            }
        } else {
            if (autoNewline.checked) data += "\n"
            ok = SessionBridge.send(data)
            if (!ok) {
                showToast("发送失败，连接可能已断开")
                return
            }
        }
        sendInput.clear()
    }
}
