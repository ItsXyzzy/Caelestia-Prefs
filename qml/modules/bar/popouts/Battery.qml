pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    function formatSeconds(s: int): string {
        const day = Math.floor(s / 86400);
        const hr = Math.floor(s / 3600) % 24;
        const min = Math.floor(s / 60) % 60;

        let comps = [];
        if (day > 0)
            comps.push(Tr.trN("%n day", "%n days", day));
        if (hr > 0)
            comps.push(Tr.trN("%n hour", "%n hours", hr));
        if (min > 0)
            comps.push(Tr.trN("%n min", "%n mins", min));

        return comps.join(Tr.trCtx(", ", "duration component separator"));
    }

    function powerProfileToString(p: int): string {
        switch (p) {
        case PowerProfile.Balanced:
            return Tr.trCtx("Balanced", "power profile");
        case PowerProfile.Performance:
            return Tr.trCtx("Performance", "power profile");
        case PowerProfile.PowerSaver:
            return Tr.trCtx("Power saver", "power profile");
        default:
            return Tr.trCtx("Unknown", "power profile");
        }
    }

    function perfDegradationToString(p: int): string {
        switch (p) {
        case PerformanceDegradationReason.HighTemperature:
            return Tr.tr("The device is too hot");
        case PerformanceDegradationReason.LapDetected:
            return Tr.tr("The device is on a lap");
        default:
            return Tr.tr("Unknown reason");
        }
    }

    readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state)
    readonly property color chargeFill: "#2e7d32"
    readonly property color chargeTrack: "#c8e6c9"
    readonly property color chargeOnTrack: "#1b5e20"
    readonly property color chargeOnFill: "#e8f5e9"
    property real animPerc: UPower.displayDevice.percentage

    implicitWidth: Tokens.sizes.bar.batteryWidth
    implicitHeight: mainCol.implicitHeight

    Behavior on animPerc {
        Anim {}
    }

    ColumnLayout {
        id: mainCol

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.medium

        StyledClippingRect {
            id: tank

            readonly property color baseFillColour: root.charging ? root.chargeFill : Colours.palette.m3secondary
            readonly property color baseContainerColour: root.charging ? root.chargeTrack : Colours.palette.m3secondaryContainer

            Layout.fillWidth: true
            Layout.preferredHeight: 120

            color: baseContainerColour
            radius: Tokens.rounding.large

            Behavior on color {
                CAnim {
                    duration: Tokens.anim.durations.expressiveDefaultEffects
                }
            }

            TankContents {
                id: tankLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium

                accentColour: root.charging ? root.chargeOnTrack : Colours.palette.m3primary
                textColour: Colours.palette.m3onSurface

                Behavior on accentColour {
                    CAnim {
                        duration: Tokens.anim.durations.expressiveDefaultEffects
                    }
                }
            }

            StyledRect {
                id: fillRect

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                implicitWidth: parent.width * root.animPerc

                color: tank.baseFillColour
                radius: Tokens.rounding.extraSmall
                clip: true

                Behavior on color {
                    CAnim {
                        duration: Tokens.anim.durations.expressiveDefaultEffects
                    }
                }

                Rectangle {
                    id: pulse

                    visible: root.charging
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * 0.35
                    x: -width

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: Qt.alpha("#ffffff", 0)
                        }
                        GradientStop {
                            position: 0.5
                            color: Qt.alpha("#ffffff", 0.22)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.alpha("#ffffff", 0)
                        }
                    }

                    SequentialAnimation {
                        running: root.charging
                        loops: Animation.Infinite

                        NumberAnimation {
                            target: pulse
                            property: "x"
                            from: -pulse.width
                            to: fillRect.width
                            duration: Tokens.anim.durations.expressiveSlowEffects * 3
                            easing: Tokens.anim.expressiveSlowEffects
                        }
                        PauseAnimation {
                            duration: Tokens.anim.durations.expressiveSlowEffects
                        }
                    }
                }

                TankContents {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: tankLayout.anchors.margins
                    width: tankLayout.width

                    accentColour: root.charging ? root.chargeOnFill : Colours.palette.m3primaryContainer
                    textColour: root.charging ? root.chargeOnFill : Colours.palette.m3onSecondary

                    Behavior on accentColour {
                        CAnim {
                            duration: Tokens.anim.durations.expressiveDefaultEffects
                        }
                    }

                    Behavior on textColour {
                        CAnim {
                            duration: Tokens.anim.durations.expressiveDefaultEffects
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: {
                const dev = UPower.displayDevice;
                if (!dev.isLaptopBattery)
                    return Tr.tr("Power profile: %1").arg(root.powerProfileToString(PowerProfiles.profile));

                if (UPower.onBattery) {
                    const time = root.formatSeconds(dev.timeToEmpty);
                    if (time)
                        return Tr.tr("Time remaining: %1").arg(time);
                    return Tr.tr("Calculating remaining battery life...");
                }

                if (dev.timeToFull > 0)
                    return Tr.tr("Time until charged: %1").arg(root.formatSeconds(dev.timeToFull));
                if (Math.round(dev.percentage * 100) === 100)
                    return Tr.tr("Fully charged!");
                return Tr.tr("Calculating time until charged...");
            }
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        Loader {
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true

            active: PowerProfiles.degradationReason !== PerformanceDegradationReason.None

            sourceComponent: StyledRect {
                implicitWidth: child.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: child.implicitHeight + Tokens.padding.large

                color: Colours.palette.m3error
                radius: Tokens.rounding.large

                Column {
                    id: child

                    anchors.centerIn: parent

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -font.pointSize / 10

                            text: "warning"
                            color: Colours.palette.m3onError
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            // TRANSLATORS: charger or thermal warning: the battery cannot draw full power
                            text: Tr.tr("Performance degraded")
                            color: Colours.palette.m3onError
                            font: Tokens.font.title.small
                        }

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -font.pointSize / 10

                            text: "warning"
                            color: Colours.palette.m3onError
                        }
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter

                        text: root.perfDegradationToString(PowerProfiles.degradationReason)
                        color: Colours.palette.m3onError
                    }
                }
            }
        }

        StyledRect {
            id: profiles

            property string current: {
                const p = PowerProfiles.profile;
                if (p === PowerProfile.PowerSaver)
                    return saver.icon;
                if (p === PowerProfile.Performance)
                    return perf.icon;
                return balance.icon;
            }

            Layout.alignment: Qt.AlignHCenter

            implicitWidth: saver.implicitHeight + balance.implicitHeight + perf.implicitHeight + Tokens.padding.medium * 2 + Tokens.spacing.largeIncreased * 2
            implicitHeight: Math.max(saver.implicitHeight, balance.implicitHeight, perf.implicitHeight) + Tokens.padding.small

            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.full

            StyledRect {
                id: indicator

                color: Colours.palette.m3primary
                radius: Tokens.rounding.full
                state: profiles.current

                states: [
                    State {
                        name: saver.icon

                        Fill {
                            item: saver
                        }
                    },
                    State {
                        name: balance.icon

                        Fill {
                            item: balance
                        }
                    },
                    State {
                        name: perf.icon

                        Fill {
                            item: perf
                        }
                    }
                ]

                transitions: Transition {
                    AnchorAnim {}
                }
            }

            Profile {
                id: saver

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Tokens.padding.extraSmall

                profile: PowerProfile.PowerSaver
                icon: "energy_savings_leaf"
            }

            Profile {
                id: balance

                anchors.centerIn: parent

                profile: PowerProfile.Balanced
                icon: "balance"
            }

            Profile {
                id: perf

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Tokens.padding.extraSmall

                profile: PowerProfile.Performance
                icon: "rocket_launch"
            }
        }
    }

    component Fill: AnchorChanges {
        required property Item item

        target: indicator
        anchors.left: item.left
        anchors.right: item.right
        anchors.top: item.top
        anchors.bottom: item.bottom
    }

    component Profile: Item {
        required property string icon
        required property int profile

        implicitWidth: icon.implicitHeight + Tokens.padding.small
        implicitHeight: icon.implicitHeight + Tokens.padding.small

        StateLayer {
            radius: Tokens.rounding.full
            color: profiles.current === parent.icon ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: PowerProfiles.profile = parent.profile
        }

        MaterialIcon {
            id: icon

            anchors.centerIn: parent

            text: parent.icon
            fontStyle: Tokens.font.icon.large
            color: profiles.current === text ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
            fill: profiles.current === text ? 1 : 0

            Behavior on fill {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }

    component TankContents: ColumnLayout {
        id: contents

        required property color accentColour
        required property color textColour

        spacing: 0

        MaterialIcon {
            Layout.leftMargin: -Tokens.padding.extraSmall
            text: UPower.displayDevice.isLaptopBattery ? "battery_full" : "bolt"
            color: contents.accentColour
            fontStyle: Tokens.font.icon.large
        }

        StyledText {
            Layout.fillWidth: true
            text: UPower.displayDevice.isLaptopBattery ? Tr.tr("Battery") : Tr.tr("Power")
            color: contents.textColour
            font: Tokens.font.body.medium
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                text: "bolt"
                color: contents.accentColour
                fontStyle: Tokens.font.icon.large
                fill: 1

                scale: root.charging ? 1 : 0
                opacity: root.charging ? 1 : 0

                Behavior on scale {
                    Anim {
                        type: Anim.FastSpatial
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }
            }

            StyledText {
                visible: UPower.displayDevice.isLaptopBattery
                text: Strings.percentOne(UPower.displayDevice.percentage)
                color: contents.accentColour
                font: Tokens.font.headline.medium
            }
        }
    }
}
