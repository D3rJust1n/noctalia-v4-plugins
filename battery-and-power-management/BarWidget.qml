import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.System

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen: null
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    readonly property string screenName: screen ? (screen.name ?? "") : ""
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(root.screenName)
    readonly property real barFontSize: Style.getBarFontSizeForScreen(root.screenName)
    readonly property string fixedFont: Settings.data?.ui?.fontFixed ?? "monospace"

    property int batPercent: 0
    property real wattNum: 0.0
    property string batStatus: "Unknown"
    property string timeRemaining: "..."
    
    property string currentProfile: "balanced"
    property int batteryThreshold: 80

    readonly property real contentWidth: layout.implicitWidth + Style.marginM * 2
    readonly property real contentHeight: capsuleHeight
    implicitWidth: contentWidth
    implicitHeight: Style.barHeight

    Component.onCompleted: {
        if (pluginApi) {
            pluginApi.mainInstance = root;
        }
        updatePowerProfile();
        thresholdLoader.reload();
    }

    function updatePowerProfile() {
        profileLoader.reload();
    }

    FileView {
        id: profileLoader
        path: "/sys/firmware/acpi/platform_profile"
        printErrors: false
        onLoaded: {
            let raw = text();
            if (raw) {
                let cleaned = raw.trim();
                if (cleaned === "performance") {
                    root.currentProfile = "performance";
                } else if (cleaned === "low-power") {
                    root.currentProfile = "power-saver";
                } else {
                    root.currentProfile = "balanced";
                }
            }
        }
    }

    function setPowerProfile(profile) {
        root.currentProfile = profile;
        profileSetter.running = false;
        profileSetter.command = ["powerprofilesctl", "set", profile];
        profileSetter.running = true;
    }

    function setBatteryThreshold(value) {
        root.batteryThreshold = value;
        let devPath = "/sys/class/power_supply/BAT0";
        if (pluginApi?.pluginSettings?.batteryDevice) {
            devPath = pluginApi.pluginSettings.batteryDevice;
        }
        thresholdSetter.running = false;
        thresholdSetter.command = ["sh", "-c", "echo " + value + " > " + devPath + "/charge_control_end_threshold"];
        thresholdSetter.running = true;
    }

    Process {
        id: thresholdSetter
        onExited: (code) => {
            if (code !== 0) Logger.error("Error writing battery threshold.");
        }
    }

    Process {
        id: profileSetter
        onExited: (code) => { updatePowerProfile(); }
    }

    Timer {
        id: globalRefreshTimer
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let devPath = "/sys/class/power_supply/BAT0";
            if (pluginApi?.pluginSettings?.batteryDevice) {
                devPath = pluginApi.pluginSettings.batteryDevice;
            }
            let batName = devPath.split("/").pop() || "BAT0";
            batLoader.device = batName;
            batLoader.reload();
            
            thresholdLoader.reload();
            updatePowerProfile();
        }
    }

    FileView {
        id: thresholdLoader
        path: {
            let devPath = "/sys/class/power_supply/BAT0";
            if (pluginApi?.pluginSettings?.batteryDevice) {
                devPath = pluginApi.pluginSettings.batteryDevice;
            }
            return devPath + "/charge_control_end_threshold";
        }
        printErrors: false
        onLoaded: {
            let val = text();
            if (val) {
                let parsed = parseInt(val.trim());
                if (!isNaN(parsed) && parsed >= 50 && parsed <= 100) root.batteryThreshold = parsed;
            }
        }
    }

    FileView {
        id: batLoader
        property string device: "BAT0"
        path: "/sys/class/power_supply/" + device + "/uevent"
        printErrors: false

        onLoaded: {
            let content = text();
            if (!content) return;

            let lines = content.split("\n");
            let cap = 0, rate = 0, volt = 0, remain = 0;
            let status = "Unknown";

            for (let i = 0; i < lines.length; i++) {
                let line = lines[i].trim();
                if (line.indexOf("POWER_SUPPLY_CAPACITY=") === 0) cap = parseInt(line.split("=")[1]) || 0;
                else if (line.indexOf("POWER_SUPPLY_POWER_NOW=") === 0) rate = parseInt(line.split("=")[1]) || 0;
                else if (line.indexOf("POWER_SUPPLY_CURRENT_NOW=") === 0) rate = parseInt(line.split("=")[1]) || rate;
                else if (line.indexOf("POWER_SUPPLY_VOLTAGE_NOW=") === 0) volt = parseInt(line.split("=")[1]) || 0;
                else if (line.indexOf("POWER_SUPPLY_ENERGY_NOW=") === 0) remain = parseInt(line.split("=")[1]) || remain;
                else if (line.indexOf("POWER_SUPPLY_CHARGE_NOW=") === 0) remain = parseInt(line.split("=")[1]) || remain;
                else if (line.indexOf("POWER_SUPPLY_STATUS=") === 0) status = line.split("=")[1] || "Unknown";
            }

            root.batPercent = cap;
            root.batStatus = status.charAt(0).toUpperCase() + status.slice(1).toLowerCase();

            if (content.indexOf("POWER_SUPPLY_POWER_NOW=") !== -1) root.wattNum = rate / 1000000.0;
            else if (volt > 0) root.wattNum = (rate * volt) / 1000000000000.0;
            else root.wattNum = 0.0;

            if (root.wattNum > 0.1 && remain > 0) {
                let totalHours = 0;
                if (content.indexOf("POWER_SUPPLY_ENERGY_NOW=") !== -1) {
                    let energyNow = remain / 1000000.0;
                    if (root.batStatus === "Discharging") totalHours = energyNow / root.wattNum;
                    else if (root.batStatus === "Charging") {
                        let energyFull = 50.0;
                        for (let j = 0; j < lines.length; j++) {
                            if (lines[j].indexOf("POWER_SUPPLY_ENERGY_FULL=") === 0) {
                                energyFull = parseInt(lines[j].split("=")[1]) / 1000000.0;
                                break;
                            }
                        }
                        totalHours = (energyFull - energyNow) / root.wattNum;
                    }
                } else if (volt > 0) {
                    let chargeNow = remain / 1000000.0;
                    let currentNow = rate / 1000000.0;
                    if (currentNow > 0) {
                        if (root.batStatus === "Discharging") totalHours = chargeNow / currentNow;
                        else if (root.batStatus === "Charging") {
                            let chargeFull = 4.5;
                            for (let j = 0; j < lines.length; j++) {
                                if (lines[j].indexOf("POWER_SUPPLY_CHARGE_FULL=") === 0) {
                                    chargeFull = parseInt(lines[j].split("=")[1]) / 1000000.0;
                                    break;
                                }
                            }
                            totalHours = (chargeFull - chargeNow) / currentNow;
                        }
                    }
                }

                if (totalHours > 0 && totalHours < 24) {
                    let h = Math.floor(totalHours);
                    let m = Math.floor((totalHours - h) * 60);
                    root.timeRemaining = h + "h " + m + "m";
                } else root.timeRemaining = "0h 0m";
            } else if (root.batStatus === "Full" || root.batStatus === "Not charging") root.timeRemaining = "0h 0m";
            else root.timeRemaining = "...";
        }
    }

    Rectangle {
        id: visualCapsule
        anchors.centerIn: parent
        width: root.contentWidth
        height: root.contentHeight
        radius: Style.radiusL
        
        color: mouseArea.containsMouse 
            ? Color.mHover 
            : (root.batStatus === "Charging" ? Color.mPrimary : Style.capsuleColor)

        border.color: root.batStatus === "Charging" ? Color.mPrimary : Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        RowLayout {
            id: layout
            anchors.centerIn: parent
            spacing: Style.marginS

            NIcon {
                icon: (root.batStatus === "Charging" || root.batStatus === "Full") ? "battery-charging" : "battery-4"
                color: mouseArea.containsMouse || root.batStatus === "Charging" ? Color.mOnPrimary : Color.mOnSurface
            }

            NText {
                text: root.batPercent + "% " + (root.batStatus === "Charging" ? "+" : "-") + root.wattNum.toFixed(1) + "W"
                pointSize: barFontSize
                font.family: root.fixedFont
                font.weight: Font.Bold
                color: mouseArea.containsMouse || root.batStatus === "Charging" ? Color.mOnPrimary : Color.mOnSurface
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.updatePowerProfile();
            thresholdLoader.reload();
            pluginApi.openPanel(root.screen, root);
        }
    }
}