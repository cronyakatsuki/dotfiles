import QtQuick
import Quickshell

// Module wrapper: full bar height with a 2px accent underline at the bottom.
// Children go into an inner Row (centered); the wrapper hides together with
// its content and never reserves extra space.
Item {
    id: moduleRoot
    property color accent: "#B4BEFE"
    default property alias content: row.data

    width: row.implicitWidth + 8
    height: 44                      // bar height
    visible: row.implicitWidth > 0  // hide with the content

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0
    }

    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 2
        color: accent
    }
}