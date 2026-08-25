// Minimal Quickshell shell that hooks into niri.
//
// Requires:
//   - quickshell (pacman: quickshell)          -> provides ShellRoot/PanelWindow/etc
//   - qml-niri  (built from source)            -> provides the Niri QML module (IPC)
//   - a running niri session                    -> NIRI_SOCKET is exported to spawn-at-startup children
//
// Run: `quickshell`  (auto-loads ~/.config/quickshell/shell.qml)
// Launched by niri via: spawn-at-startup "quickshell"
//
// Everything here live-reloads as you save the file.

import Quickshell  // ShellRoot, PanelWindow, SystemClock, Quickshell.screens
import QtQuick     // Row, Text, Rectangle, Repeater, Timer...
import Niri        // the qml-niri plugin: workspaces, windows, overview, etc.
import Quickshell.Services.Notifications  // notification daemon + Notification type

ShellRoot {
    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 32
        color: "#1E1E2E" // catppuccin mocha base

        // ------------------------------------------------------------------
        // The niri bridge. Event-driven over the IPC socket; no polling.
        // Exposes: niri.workspaces, niri.windows, niri.focusedWindow,
        //          niri.overview, niri.keyboardLayouts, plus actions.
        // ------------------------------------------------------------------
        Niri {
            id: niri
            Component.onCompleted: connect()
            onConnected: console.log("quickshell connected to niri")
            onErrorOccurred: e => console.error("quickshell/niri:", e)
        }

        // ---------- left: workspaces + focused window title ----------
        Row {
            spacing: 6
            anchors {
                left: parent.left
                leftMargin: 8
                verticalCenter: parent.verticalCenter
            }

            // workspaces switcher
            Repeater {
                model: niri.workspaces
                delegate: Rectangle {
                    width: 26
                    height: 22
                    radius: 4
                    color: model.isFocused ? "#B4BEFE" : "#313244"

                    Text {
                        anchors.centerIn: parent
                        text: model.name || model.index
                        color: model.isFocused ? "#11111B" : "#CDD6F4"
                        font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: niri.focusWorkspaceById(model.id)
                    }
                }
            }

            // separator
            Rectangle { width: 1; height: 16; color: "#45475A" }

            // focused window title
            Text {
                width: 240
                text: niri.focusedWindow?.title ?? ""
                color: "#CDD6F4"
                font.pixelSize: 12
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        // ---------- right: clock ----------
        Text {
            anchors {
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            text: Qt.formatTime(clock.date, "HH:mm")
            color: "#CDD6F4"
            font.pixelSize: 12

            SystemClock {
                id: clock
                precision: SystemClock.Minutes // no seconds -> less work
            }
        }
    }

    // ------------------------------------------------------------------
    // Notification daemon + popups.
    // NotificationServer registers org.freedesktop.Notifications on the
    // DBus so notify-send (e.g. zsh-auto-notify) works without hanging.
    // Normal (transient) notifications are NOT in trackedNotifications,
    // so we keep our own popup list off the onNotification signal and
    // auto-expire each card. Rendered catppuccin mocha, top-right below
    // the bar; click a card to dismiss it.
    // ------------------------------------------------------------------
    NotificationServer {
        id: notifServer
        keepOnReload: true
        bodyMarkupSupported: false
        bodySupported: true
        actionsSupported: false
        imageSupported: false

        onNotification: n => notifications.manage(n)
    }

    PanelWindow {
        id: notifications
        anchors {
            top: true
            right: true
        }
        margins {
            top: 36       // just below the 32px bar
            right: 8
        }
        implicitWidth: 360
        onImplicitWidthChanged: console.log("DS win w=", implicitWidth)
        onImplicitHeightChanged: console.log("DS win h=", implicitHeight)
        exclusiveZone: 0           // float over content, don't reserve space
        aboveWindows: true
        focusable: false
        color: "transparent"

        // ---- our own popup stack (Notifications are not 'tracked') ----
        ListModel { id: popups }

        function remove(notif) {
            for (let i = 0; i < popups.count; ++i) {
                if (popups.get(i).notif === notif) { popups.remove(i); break }
            }
        }

        function manage(notif) {
            popups.append({ notif: notif })
            notif.closed.connect(() => remove(notif))

            // auto-expire after a delay based on urgency
            const ms = notif.urgency === NotificationUrgency.Enum.Critical ? 15000
                     : notif.urgency === NotificationUrgency.Enum.Low ? 6000 : 8000
            const t = Qt.createQmlObject("import QtQuick; Timer { repeat: false }", notifications)
            t.interval = ms
            t.running = true
            t.onTriggered.connect(() => { remove(notif); t.destroy() })
        }

        Column {
            width: 360
            spacing: 8

            Repeater {
                model: popups

                delegate: Rectangle {
                    readonly property var n: model.notif

                    width: 360
                    radius: 10
                    color: "#313244"             // catppuccin mocha surface0
                    border.color: "#45475A"      // surface1
                    border.width: 1

                    Column {
                        id: body
                        x: 10
                        y: 10
                        width: parent.width - 20
                        spacing: 4

                        Text {
                            text: n.appName
                            color: "#B4BEFE"      // lavender
                            font.pixelSize: 11
                            font.bold: true
                        }
                        Text {
                            width: parent.width
                            text: n.summary
                            color: "#CDD6F4"      // text
                            font.pixelSize: 12
                            font.bold: true
                            wrapMode: Text.Wrap
                        }
                        Text {
                            width: parent.width
                            visible: n.body.length > 0
                            text: n.body
                            color: "#A6ADC8"      // subtext0
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                        }
                    }

                    height: body.implicitHeight + 20

                    // click anywhere to dismiss
                    TapHandler {
                        onTapped: n.dismiss()
                    }
                }
            }
        }
    }
}
