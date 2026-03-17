import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: root
    width: 1280
    height: 760
    minimumWidth: 1024
    minimumHeight: 680
    visible: true
    title: qsTr("Neo UART Assistant")
    color: "#f4f6fb"

    palette.text: "#0f1c2b"
    palette.windowText: "#0f1c2b"
    palette.buttonText: "#0f1c2b"
    palette.placeholderText: "#4e5f74"

    readonly property color bgTop: "#fbf8f2"
    readonly property color bgBottom: "#eef5ff"
    readonly property color panelBg: "#fdfefe"
    readonly property color panelBorder: "#d7e0ea"
    readonly property color textColor: "#000000"
    readonly property color subText: "#000000"
    readonly property color primary: "#0e7a68"
    readonly property color primaryStrong: "#055f51"

    readonly property int controlRadius: 10
    readonly property color controlBg: "#f8fbff"
    readonly property color controlBorder: "#b6c5d7"
    readonly property color buttonBg: "#e8eef6"

    // Background gradient (page base)
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.bgTop }
            GradientStop { position: 1.0; color: root.bgBottom }
        }
    }

    // Background shape A (top-right)

    Rectangle {
        width: 320
        height: 320
        radius: 160
        color: "#3aa28f"
        opacity: 0.2
        anchors.right: parent.right
        anchors.rightMargin: -60
        anchors.top: parent.top
        anchors.topMargin: -80
        layer.enabled: true
        layer.smooth: true
    }

    // Background shape B (bottom-left)

    Rectangle {
        width: 420
        height: 420
        radius: 210
        color: "#2f6edc"
        opacity: 0.18
        anchors.left: parent.left
        anchors.leftMargin: -140
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -180
        layer.enabled: true
        layer.smooth: true
    }

    // Main scroll container
    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: Math.max(root.width, 1200)
        clip: true

        // App shell: overall page layout
        ColumnLayout {
            id: appShell
            width: Math.max(scroll.width - 48, 1200)
            spacing: 16
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 24

            // Performance warning banner
            Rectangle {
                Layout.fillWidth: true
                color: "#fff1de"
                border.color: "#ffb84d"
                radius: 12
                Layout.preferredHeight: 64

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Label {
                        text: "⚠"
                        font.pixelSize: 18
                        color: "#8f341f"
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "性能提示：在卡片众多且串口接收频率高的场景下，长时间运行可能出现性能问题。建议将需要串口发送的测试和多参数监控测试分开进行。"
                        wrapMode: Text.WordWrap
                        color: "#8f341f"
                        font.pixelSize: 12
                    }
                    ToolButton {
                        background: Rectangle {
                            radius: 6
                            color: root.buttonBg
                            border.color: root.controlBorder
                        }
                        text: "✕"
                        onClicked: parent.parent.visible = false
                    }
                }
            }

            // Top bar: brand + status
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Brand area
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Label {
                        text: "Neo UART Assistant"
                        font.pixelSize: 28
                        font.bold: true
                        color: root.textColor
                    }
                    TextField {
                        background: Rectangle {
                            radius: root.controlRadius
                            color: root.controlBg
                            border.color: root.controlBorder
                        }
                        Layout.preferredWidth: 320
                        placeholderText: "可自定义文本"
                        text: "可自定义文本"
                    }
                }

                // Status badges
                RowLayout {
                    spacing: 8
                    Rectangle {
                        radius: 14
                        color: "#205d52"
                        Layout.preferredHeight: 30
                        Layout.preferredWidth: 110
                        Label {
                            anchors.centerIn: parent
                            text: "串口未连接"
                            color: "#e9f6f2"
                            font.pixelSize: 12
                        }
                    }
                }
            }

            // Main split: left cards + right serial
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                // Left column: cards area (blank placeholder)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 800
                    spacing: 14

                    // Placeholder panel for cards area
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"
                        border.color: "#d9e2ec"
                        radius: 16
                    }
                }

                // Right column: serial assistant
                ColumnLayout {
                    Layout.preferredWidth: 420
                    Layout.fillWidth: true
                    spacing: 12

                    // Tabs (visual only)
                    RowLayout {
                        spacing: 8
                        Button {
                            background: Rectangle {
                                radius: root.controlRadius
                                color: root.buttonBg
                                border.color: root.controlBorder
                            }
                            text: "串口助手"
                        }
                        Button {
                            background: Rectangle {
                                radius: root.controlRadius
                                color: root.buttonBg
                                border.color: root.controlBorder
                            }
                            text: "系统设置"
                        }
                    }

                    // Serial controls panel
                    // Send panel
                    Rectangle {
                        Layout.fillWidth: true
                        color: root.panelBg
                        border.color: root.panelBorder
                        radius: 16
                        Layout.preferredHeight: 200

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            RowLayout {
                                spacing: 12
                                ColumnLayout {
                                    spacing: 5
                                    Label { text: "串口"; color: root.subText; font.pixelSize: 12 }
                                    ComboBox {
                                        background: Rectangle {
                                            radius: root.controlRadius
                                            color: root.controlBg
                                            border.color: root.controlBorder
                                        }
                                        model: ["COM1", "COM2"]
                                    }
                                }
                                ColumnLayout {
                                    spacing: 5
                                    Label { text: "波特率"; color: root.subText; font.pixelSize: 12 }
                                    ComboBox {
                                        background: Rectangle {
                                            radius: root.controlRadius
                                            color: root.controlBg
                                            border.color: root.controlBorder
                                        }
                                        model: ["9600", "57600", "115200", "230400", "921600"]
                                    }
                                }
                            }

                            ColumnLayout {
                                spacing: 5
                                Label { text: "手动输入端口（可选）"; color: root.subText; font.pixelSize: 12 }
                                TextField {
                                    background: Rectangle {
                                        radius: root.controlRadius
                                        color: root.controlBg
                                        border.color: root.controlBorder
                                    }
                                    placeholderText: "例如：COM5"
                                }
                            }

                            RowLayout {
                                spacing: 8
                                Button {
                                    background: Rectangle {
                                        radius: root.controlRadius
                                        color: root.buttonBg
                                        border.color: root.controlBorder
                                    }
                                    text: "刷新串口"
                                }
                                Button {
                                    background: Rectangle {
                                        radius: root.controlRadius
                                        color: root.buttonBg
                                        border.color: root.controlBorder
                                    }
                                    text: "连接"
                                }
                                Button {
                                    background: Rectangle {
                                        radius: root.controlRadius
                                        color: root.buttonBg
                                        border.color: root.controlBorder
                                    }
                                    text: "断开"
                                }
                            }
                        }
                    }

                    // Terminal/log panel
                    Rectangle {
                        Layout.fillWidth: true
                        color: root.panelBg
                        border.color: root.panelBorder
                        radius: 16
                        Layout.preferredHeight: 240

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8
                            Label { text: "通信日志"; font.bold: true }
                            // Terminal preview area
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 12
                                color: "#071420"
                                border.color: "#223f5f"
                                Text {
                                    anchors.centerIn: parent
                                    text: "日志预览区域"
                                    color: "#d8e8fb"
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        color: root.panelBg
                        border.color: root.panelBorder
                        radius: 16
                        Layout.preferredHeight: 200

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            ColumnLayout {
                                spacing: 5
                                Label { text: "发送模式"; color: root.subText; font.pixelSize: 12 }
                                ComboBox {
                                    background: Rectangle {
                                        radius: root.controlRadius
                                        color: root.controlBg
                                        border.color: root.controlBorder
                                    }
                                    model: ["Text (文本)", "Hex (十六进制)"]
                                }
                            }
                            RowLayout {
                                spacing: 6
                                CheckBox { text: "发送 Text 时自动追加换行" }
                            }
                            TextArea {
                                background: Rectangle {
                                    radius: root.controlRadius
                                    color: root.controlBg
                                    border.color: root.controlBorder
                                }
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                placeholderText: "输入要发送的数据..."
                            }
                            RowLayout {
                                spacing: 8
                                Button {
                                    background: Rectangle {
                                        radius: root.controlRadius
                                        color: root.buttonBg
                                        border.color: root.controlBorder
                                    }
                                    text: "清空日志"
                                }
                                Button {
                                    background: Rectangle {
                                        radius: root.controlRadius
                                        color: root.buttonBg
                                        border.color: root.controlBorder
                                    }
                                    text: "发送"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
