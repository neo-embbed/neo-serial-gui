import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "controls"

Popup {
    id: popup

    readonly property var app: Window.window
    property var cardAreaRef
    property var cardRepeaterRef
    property bool editMode: false
    property int editingCardIndex: -1

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: app ? app.contentItem : null
    padding: 0
    width: 420
    height: Math.min((app ? app.height : 600) - 24, controlCardContent.implicitHeight + 24)
    x: app ? (app.width - width) / 2 : 0
    y: app ? Math.max(12, (app.height - height) / 2) : 0

    function resetForm() {
        controlCardName.text = ""
        controlCardSendText.text = ""
    }

    function openForCreate() {
        editMode = false
        editingCardIndex = -1
        resetForm()
        open()
    }

    function openForEdit(cardIndex) {
        var info = CardBridge.cardAt(cardIndex)
        if (!info || info.kind !== "control")
            return
        editMode = true
        editingCardIndex = cardIndex
        controlCardName.text = info.name || ""
        controlCardSendText.text = info.send_text || ""
        open()
    }

    background: Rectangle {
        radius: app ? app.cr : 6
        color: app ? app.panelBg : "#ffffff"
        border.color: app ? app.panelBorder : "#d0d7de"
    }

    onOpened: controlCardName.forceActiveFocus()

    contentItem: Item {
        implicitHeight: controlCardContent.implicitHeight
        implicitWidth: controlCardContent.implicitWidth

        ColumnLayout {
            id: controlCardContent
            width: popup.width - 32
            x: 16
            spacing: 10

            Item { Layout.preferredHeight: 4 }

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: popup.editMode ? "编辑控制卡片" : "新建控制卡片"
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

            Label { text: "标题"; font.pixelSize: 11; color: app ? app.subText : "#656d76" }
            LightTextField {
                id: controlCardName
                Layout.fillWidth: true
                placeholderText: "例如：启动设备"
            }

            Label { text: "串口发送文本"; font.pixelSize: 11; color: app ? app.subText : "#656d76" }
            TextArea {
                id: controlCardSendText
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                font.pixelSize: 12
                color: app ? app.textColor : "#1f2328"
                placeholderText: "输入点击发送按钮后要发送的文本"
                placeholderTextColor: app ? app.subText : "#656d76"
                wrapMode: TextEdit.Wrap
                leftPadding: 6
                rightPadding: 6
                topPadding: 6
                bottomPadding: 6
                background: Rectangle {
                    radius: app ? app.cr : 6
                    color: app ? app.controlBg : "#f6f8fa"
                    border.color: app ? app.controlBorder : "#d0d7de"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                PrimaryButton {
                    text: popup.editMode ? "保存" : "创建"
                    enabled: controlCardName.text.trim().length > 0
                    onClicked: {
                        if (popup.editMode) {
                            CardBridge.updateCard(popup.editingCardIndex, {
                                "name": controlCardName.text,
                                "send_text": controlCardSendText.text
                            })
                            var editedItem = cardRepeaterRef && cardRepeaterRef.count > popup.editingCardIndex
                                           ? cardRepeaterRef.itemAt(popup.editingCardIndex) : null
                            if (editedItem)
                                editedItem.cardInfo = CardBridge.cardAt(popup.editingCardIndex)
                            if (app) {
                                app.autoSaveCards()
                                app.showToast("已更新控制卡片：" + controlCardName.text)
                            }
                            popup.close()
                        } else {
                            CardBridge.addControlCard(controlCardName.text, controlCardSendText.text)
                            var newId = CardBridge.cardAt(CardBridge.cardCount - 1).id
                            var vw = cardAreaRef ? cardAreaRef.width : 400
                            var vh = cardAreaRef ? cardAreaRef.height : 300
                            var spawnX = (vw / 2.0 - cardAreaRef.cameraX) / cardAreaRef.cameraScale - 85
                            var spawnY = (vh / 2.0 - cardAreaRef.cameraY) / cardAreaRef.cameraScale - 65
                            if (app) {
                                spawnX = app.snapToGrid(spawnX)
                                spawnY = app.snapToGrid(spawnY)
                                app.setCardLayout(newId, "x", spawnX)
                                app.setCardLayout(newId, "y", spawnY)
                                app.autoSaveCards()
                                app.showToast("已创建控制卡片：" + controlCardName.text)
                            }
                            popup.close()
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 4 }
        }
    }
}
