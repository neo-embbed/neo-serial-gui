import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import "controls"

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
    color: windowBg

    property color windowBg: "#f0f2f5"
    property color panelBg: "#ffffff"
    property color panelBorder: "#d0d7de"
    property color textColor: "#1f2328"
    property color subText: "#656d76"
    property color primary: "#0e7a68"
    property color controlBg: "#f6f8fa"
    property color controlBorder: "#d0d7de"
    property color buttonBg: "#f0f2f5"
    property color buttonHover: "#e4e8ec"
    property color buttonPress: "#d8dce0"
    property color dangerText: "#dc6969"
    property color logBg: "#fafbfc"
    property color statusOkBg: "#e6f4f1"
    property color statusBadBg: "#fef2f2"

    readonly property int cr: 6
    readonly property var themePalette: ({
        "light": {
            windowBg: "#f0f2f5",
            panelBg: "#ffffff",
            panelBorder: "#d0d7de",
            textColor: "#1f2328",
            subText: "#656d76",
            primary: "#0e7a68",
            controlBg: "#f6f8fa",
            controlBorder: "#d0d7de",
            buttonBg: "#f0f2f5",
            buttonHover: "#e4e8ec",
            buttonPress: "#d8dce0",
            dangerText: "#dc6969",
            logBg: "#fafbfc",
            statusOkBg: "#e6f4f1",
            statusBadBg: "#fef2f2"
        },
        "dark": {
            windowBg: "#111418",
            panelBg: "#1b2026",
            panelBorder: "#30363d",
            textColor: "#e6edf3",
            subText: "#9aa4af",
            primary: "#2aa198",
            controlBg: "#141a20",
            controlBorder: "#2b313a",
            buttonBg: "#1b2026",
            buttonHover: "#222a33",
            buttonPress: "#2a333d",
            dangerText: "#ff7b72",
            logBg: "#0f1318",
            statusOkBg: "#0e2a25",
            statusBadBg: "#2a1518"
        },
        "warm": {
            windowBg: "#f7f1e8",
            panelBg: "#fffaf2",
            panelBorder: "#e2d8c8",
            textColor: "#3e342b",
            subText: "#7a6b5c",
            primary: "#b25c2a",
            controlBg: "#f4ede3",
            controlBorder: "#e2d8c8",
            buttonBg: "#f2ebe1",
            buttonHover: "#e8dfd3",
            buttonPress: "#ded4c7",
            dangerText: "#c4534b",
            logBg: "#fbf5ec",
            statusOkBg: "#efe3d6",
            statusBadBg: "#f3e0dc"
        }
    })

    Settings {
        id: uiSettings
        category: "ui"
        property string theme: "light"
        property string logFontFamily: "Consolas"
        property int logFontSize: 11
        property color logColorLetters: "#1f2328"
        property color logColorDigits: "#1f2328"
        property color logColorSymbols: "#1f2328"
        property color logColorTx: "#0e7a68"
        property color logColorSys: "#dc6969"
    }

    Settings {
        id: cardLayoutSettings
        category: "cardLayout"
        property string layoutJson: "{}"
    }

    property var cardLayoutMap: ({})
    property int cardZCounter: 1000

    function loadCardLayout() {
        try { cardLayoutMap = JSON.parse(cardLayoutSettings.layoutJson) }
        catch(e) { cardLayoutMap = {} }
    }

    function initCardZCounter() {
        var maxZ = 0
        for (var k in cardLayoutMap) {
            if (String(k).endsWith("_z")) {
                var v = parseInt(cardLayoutMap[k])
                if (!isNaN(v) && v > maxZ)
                    maxZ = v
            }
        }
        cardZCounter = Math.max(1000, maxZ)
    }

    function saveCardLayout() {
        cardLayoutSettings.layoutJson = JSON.stringify(cardLayoutMap)
    }

    function getCardLayout(cardId, prop, fallback) {
        var key = "c" + cardId + "_" + prop
        return (key in cardLayoutMap) ? cardLayoutMap[key] : fallback
    }

    function setCardLayout(cardId, prop, val) {
        var key = "c" + cardId + "_" + prop
        cardLayoutMap[key] = val
        saveCardLayout()
    }

    function raiseCard(cardItem) {
        if (!cardItem || !cardItem.cardInfo || cardItem.cardInfo.id === undefined)
            return
        cardZCounter += 1
        cardItem.zOrder = cardZCounter
        setCardLayout(cardItem.cardInfo.id, "z", cardItem.zOrder)
    }

    property string theme: uiSettings.theme

    function applyTheme(name) {
        var t = themePalette[name]
        if (!t) t = themePalette["light"]
        windowBg = t.windowBg
        panelBg = t.panelBg
        panelBorder = t.panelBorder
        textColor = t.textColor
        subText = t.subText
        primary = t.primary
        controlBg = t.controlBg
        controlBorder = t.controlBorder
        buttonBg = t.buttonBg
        buttonHover = t.buttonHover
        buttonPress = t.buttonPress
        dangerText = t.dangerText
        logBg = t.logBg
        statusOkBg = t.statusOkBg
        statusBadBg = t.statusBadBg
    }

    function setTheme(name) {
        uiSettings.theme = name
    }

    function normalizeColorValue(value) {
        var text = String(value).trim()
        if (/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(text))
            return text.toLowerCase()
        return ""
    }

    function setSettingColor(key, value) {
        var normalized = normalizeColorValue(value)
        if (normalized.length === 0)
            return false

        if (key === "letters") uiSettings.logColorLetters = normalized
        else if (key === "digits") uiSettings.logColorDigits = normalized
        else if (key === "symbols") uiSettings.logColorSymbols = normalized
        else if (key === "tx") uiSettings.logColorTx = normalized
        else if (key === "sys") uiSettings.logColorSys = normalized
        else return false
        return true
    }

    function getSettingColor(key) {
        if (key === "letters") return uiSettings.logColorLetters
        if (key === "digits") return uiSettings.logColorDigits
        if (key === "symbols") return uiSettings.logColorSymbols
        if (key === "tx") return uiSettings.logColorTx
        if (key === "sys") return uiSettings.logColorSys
        return "#000000"
    }

    function escapeHtml(text) {
        return String(text)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
    }

    function formatWhitespace(ch) {
        if (ch === " ")
            return "&nbsp;"
        if (ch === "\t")
            return "&nbsp;&nbsp;&nbsp;&nbsp;"
        return "<br/>"
    }

    function wrapWithColor(text, color) {
        return "<span style=\"color:" + color + ";\">" + text + "</span>"
    }

    function formatTerminalContent(text) {
        var result = ""
        var source = String(text)
        for (var i = 0; i < source.length; ++i) {
            var ch = source.charAt(i)
            if (/\s/.test(ch)) {
                result += formatWhitespace(ch)
                continue
            }

            var color = uiSettings.logColorLetters
            if (/[0-9]/.test(ch))
                color = uiSettings.logColorDigits
            else if (/[!-/:-@\[-`{-~]/.test(ch))
                color = uiSettings.logColorSymbols
            result += wrapWithColor(escapeHtml(ch), color)
        }
        return result
    }

    function formatTerminalContentWithColor(text, color) {
        var result = ""
        var source = String(text)
        for (var i = 0; i < source.length; ++i) {
            var ch = source.charAt(i)
            if (/\s/.test(ch))
                result += formatWhitespace(ch)
            else
                result += wrapWithColor(escapeHtml(ch), color)
        }
        return result
    }

    function formatLogLine(line) {
        if (line.indexOf("[TX] ") === 0)
            return wrapWithColor(escapeHtml("[TX] "), uiSettings.logColorTx)
                 + formatTerminalContentWithColor(line.slice(5), uiSettings.logColorTx)
        if (line.indexOf("[SYS] ") === 0)
            return wrapWithColor(escapeHtml("[SYS] "), uiSettings.logColorSys)
                 + formatTerminalContentWithColor(line.slice(6), uiSettings.logColorSys)
        if (line.indexOf("[RX] ") === 0)
            return wrapWithColor(escapeHtml("[RX] "), root.subText)
                 + formatTerminalContent(line.slice(5))
        return formatTerminalContent(line)
    }

    function buildRichLog(logText) {
        if (!logText || logText.length === 0)
            return ""

        var lines = String(logText).split("\n")
        var formatted = ""
        for (var i = 0; i < lines.length; ++i) {
            formatted += formatLogLine(lines[i])
            if (i !== lines.length - 1)
                formatted += "<br/>"
        }
        return formatted
    }

    readonly property string richLogText: buildRichLog(SessionBridge.log)

    readonly property string cardDataPath: "data/monitor_cards.json"

    function autoSaveCards() {
        CardBridge.saveToFile(cardDataPath)
    }

    Component.onCompleted: {
        applyTheme(theme)
        loadCardLayout()
        initCardZCounter()
        CardBridge.loadFromFile(cardDataPath)
    }
    onThemeChanged: applyTheme(theme)

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

    Popup {
        id: themePopup
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        parent: root.contentItem
        padding: 0
        width: 500
        height: 540
        x: (root.width - width) / 2
        y: Math.max(12, (root.height - height) / 2)

        background: Rectangle {
            radius: root.cr
            color: root.panelBg
            border.color: root.panelBorder
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
                        color: root.textColor
                    }
                    Item { Layout.fillWidth: true }
                    LightButton {
                        text: "关闭"
                        onClicked: themePopup.close()
                    }
                }

                ScrollView {
                    id: themeScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    Column {
                        id: themeCol
                        width: themeScroll.availableWidth
                        spacing: 10

                        Rectangle {
                            width: parent.width
                            implicitHeight: quickThemeColumn.implicitHeight + 20
                            radius: root.cr
                            color: root.controlBg
                            border.color: root.controlBorder
                            Column {
                                id: quickThemeColumn
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6
                                Label {
                                    text: "快速主题"
                                    font.pixelSize: 11
                                    color: root.subText
                                }
                                RowLayout {
                                    spacing: 8
                                    LightButton {
                                        text: "浅色"
                                        onClicked: root.setTheme("light")
                                    }
                                    LightButton {
                                        text: "深色"
                                        onClicked: root.setTheme("dark")
                                    }
                                    LightButton {
                                        text: "暖色"
                                        onClicked: root.setTheme("warm")
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            implicitHeight: logStyleColumn.implicitHeight + 20
                            radius: root.cr
                            color: root.controlBg
                            border.color: root.controlBorder
                            Column {
                                id: logStyleColumn
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8
                                Label {
                                    text: "通信日志样式"
                                    font.pixelSize: 11
                                    color: root.subText
                                }
                                RowLayout {
                                    width: parent.width
                                    spacing: 8
                                    Label {
                                        text: "字体"
                                        font.pixelSize: 11
                                        color: root.subText
                                        Layout.preferredWidth: 40
                                    }
                                    LightTextField {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 28
                                        text: uiSettings.logFontFamily
                                        onEditingFinished: uiSettings.logFontFamily = text
                                    }
                                    Label {
                                        text: "字号"
                                        font.pixelSize: 11
                                        color: root.subText
                                        Layout.preferredWidth: 40
                                    }
                                    LightSpinBox {
                                        from: 8
                                        to: 24
                                        value: uiSettings.logFontSize
                                        editable: true
                                        Layout.preferredWidth: 88
                                        onValueChanged: uiSettings.logFontSize = value
                                    }
                                }

                                ColorField {
                                    width: parent.width
                                    label: "字母颜色"
                                    targetKey: "letters"
                                    value: uiSettings.logColorLetters
                                }
                                ColorField {
                                    width: parent.width
                                    label: "数字颜色"
                                    targetKey: "digits"
                                    value: uiSettings.logColorDigits
                                }
                                ColorField {
                                    width: parent.width
                                    label: "符号颜色"
                                    targetKey: "symbols"
                                    value: uiSettings.logColorSymbols
                                }
                                ColorField {
                                    width: parent.width
                                    label: "TX 颜色"
                                    targetKey: "tx"
                                    value: uiSettings.logColorTx
                                }
                                ColorField {
                                    width: parent.width
                                    label: "SYS 颜色"
                                    targetKey: "sys"
                                    value: uiSettings.logColorSys
                                }

                                Rectangle {
                                    width: parent.width
                                    implicitHeight: previewColumn.implicitHeight + 16
                                    radius: 4
                                    color: root.panelBg
                                    border.color: root.controlBorder
                                    Column {
                                        id: previewColumn
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4
                                        Label {
                                            text: "预览（仅演示）"
                                            font.pixelSize: 10
                                            color: root.subText
                                        }
                                        Text {
                                            textFormat: Text.RichText
                                            font.family: uiSettings.logFontFamily
                                            font.pixelSize: uiSettings.logFontSize
                                            color: root.textColor
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                            text: "<span style='color:%1'>ABCdef</span> " +
                                                  "<span style='color:%2'>012345</span> " +
                                                  "<span style='color:%3'>!@#$%%</span> " +
                                                  "<span style='color:%4'>[TX]</span> " +
                                                  "<span style='color:%5'>[SYS]</span>"
                                                  .arg(uiSettings.logColorLetters)
                                                  .arg(uiSettings.logColorDigits)
                                                  .arg(uiSettings.logColorSymbols)
                                                  .arg(uiSettings.logColorTx)
                                                  .arg(uiSettings.logColorSys)
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

            LightButton {
                text: "主题/样式"
                onClicked: themePopup.open()
            }

            Rectangle {
                radius: 10
                color: SessionBridge.connected ? root.statusOkBg : root.statusBadBg
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

            // Left: cards area
            Rectangle {
                id: cardArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.panelBg
                border.color: root.panelBorder
                radius: root.cr
                clip: true

                // Camera (zoom/pan) for the card scene
                property real cameraScale: 1.0
                property real cameraX: 0
                property real cameraY: 0
                readonly property real minCameraScale: 0.25
                readonly property real maxCameraScale: 3.0

                // Feed serial data to CardBridge
                Connections {
                    target: SessionBridge
                    function onMessageReceived(direction, content) {
                        CardBridge.feed(content)
                    }
                }

                Label {
                    visible: CardBridge.cardCount === 0
                    anchors.centerIn: parent
                    text: "点击右上角 + 新建监测卡片"
                    color: root.subText
                }

                Item {
                    id: cardViewport
                    anchors.fill: parent

                    // Wheel zoom (overall view)
                    WheelHandler {
                        target: cardViewport
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(wheel) {
                            if (wheel.angleDelta.y === 0)
                                return

                            var oldScale = cardArea.cameraScale
                            var step = wheel.angleDelta.y / 120.0
                            var factor = Math.pow(1.15, step)
                            var newScale = Math.max(cardArea.minCameraScale, Math.min(cardArea.maxCameraScale, oldScale * factor))
                            if (Math.abs(newScale - oldScale) < 0.0001)
                                return

                            // Qt6 WheelEvent doesn't consistently expose `position` across versions;
                            // fall back to `x/y` when needed.
                            var px = (wheel.x !== undefined) ? wheel.x
                                   : (wheel.position && wheel.position.x !== undefined) ? wheel.position.x
                                   : (wheel.point && wheel.point.position && wheel.point.position.x !== undefined) ? wheel.point.position.x
                                   : 0
                            var py = (wheel.y !== undefined) ? wheel.y
                                   : (wheel.position && wheel.position.y !== undefined) ? wheel.position.y
                                   : (wheel.point && wheel.point.position && wheel.point.position.y !== undefined) ? wheel.point.position.y
                                   : 0

                            var sceneX = (px - cardArea.cameraX) / oldScale
                            var sceneY = (py - cardArea.cameraY) / oldScale

                            cardArea.cameraScale = newScale
                            cardArea.cameraX = px - sceneX * newScale
                            cardArea.cameraY = py - sceneY * newScale
                            wheel.accepted = true
                        }
                    }

                    // Middle mouse drag to pan camera
                    DragHandler {
                        target: null
                        acceptedButtons: Qt.MiddleButton
                        property point lastTranslation: Qt.point(0, 0)
                        onActiveChanged: lastTranslation = Qt.point(0, 0)
                        onTranslationChanged: {
                            var dx = translation.x - lastTranslation.x
                            var dy = translation.y - lastTranslation.y
                            cardArea.cameraX += dx
                            cardArea.cameraY += dy
                            lastTranslation = Qt.point(translation.x, translation.y)
                        }
                    }

                    // Offscreen card indicators
                    Item {
                        id: offscreenLayer
                        anchors.fill: parent
                        z: 10000

                        Repeater {
                            model: CardBridge.cardCount
                            delegate: Item {
                                readonly property var cardInfo: CardBridge.cardAt(index)
                                readonly property string cardId: (cardInfo && cardInfo.id) ? cardInfo.id : ""
                                readonly property real cardW: root.getCardLayout(cardId, "w", 170)
                                readonly property real cardH: root.getCardLayout(cardId, "h", 130)
                                readonly property real cardX: root.getCardLayout(cardId, "x", 12 + (index % 3) * 170)
                                readonly property real cardY: root.getCardLayout(cardId, "y", 12 + Math.floor(index / 3) * 150)
                                readonly property real centerX: cardX + cardW / 2.0
                                readonly property real centerY: cardY + cardH / 2.0
                                readonly property real viewX: cardArea.cameraX + centerX * cardArea.cameraScale
                                readonly property real viewY: cardArea.cameraY + centerY * cardArea.cameraScale
                                readonly property real halfW: (cardW * cardArea.cameraScale) / 2.0
                                readonly property real halfH: (cardH * cardArea.cameraScale) / 2.0
                                // Avoid names like `left/right/top/bottom` (reserved anchor line properties on Item)
                                readonly property real viewLeft: viewX - halfW
                                readonly property real viewRight: viewX + halfW
                                readonly property real viewTop: viewY - halfH
                                readonly property real viewBottom: viewY + halfH
                                // Show indicator only when the card is completely offscreen (no intersection)
                                readonly property bool completelyOffscreen: (viewRight < 0
                                                                           || viewLeft > cardViewport.width
                                                                           || viewBottom < 0
                                                                           || viewTop > cardViewport.height)
                                readonly property color cardColor: (cardInfo && cardInfo.color) ? cardInfo.color : root.primary

                                visible: cardId.length > 0 && completelyOffscreen
                                width: 44
                                height: 44

                                readonly property real pad: 16
                                readonly property real clampedX: Math.max(pad, Math.min(cardViewport.width - pad, viewX))
                                readonly property real clampedY: Math.max(pad, Math.min(cardViewport.height - pad, viewY))
                                x: clampedX - width / 2.0
                                y: clampedY - height / 2.0

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "#000000"
                                    opacity: 0.35
                                    border.color: cardColor
                                    border.width: 2
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: ">"
                                    font.pixelSize: 22
                                    color: "#ffffff"
                                    rotation: Math.atan2(viewY - clampedY, viewX - clampedX) * 180 / Math.PI
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        // Pan to bring the card closer to center (keep current zoom)
                                        cardArea.cameraX = cardViewport.width / 2.0 - centerX * cardArea.cameraScale
                                        cardArea.cameraY = cardViewport.height / 2.0 - centerY * cardArea.cameraScale
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: cardScene
                    parent: cardViewport
                    width: cardViewport.width
                    height: cardViewport.height
                    x: cardArea.cameraX
                    y: cardArea.cameraY
                    scale: cardArea.cameraScale
                    transformOrigin: Item.TopLeft
                }

                // Card instances
                Repeater {
                    id: cardRepeater
                    parent: cardScene
                    model: CardBridge.cardCount

                     Rectangle {
                         id: cardWidget
                         property int cardIndex: index
                         property var cardInfo: CardBridge.cardAt(index)
                         property var cardVal: ({})
                         property string cardColor: cardInfo.color || root.primary
                        property int zOrder: root.getCardLayout(cardInfo.id, "z", 0)

                        readonly property real minW: 140
                        readonly property real minH: 100
                        readonly property real scaleFactor: Math.min(width / minW, height / minH)

                        x: root.getCardLayout(cardInfo.id, "x", 12 + (index % 3) * 170)
                        y: root.getCardLayout(cardInfo.id, "y", 12 + Math.floor(index / 3) * 150)
                        width: root.getCardLayout(cardInfo.id, "w", 170)
                        height: root.getCardLayout(cardInfo.id, "h", 130)
                        z: zOrder

                        radius: root.cr
                        color: root.controlBg
                        border.color: root.controlBorder

                        Component.onCompleted: {
                            cardVal = CardBridge.cardValue(cardIndex) || {}
                            if (zOrder === 0)
                                root.raiseCard(cardWidget)
                        }

                        Connections {
                            target: CardBridge
                            function onCardValueUpdated(cardId, value) {
                                if (cardId === cardWidget.cardInfo.id)
                                    cardWidget.cardVal = value
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.AllButtons
                            onPressed: root.raiseCard(cardWidget)
                        }

                        // Title bar (draggable)
                        Rectangle {
                            id: cardTitleBar
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: Math.max(22, 22 * cardWidget.scaleFactor)
                            radius: root.cr
                            color: "transparent"

                            Rectangle {
                                anchors.fill: parent
                                anchors.bottomMargin: -root.cr
                                color: cardWidget.cardColor
                                opacity: 0.12
                                radius: root.cr
                            }

                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: cardWidget.cardInfo.name || ""
                                font.pixelSize: Math.max(10, 11 * cardWidget.scaleFactor)
                                font.bold: true
                                color: cardWidget.cardColor
                                elide: Text.ElideRight
                                width: parent.width - 30
                            }

                            // Delete button (subtle)
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: "×"
                                font.pixelSize: 13
                                color: root.subText
                                opacity: deleteMA.containsMouse ? 1.0 : 0.3

                                MouseArea {
                                    id: deleteMA
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var idx = cardWidget.cardIndex
                                        CardBridge.removeCard(idx)
                                        autoSaveCards()
                                        showToast("已删除卡片")
                                    }
                                }
                            }

                            MouseArea {
                                id: dragMA
                                anchors.fill: parent
                                anchors.rightMargin: 24
                                cursorShape: Qt.SizeAllCursor
                                property point pressPos
                                property point pressItemPos
                                onPressed: function(mouse) {
                                    root.raiseCard(cardWidget)
                                    pressPos = mapToItem(cardScene, mouse.x, mouse.y)
                                    pressItemPos = Qt.point(cardWidget.x, cardWidget.y)
                                }
                                onPositionChanged: function(mouse) {
                                    if (!pressed) return
                                    var cur = mapToItem(cardScene, mouse.x, mouse.y)
                                    var nx = pressItemPos.x + cur.x - pressPos.x
                                    var ny = pressItemPos.y + cur.y - pressPos.y
                                    cardWidget.x = nx
                                    cardWidget.y = ny
                                }
                                onReleased: {
                                    root.setCardLayout(cardWidget.cardInfo.id, "x", cardWidget.x)
                                    root.setCardLayout(cardWidget.cardInfo.id, "y", cardWidget.y)
                                }
                            }
                        }

                        // Card body: value display
                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: cardTitleBar.bottom
                            anchors.bottom: resizeHandle.top
                            anchors.margins: 8
                            anchors.topMargin: 4
                            spacing: 2

                            Item { Layout.fillHeight: true; width: 1; height: 1 }

                            Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: {
                                    var v = cardWidget.cardVal
                                    if (!v || v.matched === undefined) return "--"
                                    var info = cardWidget.cardInfo
                                    if (info.type === "boolean")
                                        return v.boolean ? "TRUE" : "FALSE"
                                    var num = Number(v.numeric)
                                    return isNaN(num) ? v.raw || "--" : num.toFixed(2)
                                }
                                font.pixelSize: Math.max(16, Math.min(48, 24 * cardWidget.scaleFactor))
                                font.bold: true
                                color: cardWidget.cardColor
                                elide: Text.ElideRight
                            }

                            Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                visible: (cardWidget.cardInfo.unit || "").length > 0
                                text: cardWidget.cardInfo.unit || ""
                                font.pixelSize: Math.max(9, 11 * cardWidget.scaleFactor)
                                color: root.subText
                            }

                            Label {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: {
                                    return cardWidget.cardInfo.pattern || ""
                                }
                                font.pixelSize: Math.max(8, 9 * cardWidget.scaleFactor)
                                color: root.subText
                                elide: Text.ElideRight
                                wrapMode: Text.WrapAnywhere
                                maximumLineCount: 2
                            }
                        }

                        // Resize handle (bottom-right corner)
                        Item {
                            id: resizeHandle
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 16; height: 16

                            Text {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: 2
                                anchors.bottomMargin: 0
                                text: "⋱"
                                font.pixelSize: 10
                                color: root.subText
                                opacity: resizeMA.containsMouse ? 0.8 : 0.3
                            }

                            MouseArea {
                                id: resizeMA
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.SizeFDiagCursor
                                property point pressPos
                                property real pressW; property real pressH
                                onPressed: function(mouse) {
                                    root.raiseCard(cardWidget)
                                    pressPos = mapToItem(cardScene, mouse.x, mouse.y)
                                    pressW = cardWidget.width
                                    pressH = cardWidget.height
                                }
                                onPositionChanged: function(mouse) {
                                    if (!pressed) return
                                    var cur = mapToItem(cardScene, mouse.x, mouse.y)
                                    cardWidget.width = Math.max(cardWidget.minW, pressW + cur.x - pressPos.x)
                                    cardWidget.height = Math.max(cardWidget.minH, pressH + cur.y - pressPos.y)
                                }
                                onReleased: {
                                    root.setCardLayout(cardWidget.cardInfo.id, "w", cardWidget.width)
                                    root.setCardLayout(cardWidget.cardInfo.id, "h", cardWidget.height)
                                }
                            }
                        }
                    }
                }

                // Add card button (top-right corner)
                Rectangle {
                    id: addCardBtn
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 8
                    anchors.rightMargin: 8
                    width: 28; height: 28
                    radius: root.cr
                    color: addCardMa.pressed ? root.buttonPress
                         : addCardMa.containsMouse ? root.buttonHover
                         : root.buttonBg
                    border.color: root.controlBorder
                    z: 1000000

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        font.pixelSize: 16
                        color: root.primary
                    }

                    MouseArea {
                        id: addCardMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addCardPopup.open()
                    }
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
                            color: root.logBg
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
                                    font.family: uiSettings.logFontFamily
                                    font.pixelSize: uiSettings.logFontSize
                                    text: root.richLogText
                                    wrapMode: TextArea.Wrap
                                    background: null
                                    textFormat: TextEdit.RichText

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

    // ── Add Card Popup ────────────────────────────────────────

    Popup {
        id: addCardPopup
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        parent: root.contentItem
        padding: 0
        width: 420
        height: Math.min(root.height - 24, addCardContent.implicitHeight + 24)
        x: (root.width - width) / 2
        y: Math.max(12, (root.height - height) / 2)

        property bool advancedMode: false
        property var boolTrueList: []
        property var boolFalseList: []

        background: Rectangle {
            radius: root.cr
            color: root.panelBg
            border.color: root.panelBorder
        }

        onOpened: {
            newCardName.text = ""
            newCardPattern.text = ""
            newCardPrefix.text = ""
            newCardSuffix.text = ""
            newCardUnit.text = ""
            newCardColor.text = "#0e7a68"
            newCardTypeCombo.currentIndex = 0
            advancedMode = false
            boolTrueList = ["ON"]
            boolFalseList = ["OFF"]
            newCardName.forceActiveFocus()
        }

        function buildPattern() {
            if (advancedMode)
                return newCardPattern.text

            var prefix = newCardPrefix.text
            var suffix = newCardSuffix.text
            var isBoolean = newCardTypeCombo.currentIndex === 1

            // Escape regex special chars in user strings
            function escRe(s) {
                return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
            }

            if (isBoolean) {
                // Collect all true/false keywords
                var trueWords = []
                var falseWords = []
                for (var i = 0; i < boolTrueList.length; ++i) {
                    var tw = boolTrueList[i].trim()
                    if (tw.length > 0) trueWords.push(tw)
                }
                for (var j = 0; j < boolFalseList.length; ++j) {
                    var fw = boolFalseList[j].trim()
                    if (fw.length > 0) falseWords.push(fw)
                }
                if (trueWords.length === 0) trueWords = ["ON"]
                if (falseWords.length === 0) falseWords = ["OFF"]

                var allKw = trueWords.concat(falseWords).map(escRe)
                var regex = escRe(prefix) + "(" + allKw.join("|") + ")" + escRe(suffix)
                return regex + "; true=" + trueWords.join("|") + "; false=" + falseWords.join("|")
            } else {
                return escRe(prefix) + "(\\d+\\.?\\d*)" + escRe(suffix)
            }
        }

        function canCreate() {
            if (newCardName.text.length === 0) return false
            if (advancedMode) return newCardPattern.text.length > 0
            return newCardPrefix.text.length > 0 || newCardSuffix.text.length > 0
        }

        contentItem: Item {
            implicitHeight: addCardContent.implicitHeight
            implicitWidth: addCardContent.implicitWidth

            ScrollView {
                anchors.fill: parent
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    id: addCardContent
                    width: addCardPopup.width - 32
                    x: 16
                    spacing: 10

                    Item { Layout.preferredHeight: 4 }

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "新建监测卡片"
                            font.pixelSize: 13
                            font.bold: true
                            color: root.textColor
                        }
                        Item { Layout.fillWidth: true }
                        LightButton {
                            text: addCardPopup.advancedMode ? "简单模式" : "高级模式"
                            onClicked: addCardPopup.advancedMode = !addCardPopup.advancedMode
                        }
                        LightButton {
                            text: "关闭"
                            onClicked: addCardPopup.close()
                        }
                    }

                    Label { text: "名称"; font.pixelSize: 11; color: root.subText }
                    LightTextField {
                        id: newCardName
                        Layout.fillWidth: true
                        placeholderText: "例如：温度、电压"
                    }

                    // ── Advanced mode: raw regex ──
                    ColumnLayout {
                        visible: addCardPopup.advancedMode
                        Layout.fillWidth: true
                        spacing: 6

                        Label { text: "匹配模式 (正则表达式)"; font.pixelSize: 11; color: root.subText }
                        LightTextField {
                            id: newCardPattern
                            Layout.fillWidth: true
                            placeholderText: "例如：temp=(\\d+\\.?\\d*)"
                        }

                        Label { text: "类型"; font.pixelSize: 11; color: root.subText }
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

                    // ── Simple mode: prefix + type + suffix ──
                    ColumnLayout {
                        visible: !addCardPopup.advancedMode
                        Layout.fillWidth: true
                        spacing: 6

                        Label { text: "匹配规则"; font.pixelSize: 11; color: root.subText }

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
                            color: root.subText
                            font.italic: true
                        }

                        // Boolean true/false keyword lists
                        ColumnLayout {
                            visible: newCardTypeCombo.currentIndex === 1
                            Layout.fillWidth: true
                            spacing: 6

                            // True keywords
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "True 关键词"; font.pixelSize: 11; color: root.subText }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: 22; height: 22; radius: root.cr
                                    color: addTrueMa.pressed ? root.buttonPress
                                         : addTrueMa.containsMouse ? root.buttonHover : root.buttonBg
                                    border.color: root.controlBorder
                                    Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 13; color: root.primary }
                                    MouseArea {
                                        id: addTrueMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var l = addCardPopup.boolTrueList.slice()
                                            l.push("")
                                            addCardPopup.boolTrueList = l
                                        }
                                    }
                                }
                            }
                            Repeater {
                                model: addCardPopup.boolTrueList.length
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    LightTextField {
                                        Layout.fillWidth: true
                                        text: addCardPopup.boolTrueList[index]
                                        placeholderText: "如 ON、YES、1"
                                        onTextEdited: {
                                            var l = addCardPopup.boolTrueList.slice()
                                            l[index] = text
                                            addCardPopup.boolTrueList = l
                                        }
                                    }
                                    LightButton {
                                        text: "×"
                                        visible: addCardPopup.boolTrueList.length > 1
                                        onClicked: {
                                            var l = addCardPopup.boolTrueList.slice()
                                            l.splice(index, 1)
                                            addCardPopup.boolTrueList = l
                                        }
                                    }
                                }
                            }

                            // False keywords
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "False 关键词"; font.pixelSize: 11; color: root.subText }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: 22; height: 22; radius: root.cr
                                    color: addFalseMa.pressed ? root.buttonPress
                                         : addFalseMa.containsMouse ? root.buttonHover : root.buttonBg
                                    border.color: root.controlBorder
                                    Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 13; color: root.primary }
                                    MouseArea {
                                        id: addFalseMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var l = addCardPopup.boolFalseList.slice()
                                            l.push("")
                                            addCardPopup.boolFalseList = l
                                        }
                                    }
                                }
                            }
                            Repeater {
                                model: addCardPopup.boolFalseList.length
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    LightTextField {
                                        Layout.fillWidth: true
                                        text: addCardPopup.boolFalseList[index]
                                        placeholderText: "如 OFF、NO、0"
                                        onTextEdited: {
                                            var l = addCardPopup.boolFalseList.slice()
                                            l[index] = text
                                            addCardPopup.boolFalseList = l
                                        }
                                    }
                                    LightButton {
                                        text: "×"
                                        visible: addCardPopup.boolFalseList.length > 1
                                        onClicked: {
                                            var l = addCardPopup.boolFalseList.slice()
                                            l.splice(index, 1)
                                            addCardPopup.boolFalseList = l
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Unit & Color (shared) ──
                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Label { text: "单位"; font.pixelSize: 11; color: root.subText }
                            LightTextField {
                                id: newCardUnit
                                Layout.fillWidth: true
                                placeholderText: "例如：°C、V、A"
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Label { text: "颜色"; font.pixelSize: 11; color: root.subText }
                            RowLayout {
                                spacing: 4
                                Rectangle {
                                    width: 16; height: 16; radius: 4
                                    color: root.normalizeColorValue(newCardColor.text) || "#000000"
                                    border.color: root.controlBorder
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
                            visible: !addCardPopup.advancedMode
                            text: "生成: " + addCardPopup.buildPattern()
                            font.pixelSize: 9
                            color: root.subText
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Item { visible: addCardPopup.advancedMode; Layout.fillWidth: true }

                        PrimaryButton {
                            text: "创建"
                            enabled: addCardPopup.canCreate()
                            onClicked: {
                                var pattern = addCardPopup.buildPattern()
                                var cardType
                                if (addCardPopup.advancedMode)
                                    cardType = newCardTypeAdvNumeric.checked ? "numeric" : "boolean"
                                else
                                    cardType = newCardTypeCombo.currentIndex === 0 ? "numeric" : "boolean"
                                var color = root.normalizeColorValue(newCardColor.text)
                                if (!color) color = "#0e7a68"
                                CardBridge.addCard(newCardName.text, pattern,
                                                   cardType, newCardUnit.text, color)
                                addCardPopup.close()
                                root.autoSaveCards()
                                root.showToast("已创建卡片：" + newCardName.text)
                            }
                        }
                    }

                    Item { Layout.preferredHeight: 4 }
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
