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
        implicitHeight: 44
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
                    width: 30
                    height: 26
                    radius: 5
                    color: model.isFocused ? "#B4BEFE" : "#313244"

                    Text {
                        anchors.centerIn: parent
                        text: model.name || model.index
                        color: model.isFocused ? "#11111B" : "#CDD6F4"
                        font.family: "Inter"
                        font.pointSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: niri.focusWorkspaceById(model.id)
                    }
                }
            }

            // separator
            Rectangle { width: 1; height: 20; color: "#45475A" }

            // focused window title
            Text {
                width: 240
                text: niri.focusedWindow?.title ?? ""
                color: "#CDD6F4"
                font.family: "Inter"
                font.pointSize: 11
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
            font.family: "Inter"
            font.pointSize: 11

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
    // Notifications are marked tracked => daemon keeps them alive and puts
    // them in trackedNotifications (which we render). A sweep timer expires
    // each one based on urgency. Rendered catppuccin mocha, top-right below
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
            top: 48       // just below the 44px bar
            right: 8
        }
        implicitWidth: 360
        exclusiveZone: 0           // float over content, don't reserve space
        aboveWindows: true
        focusable: false
        color: "transparent"

        // ---- popup state: per-notification expiry deadlines ----
        property var expiry: ({})   // id -> { notif, deadline }

        function manage(notif) {
            notif.tracked = true    // keep alive + show in trackedNotifications
            const ms = notif.urgency === NotificationUrgency.Enum.Critical ? 25000
                     : notif.urgency === NotificationUrgency.Enum.Low ? 10000 : 15000
            notifications.expiry[notif.id] = { notif: notif, deadline: Date.now() + ms }
            notif.closed.connect(() => { delete notifications.expiry[notif.id] })
            if (!expiryTimer.running) expiryTimer.restart()
        }

        Timer {
            id: expiryTimer
            interval: 500
            repeat: true
            running: false
            onTriggered: {
                const now = Date.now()
                for (const id of Object.keys(notifications.expiry)) {
                    const e = notifications.expiry[id]
                    if (e && now >= e.deadline) {
                        delete notifications.expiry[id]
                        e.notif.expire()
                    }
                }
            }
        }

        Column {
            width: 360
            spacing: 8

            Repeater {
                model: notifServer.trackedNotifications

                delegate: Rectangle {
                    readonly property var n: modelData

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
                            font.family: "Inter"
                            font.pixelSize: 11
                            font.bold: true
                        }
                        Text {
                            width: parent.width
                            text: n.summary
                            color: "#CDD6F4"      // text
                            font.family: "Inter"
                            font.pixelSize: 12
                            font.bold: true
                            wrapMode: Text.Wrap
                        }
                        Text {
                            width: parent.width
                            visible: n.body.length > 0
                            text: n.body
                            color: "#A6ADC8"      // subtext0
                            font.family: "Inter"
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
