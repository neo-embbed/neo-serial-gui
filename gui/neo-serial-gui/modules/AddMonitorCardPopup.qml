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

    property bool advancedMode: false
    property var boolTrueList: []
    property var boolFalseList: []
    property bool editMode: false
    property int editingCardIndex: -1

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    parent: app ? app.contentItem : null
    padding: 0
    width: 420
    height: Math.min((app ? app.height : 600) - 24, addCardContent.implicitHeight + 24)
    x: app ? (app.width - width) / 2 : 0
    y: app ? Math.max(12, (app.height - height) / 2) : 0

    function resetForm() {
        newCardName.text = ""
        newCardPattern.text = ""
        newCardPrefix.text = ""
        newCardSuffix.text = ""
        newCardUnit.text = ""
        newCardColor.text = "#0e7a68"
        newCardTypeCombo.currentIndex = 0
        advancedMode = false
        newCardTypeAdvNumeric.checked = true
        newCardTypeAdvBool.checked = false
        newCardNegative.checked = false
        boolTrueList = ["ON"]
        boolFalseList = ["OFF"]
    }

    function splitPatternParts(pattern) {
        var openIndex = -1
        var closeIndex = -1
        var escaped = false
        var depth = 0
        for (var i = 0; i < pattern.length; ++i) {
            var ch = pattern.charAt(i)
            if (escaped) {
                escaped = false
                continue
            }
            if (ch === "\\") {
                escaped = true
                continue
            }
            if (ch === "(") {
                if (depth === 0)
                    openIndex = i
                depth += 1
            } else if (ch === ")" && depth > 0) {
                depth -= 1
                if (depth === 0) {
                    closeIndex = i
                    break
                }
            }
        }
        if (openIndex < 0 || closeIndex <= openIndex)
            return null
        return {
            prefix: pattern.slice(0, openIndex),
            capture: pattern.slice(openIndex + 1, closeIndex),
            suffix: pattern.slice(closeIndex + 1)
        }
    }

    function unescapeRegexLiteral(text) {
        return String(text).replace(/\\([.*+?^${}()|[\]\\])/g, "$1")
    }

    function populateFromCard(cardIndex) {
        var info = CardBridge.cardAt(cardIndex)
        if (!info || info.id === undefined)
            return false

        resetForm()
        newCardName.text = info.name || ""
        newCardUnit.text = info.unit || ""
        newCardColor.text = info.color || "#0e7a68"

        var pattern = String(info.pattern || "")
        var type = String(info.type || "numeric")
        var simpleLoaded = false

        if (type === "numeric") {
            var numericParts = splitPatternParts(pattern)
            if (numericParts && (numericParts.capture === "\\d+\\.?\\d*" || numericParts.capture === "-?\\d+\\.?\\d*")) {
                advancedMode = false
                newCardTypeCombo.currentIndex = 0
                newCardPrefix.text = unescapeRegexLiteral(numericParts.prefix)
                newCardSuffix.text = unescapeRegexLiteral(numericParts.suffix)
                newCardNegative.checked = numericParts.capture.indexOf("-?") === 0
                simpleLoaded = true
            }
        } else if (type === "boolean") {
            var parts = pattern.split(";")
            var regexPart = parts.length > 0 ? String(parts[0]).trim() : ""
            var boolParts = splitPatternParts(regexPart)
            if (boolParts) {
                advancedMode = false
                newCardTypeCombo.currentIndex = 1
                newCardPrefix.text = unescapeRegexLiteral(boolParts.prefix)
                newCardSuffix.text = unescapeRegexLiteral(boolParts.suffix)
                boolTrueList = ["ON"]
                boolFalseList = ["OFF"]
                for (var j = 1; j < parts.length; ++j) {
                    var part = String(parts[j]).trim()
                    if (part.indexOf("true=") === 0)
                        boolTrueList = part.slice(5).split("|")
                    else if (part.indexOf("false=") === 0)
                        boolFalseList = part.slice(6).split("|")
                }
                simpleLoaded = true
            }
        }

        if (!simpleLoaded) {
            advancedMode = true
            newCardPattern.text = pattern
            if (type === "boolean") {
                newCardTypeAdvBool.checked = true
                newCardTypeAdvNumeric.checked = false
            } else {
                newCardTypeAdvNumeric.checked = true
                newCardTypeAdvBool.checked = false
            }
        }
        return true
    }

    function openForCreate() {
        editMode = false
        editingCardIndex = -1
        resetForm()
        open()
    }

    function openForEdit(cardIndex) {
        if (!populateFromCard(cardIndex))
            return
        editMode = true
        editingCardIndex = cardIndex
        open()
    }

    function buildPattern() {
        if (advancedMode)
            return newCardPattern.text

        var prefix = newCardPrefix.text
        var suffix = newCardSuffix.text
        var isBoolean = newCardTypeCombo.currentIndex === 1

        function escRe(s) {
            return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
        }

        if (isBoolean) {
            var trueWords = []
            var falseWords = []
            for (var i = 0; i < boolTrueList.length; ++i) {
                var tw = boolTrueList[i].trim()
                if (tw.length > 0)
                    trueWords.push(tw)
            }
            for (var j = 0; j < boolFalseList.length; ++j) {
                var fw = boolFalseList[j].trim()
                if (fw.length > 0)
                    falseWords.push(fw)
            }
            if (trueWords.length === 0)
                trueWords = ["ON"]
            if (falseWords.length === 0)
                falseWords = ["OFF"]

            var allKw = trueWords.concat(falseWords).map(escRe)
            var regex = escRe(prefix) + "(" + allKw.join("|") + ")" + escRe(suffix)
            return regex + "; true=" + trueWords.join("|") + "; false=" + falseWords.join("|")
        }

        var neg = newCardNegative.checked ? "-?" : ""
        return escRe(prefix) + "(" + neg + "\\d+\\.?\\d*)" + escRe(suffix)
    }

    function canCreate() {
        if (newCardName.text.length === 0)
            return false
        if (advancedMode)
            return newCardPattern.text.length > 0
        return newCardPrefix.text.length > 0 || newCardSuffix.text.length > 0
    }

    background: Rectangle {
        radius: app ? app.cr : 6
        color: app ? app.panelBg : "#ffffff"
        border.color: app ? app.panelBorder : "#d0d7de"
    }

    onOpened: newCardName.forceActiveFocus()

    contentItem: Item {
        implicitHeight: addCardContent.implicitHeight
        implicitWidth: addCardContent.implicitWidth

        ScrollView {
            anchors.fill: parent
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                id: addCardContent
                width: popup.width - 32
                x: 16
                spacing: 10

                Item { Layout.preferredHeight: 4 }

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: popup.editMode ? "编辑监测卡片" : "新建监测卡片"
                        font.pixelSize: 13
                        font.bold: true
                        color: app ? app.textColor : "#1f2328"
                    }

                    Item { Layout.fillWidth: true }

                    LightButton {
                        text: popup.advancedMode ? "简单模式" : "高级模式"
                        onClicked: popup.advancedMode = !popup.advancedMode
                    }

                    LightButton {
                        text: "关闭"
                        onClicked: popup.close()
                    }
                }

                Label { text: "名称"; font.pixelSize: 11; color: app ? app.subText : "#656d76" }
                LightTextField {
                    id: newCardName
                    Layout.fillWidth: true
                    placeholderText: "例如：温度、电压"
                }

                ColumnLayout {
                    visible: popup.advancedMode
                    Layout.fillWidth: true
                    spacing: 6

                    Label { text: "匹配模式（正则表达式）"; font.pixelSize: 11; color: app ? app.subText : "#656d76" }
                    LightTextField {
                        id: newCardPattern
                        Layout.fillWidth: true
                        placeholderText: "例如：temp=(\\d+\\.?\\d*)"
                    }

                    Label { text: "类型"; font.pixelSize: 11; color: app ? app.subText : "#656d76" }
                    RowLayout {
                        spacing: 12

                        LightRadio {
                            id: newCardTypeAdvNumeric
                            text: "数值 (Numeric)"
                            checked: true
                        }

                        LightRadio {
                            id: newCardTypeAdvBool
                            text: "布尔 (Boolean)"
                        }
                    }
                }

                ColumnLayout {
                    visible: !popup.advancedMode
                    Layout.fillWidth: true
                    spacing: 6

                    Label { text: "匹配规则"; font.pixelSize: 11; color: app ? app.subText : "#656d76" }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        LightTextField {
                            id: newCardPrefix
                            Layout.fillWidth: true
                            placeholderText: "前缀，如 temp="
                        }

                        LightComboBox {
                            id: newCardTypeCombo
                            Layout.preferredWidth: 100
                            model: ["数值", "布尔"]
                        }

                        LightTextField {
                            id: newCardSuffix
                            Layout.fillWidth: true
                            placeholderText: "后缀，如 °C"
                        }
                    }

                    Label {
                        text: {
                            if (newCardTypeCombo.currentIndex === 0)
                                return "将匹配：" + (newCardPrefix.text || "前缀") + "<数值>" + (newCardSuffix.text || "后缀")
                            return "将匹配：" + (newCardPrefix.text || "前缀") + "<关键词>" + (newCardSuffix.text || "后缀")
                        }
                        font.pixelSize: 10
                        color: app ? app.subText : "#656d76"
                        font.italic: true
                    }

                    LightCheckBox {
                        id: newCardNegative
                        visible: newCardTypeCombo.currentIndex === 0
                        text: "支持负数"
                    }

                    ColumnLayout {
                        visible: newCardTypeCombo.currentIndex === 1
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            Label { text: "True 关键词"; font.pixelSize: 11; color: app ? app.subText : "#656d76" }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 22
                                height: 22
                                radius: app ? app.cr : 6
                                color: addTrueMa.pressed ? (app ? app.buttonPress : "#d8dee4")
                                     : addTrueMa.containsMouse ? (app ? app.buttonHover : "#eef2f6")
                                     : (app ? app.buttonBg : "#f6f8fa")
                                border.color: app ? app.controlBorder : "#d0d7de"

                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    font.pixelSize: 13
                                    color: app ? app.primary : "#0e7a68"
                                }

                                MouseArea {
                                    id: addTrueMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var l = popup.boolTrueList.slice()
                                        l.push("")
                                        popup.boolTrueList = l
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: popup.boolTrueList.length

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                LightTextField {
                                    Layout.fillWidth: true
                                    text: popup.boolTrueList[index]
                                    placeholderText: "如 ON、YES、1"
                                    onTextEdited: {
                                        var l = popup.boolTrueList.slice()
                                        l[index] = text
                                        popup.boolTrueList = l
                                    }
                                }

                                LightButton {
                                    text: "×"
                                    visible: popup.boolTrueList.length > 1
                                    onClicked: {
                                        var l = popup.boolTrueList.slice()
                                        l.splice(index, 1)
                                        popup.boolTrueList = l
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Label { text: "False 关键词"; font.pixelSize: 11; color: app ? app.subText : "#656d76" }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 22
                                height: 22
                                radius: app ? app.cr : 6
                                color: addFalseMa.pressed ? (app ? app.buttonPress : "#d8dee4")
                                     : addFalseMa.containsMouse ? (app ? app.buttonHover : "#eef2f6")
                                     : (app ? app.buttonBg : "#f6f8fa")
                                border.color: app ? app.controlBorder : "#d0d7de"

                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    font.pixelSize: 13
                                    color: app ? app.primary : "#0e7a68"
                                }

                                MouseArea {
                                    id: addFalseMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var l = popup.boolFalseList.slice()
                                        l.push("")
                                        popup.boolFalseList = l
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: popup.boolFalseList.length

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                LightTextField {
                                    Layout.fillWidth: true
                                    text: popup.boolFalseList[index]
                                    placeholderText: "如 OFF、NO、0"
                                    onTextEdited: {
                                        var l = popup.boolFalseList.slice()
                                        l[index] = text
                                        popup.boolFalseList = l
                                    }
                                }

                                LightButton {
                                    text: "×"
                                    visible: popup.boolFalseList.length > 1
                                    onClicked: {
                                        var l = popup.boolFalseList.slice()
                                        l.splice(index, 1)
                                        popup.boolFalseList = l
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Label { text: "单位"; font.pixelSize: 11; color: app ? app.subText : "#656d76" }
                        LightTextField {
                            id: newCardUnit
                            Layout.fillWidth: true
                            placeholderText: "例如：°C、V、A"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Label { text: "颜色"; font.pixelSize: 11; color: app ? app.subText : "#656d76" }
                        RowLayout {
                            spacing: 4

                            Rectangle {
                                width: 16
                                height: 16
                                radius: 4
                                color: app ? (app.normalizeColorValue(newCardColor.text) || "#000000") : "#000000"
                                border.color: app ? app.controlBorder : "#d0d7de"
                            }

                            LightTextField {
                                id: newCardColor
                                Layout.fillWidth: true
                                text: "#0e7a68"
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4

                    Label {
                        visible: !popup.advancedMode
                        text: "生成: " + popup.buildPattern()
                        font.pixelSize: 9
                        color: app ? app.subText : "#656d76"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Item {
                        visible: popup.advancedMode
                        Layout.fillWidth: true
                    }

                    PrimaryButton {
                        text: popup.editMode ? "保存" : "创建"
                        enabled: popup.canCreate()
                        onClicked: {
                            var pattern = popup.buildPattern()
                            var cardType
                            if (popup.advancedMode)
                                cardType = newCardTypeAdvNumeric.checked ? "numeric" : "boolean"
                            else
                                cardType = newCardTypeCombo.currentIndex === 0 ? "numeric" : "boolean"

                            var color = app ? app.normalizeColorValue(newCardColor.text) : newCardColor.text
                            if (!color)
                                color = "#0e7a68"

                            if (popup.editMode) {
                                CardBridge.updateCard(popup.editingCardIndex, {
                                    "name": newCardName.text,
                                    "pattern": pattern,
                                    "type": cardType,
                                    "unit": newCardUnit.text,
                                    "color": color
                                })
                                var editedItem = cardRepeaterRef && cardRepeaterRef.count > popup.editingCardIndex
                                               ? cardRepeaterRef.itemAt(popup.editingCardIndex) : null
                                if (editedItem)
                                    editedItem.cardInfo = CardBridge.cardAt(popup.editingCardIndex)
                                if (app) {
                                    app.autoSaveCards()
                                    app.showToast("已更新卡片：" + newCardName.text)
                                }
                                popup.close()
                            } else {
                                CardBridge.addCard(newCardName.text, pattern, cardType, newCardUnit.text, color)
                                var newId = CardBridge.cardAt(CardBridge.cardCount - 1).id
                                var vw = cardAreaRef ? cardAreaRef.width : 400
                                var vh = cardAreaRef ? cardAreaRef.height : 300
                                var cameraX = cardAreaRef ? cardAreaRef.cameraX : 0
                                var cameraY = cardAreaRef ? cardAreaRef.cameraY : 0
                                var cameraScale = cardAreaRef ? cardAreaRef.cameraScale : 1
                                var spawnX = (vw / 2.0 - cameraX) / cameraScale - 85
                                var spawnY = (vh / 2.0 - cameraY) / cameraScale - 65
                                if (app) {
                                    spawnX = app.snapToGrid(spawnX)
                                    spawnY = app.snapToGrid(spawnY)
                                    app.setCardLayout(newId, "x", spawnX)
                                    app.setCardLayout(newId, "y", spawnY)
                                    app.autoSaveCards()
                                    app.showToast("已创建卡片：" + newCardName.text)
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
}
