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
import Quickshell.Services.SystemTray     // SystemTray singleton + SystemTrayItem
import Quickshell.Services.Pipewire       // volume widget: Pipewire, PwNode, PwObjectTracker
import Quickshell.Services.Mpris          // media widget: Mpris, MprisPlayer
import Quickshell.Io                       // Process + StdioCollector (system monitor)
import Quickshell.Widgets                 // IconImage (icon-style images)

ShellRoot {
    PanelWindow {
        id: bar
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
                    width: 32
                    height: 28
                    radius: 5
                    color: model.isFocused ? "#B4BEFE" : "#313244"

                    Text {
                        anchors.centerIn: parent
                        text: {
                            var kanji = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
                            var n = parseInt(model.name) || (model.index + 1)
                            return kanji[n] ? kanji[n] : String(n)
                        }
                        color: model.isFocused ? "#11111B" : "#CDD6F4"
                        font.family: "Inter"
                        font.pointSize: 13
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
                font.pointSize: 13
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        // ---------- right: media + volume + clock + system tray ----------
        Row {
            id: rightSide
            spacing: 10
            anchors {
                right: parent.right
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }

            // system monitor — CPU / RAM / GPU temp, polled every 2s
            Row {
                id: monitorWidget
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                visible: monitorText.text !== ""

                // shell one-liner: prints "<cpu%> <mem%> <gpu°C>" in one line
                // (CPU is a 0.4s delta sample; memory uses total-available)
                property string monitorScript: `t1=$(awk "/^cpu /{u=\$2+\$4;i=\$5} END{print u+i}" /proc/stat)
b1=$(awk "/^cpu /{u=\$2+\$4;i=\$5} END{print u}" /proc/stat)
sleep 0.4
t2=$(awk "/^cpu /{u=\$2+\$4;i=\$5} END{print u+i}" /proc/stat)
b2=$(awk "/^cpu /{u=\$2+\$4;i=\$5} END{print u}" /proc/stat)
cpu=$(( (b2-b1)*100/(t2-t1) ))
mem=$(awk "/MemTotal:/{t=\$2} /MemAvailable:/{a=\$2} END{printf \"%d\", (t-a)*100/t}" /proc/meminfo)
gpu=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null || echo 0)
printf \"%d %d %d\" \"$cpu\" \"$mem\" \"$gpu\"
`

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "file:///usr/share/icons/Papirus-Dark/16x16/devices/cpu.svg"
                    sourceSize.width: 14
                    sourceSize.height: 14
                }
                Text {
                    id: monitorText
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: "#A6ADC8"            // subtext0
                    font.family: "Inter"
                    font.pointSize: 12
                }

                Process {
                    id: monitorProc
                    running: false
                    environment: {
                        "PATH": "/usr/local/bin:/usr/bin:/bin",
                        "XDG_RUNTIME_DIR": "/run/user/1000"
                    }
                    stdout: StdioCollector { waitForEnd: true }
                    onStarted: console.log("MON started")
                    onExited: {
                        console.log("MON exited", exitCode, "out:", JSON.stringify(monitorProc.stdout.text))
                        const out = monitorProc.stdout.text.trim()
                        const m = out.match(/^(\d+) (\d+) (\d+)$/)
                        if (m) monitorText.text = m[1] + "% · " + m[2] + "% · " + m[3] + "°"
                        else console.log("MON parse FAILED:", out)
                    }
                }

                Timer {
                    id: monitorTimer
                    interval: 2000
                    repeat: true
                    running: true
                    triggeredOnStart: true
                    onTriggered: {
                        console.log("MON script:", JSON.stringify(monitorWidget.monitorScript))
                        monitorProc.command = ["sh", "-c", monitorWidget.monitorScript]
                        monitorProc.running = true
                    }
                }
            }

            // media player — shows the current MPRIS track (spotifyd);
            // prev / play-pause / next buttons, hidden when nothing plays.
            Row {
                id: mediaWidget
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                visible: player != null && player.trackTitle !== ""

                readonly property var player: {
                    const ps = Mpris.players.values
                    for (const p of ps) if (p.isPlaying) return p
                    return ps[0] ?? null
                }

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "file:///usr/share/icons/Papirus-Dark/16x16/actions/media-skip-backward.svg"
                    sourceSize.width: 14
                    sourceSize.height: 14
                    TapHandler {
                        onTapped: if (mediaWidget.player?.canGoPrevious) mediaWidget.player.previous()
                    }
                }
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "file:///usr/share/icons/Papirus-Dark/16x16/actions/" + (mediaWidget.player?.isPlaying
                        ? "media-playback-pause.svg"
                        : "media-playback-start.svg")
                    sourceSize.width: 14
                    sourceSize.height: 14
                    TapHandler {
                        onTapped: if (mediaWidget.player?.canTogglePlaying) mediaWidget.player.togglePlaying()
                    }
                }
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "file:///usr/share/icons/Papirus-Dark/16x16/actions/media-skip-forward.svg"
                    sourceSize.width: 14
                    sourceSize.height: 14
                    TapHandler {
                        onTapped: if (mediaWidget.player?.canGoNext) mediaWidget.player.next()
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 240
                    elide: Text.ElideRight
                    font.family: "Inter"
                    font.pointSize: 12
                    color: "#A6ADC8"            // subtext0
                    text: mediaWidget.player
                        ? mediaWidget.player.trackArtist + " — " + mediaWidget.player.trackTitle
                        : ""
                }
            }

            // volume — icon + %, scroll = level, click = mute
            PwObjectTracker {
                objects: [Pipewire.defaultAudioSink]
            }

            Item {
                id: volumeWidget
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: volumeInner.implicitWidth
                implicitHeight: volumeInner.implicitHeight

                readonly property var node: Pipewire.defaultAudioSink
                // Papirus-Dark icon paths (Qt can't resolve themed icons under niri)
                readonly property string volumeIconPath: {
                    const v = node?.audio?.volume ?? 0
                    const name = node?.audio?.muted || v <= 0 ? "audio-volume-muted"
                        : v < 0.34 ? "audio-volume-low"
                        : v < 0.67 ? "audio-volume-medium"
                        : "audio-volume-high"
                    return "file:///usr/share/icons/Papirus-Dark/16x16/actions/" + name + ".svg"
                }

                Row {
                    id: volumeInner
                    spacing: 4

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: volumeWidget.volumeIconPath
                        sourceSize.width: 16
                        sourceSize.height: 16
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round((volumeWidget.node?.audio?.volume ?? 0) * 100) + "%"
                        color: "#CDD6F4"
                        font.family: "Inter"
                        font.pointSize: 12
                    }
                }

                // cycle the default audio sink on right-click (Easy Effects excluded).
                // Sinks are matched by node object + description — never by numeric
                // id, since Pipewire ids change on every daemon reload.
                function cycleSink() {
                    const sinks = Pipewire.nodes.values.filter(n =>
                        n && n.isSink && !String(n.description ?? "").toLowerCase().includes("easy effects"))
                    if (sinks.length < 2) return
                    const cur = Pipewire.defaultAudioSink
                    const next = sinks[(sinks.indexOf(cur) + 1) % sinks.length]
                    if (!next) return
                    Pipewire.preferredDefaultAudioSink = next
                    osd.showSink(next.description || next.name || "unknown sink")
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) volumeWidget.cycleSink()
                        else volumeWidget.node.audio.muted = !volumeWidget.node.audio.muted
                    }
                    onWheel: wheel => {
                        const n = volumeWidget.node
                        if (!n) return
                        const delta = wheel.angleDelta.y > 0 ? 0.02 : -0.02
                        n.audio.volume = Math.max(0, Math.min(1.0, n.audio.volume + delta))
                    }
                }
            }

            // clock
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatTime(clock.date, "HH:mm")
                color: "#CDD6F4"
                font.family: "Inter"
                font.pointSize: 13

                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes // no seconds -> less work
                }
            }

            // system tray — pinned to the far right, darker chip so its
            // start/end is obvious.
            Rectangle {
                id: trayBox
                visible: trayRepeater.count > 0   // hide when nothing is in the tray
                radius: 6
                height: 30
                color: "#181825"             // catppuccin mocha mantle (darker than bar base)
                border.color: "#313244"      // surface0 edge
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: trayRow.implicitWidth + 8

                Row {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        id: trayRepeater
                        model: SystemTray.items

                        delegate: Rectangle {
                            required property var modelData
                            readonly property var item: modelData

                            width: 24
                            height: 24
                            radius: 5
                            color: ma.containsMouse ? "#45475A" : "transparent"

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 17
                                source: item.icon
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                onClicked: {
                                    if (item.hasMenu) {
                                        // show the item's menu just below the icon
                                        var pos = parent.mapToItem(bar.contentItem, 0, 0)
                                        item.display(bar, pos.x, pos.y + parent.height)
                                    } else {
                                        item.activate()
                                    }
                                }
                                onPressAndHold: item.secondaryActivate()
                            }
                        }
                    }
                }
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
            bottom: true      // full-height window: size never changes -> no resize bug
        }
        margins {
            top: 48       // just below the 44px bar
            right: 8
        }
        implicitWidth: 360
        visible: notifServer.trackedNotifications.values.length > 0
        mask: Region { item: popupList.contentItem }   // reveal only the cards
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

        ListView {
            id: popupList
            anchors {
                top: parent.top
                right: parent.right
                bottom: parent.bottom
            }
            width: 360
            interactive: false
            spacing: 8
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

    // ------------------------------------------------------------------
    // OSD: "sink switched" indicator, centered a bit below mid-screen.
    // Full-width layer window whose mask reveals only the card, so it
    // never interacts with layout and never needs to resize.
    // ------------------------------------------------------------------
    PanelWindow {
        id: osd
        visible: false
        anchors {
            top: true
            left: true
            right: true
        }
        margins {
            top: osd.osdTop       // a bit below the middle of the screen
        }
        implicitHeight: osdCard.height
        mask: Region { item: osdCard }   // only the card shows / is interactive
        exclusiveZone: 0
        aboveWindows: true
        focusable: false
        color: "transparent"

        property int osdTop: Math.round((Quickshell.screens[0]?.height ?? 1080) * 0.55)

        function showSink(label) {
            osdLabel.text = label
            osdTimer.restart()
            osd.visible = true
        }

        Rectangle {
            id: osdCard
            width: 320
            height: 56
            radius: 12
            color: "#313244"             // surface0
            border.color: "#45475A"      // surface1
            border.width: 1
            anchors.horizontalCenter: parent.horizontalCenter

            Row {
                anchors.centerIn: parent
                spacing: 12

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "file:///usr/share/icons/Papirus-Dark/16x16/actions/audio-volume-high.svg"
                    sourceSize.width: 26
                    sourceSize.height: 26
                }
                Text {
                    id: osdLabel
                    anchors.verticalCenter: parent.verticalCenter
                    width: 240
                    elide: Text.ElideRight
                    text: ""
                    color: "#CDD6F4"
                    font.family: "Inter"
                    font.pointSize: 13
                }
            }
        }

        Timer {
            id: osdTimer
            interval: 2200
            onTriggered: osd.visible = false
        }
    }
}
