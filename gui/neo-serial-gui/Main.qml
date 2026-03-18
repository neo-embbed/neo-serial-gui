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
    title: qsTr("Neo UART Assistant")
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

    readonly property int cr: 6

    // Reusable light button component
    component LightButton: Button {
        id: _btn
        font.pixelSize: 11
        topPadding: 4; bottomPadding: 4
        leftPadding: 10; rightPadding: 10
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

    // Reusable light combobox
    component LightComboBox: ComboBox {
        id: _combo
        font.pixelSize: 12
        topPadding: 3; bottomPadding: 3
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

    // Reusable light text field
    component LightTextField: TextField {
        font.pixelSize: 12
        color: root.textColor
        leftPadding: 6; rightPadding: 6
        topPadding: 4; bottomPadding: 4
        background: Rectangle {
            implicitHeight: 26
            radius: root.cr
            color: root.controlBg
            border.color: root.controlBorder
        }
    }

    // Reusable light checkbox
    component LightCheckBox: CheckBox {
        id: _chk
        font.pixelSize: 11
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
            Rectangle {
                radius: 10
                color: "#e6f4f1"
                border.color: root.primary
                implicitHeight: 22
                implicitWidth: statusLabel.implicitWidth + 16
                Label {
                    id: statusLabel
                    anchors.centerIn: parent
                    text: "串口未连接"
                    color: root.primary
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

                // Serial connection
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
                                Layout.preferredWidth: 90
                                model: ["COM1", "COM2"]
                            }
                            Label { text: "波特率"; font.pixelSize: 11; color: root.subText }
                            LightComboBox {
                                Layout.preferredWidth: 90
                                model: ["9600", "57600", "115200", "230400", "921600"]
                            }
                        }
                        RowLayout {
                            spacing: 4
                            LightTextField {
                                Layout.fillWidth: true
                                placeholderText: "手动输入端口，如 COM5"
                            }
                            LightButton { text: "刷新" }
                            LightButton { text: "连接" }
                            LightButton { text: "断开" }
                        }
                    }
                }

                // Log panel
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

                        Label { text: "通信日志"; font.pixelSize: 12; font.bold: true; color: root.textColor }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 4
                            color: "#fafbfc"
                            border.color: root.controlBorder

                            ScrollView {
                                anchors.fill: parent
                                anchors.margins: 4
                                TextArea {
                                    readOnly: true
                                    color: root.textColor
                                    font.family: "Consolas"
                                    font.pixelSize: 11
                                    text: ""
                                    background: null
                                }
                            }
                        }
                    }
                }

                // Send panel
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
                            Label { text: "模式"; font.pixelSize: 11; color: root.subText }
                            LightComboBox {
                                Layout.preferredWidth: 100
                                model: ["Text", "Hex"]
                            }
                            LightCheckBox { text: "自动换行" }
                        }
                        TextArea {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            font.pixelSize: 12
                            color: root.textColor
                            placeholderText: "输入要发送的数据..."
                            leftPadding: 6; rightPadding: 6
                            topPadding: 4; bottomPadding: 4
                            background: Rectangle {
                                radius: root.cr
                                color: root.controlBg
                                border.color: root.controlBorder
                            }
                        }
                        RowLayout {
                            spacing: 4
                            Item { Layout.fillWidth: true }
                            LightButton { text: "清空日志" }
                            LightButton { text: "发送" }
                        }
                    }
                }
            }
        }
    }
}
