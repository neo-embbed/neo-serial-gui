import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.settings

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

    Component.onCompleted: applyTheme(theme)
    onThemeChanged: applyTheme(theme)

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

    component LightSpinBox: SpinBox {
        id: _spin
        editable: true
        font.pixelSize: 12
        implicitHeight: 28
        implicitWidth: 96

        contentItem: TextInput {
            z: 2
            text: _spin.displayText
            font: _spin.font
            color: root.textColor
            selectionColor: root.primary
            selectedTextColor: "#ffffff"
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            readOnly: !_spin.editable
            validator: _spin.validator
            inputMethodHints: Qt.ImhDigitsOnly

            onTextEdited: function() {
                if (_spin.editable)
                    _spin.value = _spin.valueFromText(text, _spin.locale)
            }
        }

        up.indicator: Rectangle {
            x: parent.width - width
            y: 0
            width: 26
            height: parent.height / 2
            radius: root.cr
            color: _spin.up.pressed ? root.buttonPress
                 : _spin.up.hovered ? root.buttonHover
                 : root.buttonBg
            border.color: root.controlBorder

            Text {
                anchors.centerIn: parent
                text: "+"
                font.pixelSize: 12
                color: root.textColor
            }
        }

        down.indicator: Rectangle {
            x: parent.width - width
            y: parent.height / 2
            width: 26
            height: parent.height / 2
            radius: root.cr
            color: _spin.down.pressed ? root.buttonPress
                 : _spin.down.hovered ? root.buttonHover
                 : root.buttonBg
            border.color: root.controlBorder

            Text {
                anchors.centerIn: parent
                text: "-"
                font.pixelSize: 12
                color: root.textColor
            }
        }

        background: Rectangle {
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

    component ColorField: RowLayout {
        property string label: ""
        property string targetKey: ""
        property string value: "#000000"

        spacing: 6
        Layout.fillWidth: true
        implicitHeight: 30

        Label {
            text: label
            font.pixelSize: 11
            color: root.subText
            Layout.preferredWidth: 84
        }
        Rectangle {
            width: 16
            height: 16
            radius: 4
            color: value
            border.color: root.controlBorder
        }
        LightTextField {
            id: colorInput
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            text: value
            onEditingFinished: {
                if (!root.setSettingColor(targetKey, text)) {
                    text = value
                    root.showToast("颜色格式错误，请输入十六进制值，例如 #1f2328")
                }
            }
        }
        LightButton {
            text: "选择"
            Layout.preferredHeight: 28
            onClicked: {
                colorDialog.targetKey = targetKey
                colorDialog.color = value
                colorDialog.open()
            }
        }
        onValueChanged: {
            if (!colorInput.activeFocus) colorInput.text = value
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

    ColorDialog {
        id: colorDialog
        property string targetKey: ""
        title: "选择颜色"
        onAccepted: {
            root.setSettingColor(targetKey, color)
        }
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
                                                  "<span style='color:%3'>!@#$%</span> " +
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
