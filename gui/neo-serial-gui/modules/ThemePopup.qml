import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "controls"

Popup {
    id: popup

    readonly property var app: Window.window
    property var uiSettings

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: app ? app.contentItem : null
    padding: 0
    width: 500
    height: 540
    x: app ? (app.width - width) / 2 : 0
    y: app ? Math.max(12, (app.height - height) / 2) : 0

    background: Rectangle {
        radius: app ? app.cr : 6
        color: app ? app.panelBg : "#ffffff"
        border.color: app ? app.panelBorder : "#d0d7de"
    }

    contentItem: Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "主题与日志样式"
                    font.pixelSize: 13
                    font.bold: true
                    color: app ? app.textColor : "#1f2328"
                }
                Item { Layout.fillWidth: true }
                LightButton {
                    text: "关闭"
                    onClicked: popup.close()
                }
            }

            ScrollView {
                id: themeScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                Column {
                    width: themeScroll.availableWidth
                    spacing: 10

                    Rectangle {
                        width: parent.width
                        implicitHeight: quickThemeColumn.implicitHeight + 20
                        radius: app ? app.cr : 6
                        color: app ? app.controlBg : "#f6f8fa"
                        border.color: app ? app.controlBorder : "#d0d7de"

                        Column {
                            id: quickThemeColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            Label {
                                text: "快速主题"
                                font.pixelSize: 11
                                color: app ? app.subText : "#656d76"
                            }

                            RowLayout {
                                spacing: 8
                                LightButton {
                                    text: "浅色"
                                    onClicked: if (app) app.setTheme("light")
                                }
                                LightButton {
                                    text: "深色"
                                    onClicked: if (app) app.setTheme("dark")
                                }
                                LightButton {
                                    text: "暖色"
                                    onClicked: if (app) app.setTheme("warm")
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        implicitHeight: logStyleColumn.implicitHeight + 20
                        radius: app ? app.cr : 6
                        color: app ? app.controlBg : "#f6f8fa"
                        border.color: app ? app.controlBorder : "#d0d7de"

                        Column {
                            id: logStyleColumn
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Label {
                                text: "通信日志样式"
                                font.pixelSize: 11
                                color: app ? app.subText : "#656d76"
                            }

                            RowLayout {
                                width: parent.width
                                spacing: 8

                                Label {
                                    text: "字体"
                                    font.pixelSize: 11
                                    color: app ? app.subText : "#656d76"
                                    Layout.preferredWidth: 40
                                }

                                LightTextField {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    text: uiSettings ? uiSettings.logFontFamily : ""
                                    onEditingFinished: if (uiSettings) uiSettings.logFontFamily = text
                                }

                                Label {
                                    text: "字号"
                                    font.pixelSize: 11
                                    color: app ? app.subText : "#656d76"
                                    Layout.preferredWidth: 40
                                }

                                LightSpinBox {
                                    from: 8
                                    to: 24
                                    value: uiSettings ? uiSettings.logFontSize : 11
                                    editable: true
                                    Layout.preferredWidth: 88
                                    onValueChanged: if (uiSettings) uiSettings.logFontSize = value
                                }
                            }

                            ColorField { width: parent.width; label: "字母颜色"; targetKey: "letters"; value: uiSettings ? uiSettings.logColorLetters : "#1f2328" }
                            ColorField { width: parent.width; label: "数字颜色"; targetKey: "digits"; value: uiSettings ? uiSettings.logColorDigits : "#1f2328" }
                            ColorField { width: parent.width; label: "符号颜色"; targetKey: "symbols"; value: uiSettings ? uiSettings.logColorSymbols : "#1f2328" }
                            ColorField { width: parent.width; label: "TX 颜色"; targetKey: "tx"; value: uiSettings ? uiSettings.logColorTx : "#0e7a68" }
                            ColorField { width: parent.width; label: "SYS 颜色"; targetKey: "sys"; value: uiSettings ? uiSettings.logColorSys : "#dc6969" }

                            Rectangle {
                                width: parent.width
                                implicitHeight: previewColumn.implicitHeight + 16
                                radius: 4
                                color: app ? app.panelBg : "#ffffff"
                                border.color: app ? app.controlBorder : "#d0d7de"

                                Column {
                                    id: previewColumn
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    Label {
                                        text: "预览（仅演示）"
                                        font.pixelSize: 10
                                        color: app ? app.subText : "#656d76"
                                    }

                                    Text {
                                        textFormat: Text.StyledText
                                        font.family: uiSettings ? uiSettings.logFontFamily : "Consolas"
                                        font.pixelSize: uiSettings ? uiSettings.logFontSize : 11
                                        color: app ? app.textColor : "#1f2328"
                                        width: parent.width
                                        wrapMode: Text.Wrap
                                        text: "<span style='color:%1'>ABCdef</span> " +
                                              "<span style='color:%2'>012345</span> " +
                                              "<span style='color:%3'>!@#$%%</span> " +
                                              "<span style='color:%4'>[TX]</span> " +
                                              "<span style='color:%5'>[SYS]</span>"
                                              .arg(uiSettings ? uiSettings.logColorLetters : "#1f2328")
                                              .arg(uiSettings ? uiSettings.logColorDigits : "#1f2328")
                                              .arg(uiSettings ? uiSettings.logColorSymbols : "#1f2328")
                                              .arg(uiSettings ? uiSettings.logColorTx : "#0e7a68")
                                              .arg(uiSettings ? uiSettings.logColorSys : "#dc6969")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
