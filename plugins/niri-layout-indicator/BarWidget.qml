import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI

Rectangle {
    id: root

    // Plugin API injected by Noctalia
    property var pluginApi: null

    // Required Noctalia bar widget properties
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    // Settings
    property string displayMode: pluginApi?.pluginSettings?.displayMode || "text" // "text" | "flag"
    property string middleClickAction: pluginApi?.pluginSettings?.middleClickAction || "previous" // "previous" | "toggle-mode"
    property int pollIntervalMs: pluginApi?.pluginSettings?.pollIntervalMs || 750

    // Runtime state
    property int currentIndex: -1
    property string currentName: "Unknown"
    property var layouts: []

    implicitWidth: label.implicitWidth + Style.marginS * 2
    implicitHeight: Style.barHeight - 2

    color: Style.capsuleColor
    radius: Style.radiusM

    function saveSettings() {
        if (!pluginApi || !pluginApi.pluginSettings)
            return

        pluginApi.pluginSettings.displayMode = root.displayMode
        pluginApi.pluginSettings.middleClickAction = root.middleClickAction
        pluginApi.pluginSettings.pollIntervalMs = root.pollIntervalMs
        pluginApi.saveSettings()
    }

    function codeForLayout(name) {
        var n = (name || "").toLowerCase()

        if (n.indexOf("russian") >= 0) return "ru"
        if (n.indexOf("english") >= 0) return "en"
        if (n.indexOf("french") >= 0) return "fr"
        if (n.indexOf("german") >= 0) return "de"
        if (n.indexOf("spanish") >= 0) return "es"
        if (n.indexOf("italian") >= 0) return "it"
        if (n.indexOf("portuguese") >= 0) return "pt"
        if (n.indexOf("polish") >= 0) return "pl"
        if (n.indexOf("ukrainian") >= 0) return "uk"
        if (n.indexOf("belarusian") >= 0) return "be"
        if (n.indexOf("czech") >= 0) return "cs"
        if (n.indexOf("slovak") >= 0) return "sk"
        if (n.indexOf("turkish") >= 0) return "tr"
        if (n.indexOf("greek") >= 0) return "el"
        if (n.indexOf("hebrew") >= 0) return "he"
        if (n.indexOf("arabic") >= 0) return "ar"
        if (n.indexOf("japanese") >= 0) return "ja"
        if (n.indexOf("korean") >= 0) return "ko"
        if (n.indexOf("chinese") >= 0) return "zh"

        // Fallback: first two letters from the first word
        var first = (name || "??").replace(/\(.*/, "").trim().split(/\s+/)[0]
        return first.substring(0, 2).toLowerCase()
    }

    function flagForLayout(name) {
        var n = (name || "").toLowerCase()

        // Country flags are not the same thing as layouts, but good enough for a visible indicator.
        if (n.indexOf("russian") >= 0) return "🇷🇺"
        if (n.indexOf("english") >= 0 && (n.indexOf("uk") >= 0 || n.indexOf("british") >= 0)) return "🇬🇧"
        if (n.indexOf("english") >= 0) return "🇺🇸"
        if (n.indexOf("french") >= 0) return "🇫🇷"
        if (n.indexOf("german") >= 0) return "🇩🇪"
        if (n.indexOf("spanish") >= 0) return "🇪🇸"
        if (n.indexOf("italian") >= 0) return "🇮🇹"
        if (n.indexOf("portuguese") >= 0) return "🇵🇹"
        if (n.indexOf("polish") >= 0) return "🇵🇱"
        if (n.indexOf("ukrainian") >= 0) return "🇺🇦"
        if (n.indexOf("belarusian") >= 0) return "🇧🇾"
        if (n.indexOf("czech") >= 0) return "🇨🇿"
        if (n.indexOf("slovak") >= 0) return "🇸🇰"
        if (n.indexOf("turkish") >= 0) return "🇹🇷"
        if (n.indexOf("greek") >= 0) return "🇬🇷"
        if (n.indexOf("hebrew") >= 0) return "🇮🇱"
        if (n.indexOf("arabic") >= 0) return "🌐"
        if (n.indexOf("japanese") >= 0) return "🇯🇵"
        if (n.indexOf("korean") >= 0) return "🇰🇷"
        if (n.indexOf("chinese") >= 0) return "🇨🇳"

        return "⌨"
    }

    function indicatorText() {
        if (root.currentIndex < 0)
            return "??"

        return root.displayMode === "flag"
            ? flagForLayout(root.currentName)
            : codeForLayout(root.currentName)
    }

    function parseLayouts(output) {
        var parsed = []
        var activeIndex = -1
        var activeName = "Unknown"

        var lines = (output || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            // Examples:
            // " * 0 English (US)"
            // "   1 Russian"
            var match = line.match(/^\s*(\*)?\s*(\d+)\s+(.+?)\s*$/)
            if (!match)
                continue

            var item = {
                active: match[1] === "*",
                index: parseInt(match[2]),
                name: match[3]
            }
            parsed.push(item)

            if (item.active) {
                activeIndex = item.index
                activeName = item.name
            }
        }

        root.layouts = parsed

        if (activeIndex >= 0) {
            root.currentIndex = activeIndex
            root.currentName = activeName
        }
    }

    function refresh() {
        if (!readLayoutsProc.running)
            readLayoutsProc.exec(["niri", "msg", "keyboard-layouts"])
    }

    function switchLayout(target) {
        switchProc.exec(["niri", "msg", "action", "switch-layout", target.toString()])
        refreshDelay.restart()
    }

    function toggleDisplayMode() {
        root.displayMode = root.displayMode === "text" ? "flag" : "text"
        saveSettings()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Style.marginS

        NText {
            id: label
            text: root.indicatorText()
            color: Color.mOnSurface
            pointSize: Style.fontSizeM
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        hoverEnabled: true

        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.switchLayout("next")
            } else if (mouse.button === Qt.MiddleButton) {
                if (root.middleClickAction === "toggle-mode")
                    root.toggleDisplayMode()
                else
                    root.switchLayout("prev")
            } else if (mouse.button === Qt.RightButton) {
                root.refresh()
                menu.open()
            }
        }
    }

    Popup {
        id: menu
        x: 0
        y: root.height + 6
        width: Math.max(220, menuColumn.implicitWidth + Style.marginM * 2)
        height: menuColumn.implicitHeight + Style.marginM * 2
        padding: Style.marginM
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Style.capsuleColor
            radius: Style.radiusM
            border.width: 1
            border.color: Color.mOutline
        }

        ColumnLayout {
            id: menuColumn
            anchors.fill: parent
            spacing: Style.marginS

            NText {
                text: "Keyboard layout"
                color: Color.mOnSurface
                pointSize: Style.fontSizeS
                font.weight: Font.Bold
            }

            Repeater {
                model: root.layouts

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: Style.radiusS
                    color: modelData.active ? Color.mPrimaryContainer : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Style.marginS
                        anchors.rightMargin: Style.marginS
                        spacing: Style.marginS

                        NText {
                            text: modelData.active ? "●" : "○"
                            color: modelData.active ? Color.mPrimary : Color.mOnSurfaceVariant
                            pointSize: Style.fontSizeS
                        }

                        NText {
                            Layout.fillWidth: true
                            text: codeForLayout(modelData.name) + "  " + modelData.name
                            color: Color.mOnSurface
                            pointSize: Style.fontSizeS
                            elide: Text.ElideRight
                        }

                        NText {
                            text: flagForLayout(modelData.name)
                            color: Color.mOnSurface
                            pointSize: Style.fontSizeS
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.switchLayout(modelData.index)
                            menu.close()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Color.mOutline
                opacity: 0.5
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: Style.radiusS
                color: "transparent"

                NText {
                    anchors.centerIn: parent
                    text: "Display: " + (root.displayMode === "text" ? "text" : "flag")
                    color: Color.mOnSurface
                    pointSize: Style.fontSizeS
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.toggleDisplayMode()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: Style.radiusS
                color: "transparent"

                NText {
                    anchors.centerIn: parent
                    text: "Middle click: " + (root.middleClickAction === "previous" ? "previous layout" : "toggle display")
                    color: Color.mOnSurface
                    pointSize: Style.fontSizeS
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.middleClickAction = root.middleClickAction === "previous" ? "toggle-mode" : "previous"
                        root.saveSettings()
                    }
                }
            }
        }
    }

    Process {
        id: readLayoutsProc
        stdout: StdioCollector {
            onStreamFinished: root.parseLayouts(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.length > 0)
                    Logger.w("NiriLayoutIndicator", this.text)
            }
        }
    }

    Process {
        id: switchProc
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.length > 0)
                    Logger.w("NiriLayoutIndicator", this.text)
            }
        }
    }

    Timer {
        id: pollTimer
        interval: root.pollIntervalMs
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshDelay
        interval: 120
        repeat: false
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        root.refresh()
        Logger.i("NiriLayoutIndicator", "Loaded")
    }
}
