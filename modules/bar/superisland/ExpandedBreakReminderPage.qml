import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Full-screen 20-20-20 reminder page rendered inside the expanded SuperIsland shell.
Item {
    id: root

    property real _haloPhase: 0

    function pageActivated() {
        _haloDrift.restart()
        _ringCanvas.requestPaint()
        _haloCanvas.requestPaint()
    }

    function pageDeactivated() {
    }

    function pageExitDuration() {
        return 0
    }

    readonly property real _ringSize: Math.max(220, Math.min(width, height) * 0.28)
    readonly property real _ringThickness: Math.max(14, Math.round(_ringSize * 0.055))
    readonly property real _haloPadding: Math.max(root._ringThickness * 1.45, 22)
    readonly property real _visualRingSize: root._ringSize + root._haloPadding * 2
    readonly property real _contentPadding: Math.max(20, Math.round(28 * Theme.uiScale))
    readonly property int _introDuration: Math.max(900, Math.round(Theme.anim.moveDuration * 5.5))
    readonly property int _outroDuration: Math.max(700, BreakReminderService.outroMs)
    readonly property real _introProgress:
        BreakReminderService.breakActive
            ? root._clamp01(BreakReminderService.phaseElapsedMs / root._introDuration)
            : 1
    readonly property real _outroProgress:
        BreakReminderService.outroActive
            ? root._clamp01(BreakReminderService.phaseElapsedMs / root._outroDuration)
            : 0
    readonly property real _introEase: root._easeOutCubic(root._introProgress)
    readonly property real _countdownEase:
        root._easeInOutSine(1 - Math.max(0, Math.min(1, BreakReminderService.breakProgress)))
    readonly property real _outroEase: root._easeInOutSine(root._outroProgress)
    readonly property real _ringMotionScale: root._lerp(1.0, 0.84, root._countdownEase)
    readonly property real _coreScale: {
        const introScale = root._lerp(1.24, 1.0, root._introEase)
        const outroScale = BreakReminderService.outroActive
            ? root._lerp(1.0, 1.2, root._outroEase)
            : 1.0
        return introScale * root._ringMotionScale * outroScale
    }
    readonly property real _coreOpacity:
        BreakReminderService.outroActive
            ? root._lerp(1.0, 0.0, root._outroEase)
            : root._lerp(0.0, 1.0, root._introEase)

    function _clamp01(value) {
        return Math.max(0, Math.min(1, value))
    }

    function _lerp(from, to, progress) {
        const t = root._clamp01(progress)
        return from + (to - from) * t
    }

    function _easeOutCubic(progress) {
        const t = 1 - root._clamp01(progress)
        return 1 - t * t * t
    }

    function _easeInOutSine(progress) {
        const t = root._clamp01(progress)
        return -(Math.cos(Math.PI * t) - 1) / 2
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.18)
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.14)
        border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.22)
        border.width: 1
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.06)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root._contentPadding
        spacing: Math.max(18, Math.round(22 * Theme.uiScale))

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                radius: 999
                color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.18)
                border.color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.46)
                border.width: 1
                implicitWidth: _badgeRow.implicitWidth + 24
                implicitHeight: 34

                RowLayout {
                    id: _badgeRow
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        width: 8
                        height: 8
                        radius: width / 2
                        color: Colors.highlight
                    }

                    Text {
                        text: BreakReminderService.phaseTitle
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        font.weight: Font.DemiBold
                        color: Colors.text
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: _snoozeButton
                visible: !BreakReminderService.outroActive
                color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.34)
                border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.8)
                border.width: 1
                radius: 12
                implicitWidth: _snoozeLabel.implicitWidth + 28
                implicitHeight: 38

                Text {
                    id: _snoozeLabel
                    anchors.centerIn: parent
                    text: "延后 " + BreakReminderService.snoozeMinutes + " 分钟"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Colors.text
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BreakReminderService.snoozeBreak()
                }
            }

            Rectangle {
                id: _finishButton
                visible: !BreakReminderService.outroActive
                color: Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.9)
                border.color: "transparent"
                radius: 12
                implicitWidth: _finishLabel.implicitWidth + 28
                implicitHeight: 38

                Text {
                    id: _finishLabel
                    anchors.centerIn: parent
                    text: "结束休息"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Colors.background
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BreakReminderService.finishBreak()
                }
            }
        }

        Item { Layout.fillHeight: true }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: Math.min(parent.width, Math.round(760 * Theme.uiScale))
            implicitWidth: _visualColumn.implicitWidth
            implicitHeight: _visualColumn.implicitHeight
            opacity: root._coreOpacity
            scale: root._coreScale
            transformOrigin: Item.Center

            ColumnLayout {
                id: _visualColumn
                anchors.centerIn: parent
                spacing: Math.max(16, Math.round(20 * Theme.uiScale))

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: root._visualRingSize
                    implicitHeight: root._visualRingSize

                    Canvas {
                        id: _haloCanvas
                        anchors.fill: parent

                        onPaint: {
                            const context = getContext("2d")
                            const size = Math.min(width, height)
                            const center = size / 2
                            const baseRadius = center - root._ringThickness / 2 + root._ringThickness * 0.95
                            const segmentCount = 96
                            const baseLineWidth = root._ringThickness * 0.56

                            context.clearRect(0, 0, width, height)
                            context.lineCap = "round"

                            for (let index = 0; index < segmentCount; index++) {
                                const progress = index / segmentCount
                                const angle = progress * Math.PI * 2 - Math.PI / 2
                                const nextAngle = angle + Math.PI * 2 / segmentCount * 0.86
                                const wave = 0.5
                                    + 0.27 * Math.sin(angle * 3 + root._haloPhase * Math.PI * 2)
                                    + 0.18 * Math.sin(angle * 7 - root._haloPhase * Math.PI * 4)
                                const clampedWave = Math.max(0.08, wave)
                                const radius = baseRadius + Math.sin(angle * 2 + root._haloPhase * Math.PI * 2) * (root._ringThickness * 0.18)

                                context.strokeStyle = Qt.rgba(
                                    Colors.background.r * 0.55,
                                    Colors.background.g * 0.55,
                                    Colors.background.b * 0.55,
                                    0.22 + clampedWave * 0.2
                                )
                                context.lineWidth = baseLineWidth * (0.6 + clampedWave * 0.72)
                                context.beginPath()
                                context.arc(center, center, radius, angle, nextAngle, false)
                                context.stroke()
                            }
                        }
                    }

                    Canvas {
                        id: _ringCanvas
                        anchors.centerIn: parent
                        width: root._ringSize
                        height: root._ringSize

                        onPaint: {
                            const context = getContext("2d")
                            const progress = Math.max(0, Math.min(1, BreakReminderService.breakProgress))
                            const size = Math.min(width, height)
                            const lineWidth = root._ringThickness
                            const center = size / 2
                            const radius = center - lineWidth / 2
                            const startAngle = -Math.PI / 2
                            const endAngle = startAngle + Math.PI * 2 * progress

                            context.clearRect(0, 0, width, height)

                            context.lineCap = "round"
                            context.lineWidth = lineWidth
                            context.strokeStyle = Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.24)
                            context.beginPath()
                            context.arc(center, center, radius, 0, Math.PI * 2, false)
                            context.stroke()

                            context.strokeStyle = Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.16)
                            context.lineWidth = lineWidth * 1.7
                            context.beginPath()
                            context.arc(center, center, radius, startAngle, endAngle, false)
                            context.stroke()

                            context.strokeStyle = Qt.rgba(Colors.highlight.r, Colors.highlight.g, Colors.highlight.b, 0.98)
                            context.lineWidth = lineWidth
                            context.beginPath()
                            context.arc(center, center, radius, startAngle, endAngle, false)
                            context.stroke()
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: BreakReminderService.countdownText
                            font.family: Theme.fontMono
                            font.pixelSize: Math.max(34, Math.round(42 * Theme.uiScale))
                            font.bold: true
                            color: Colors.text
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "保持视线离开屏幕"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Colors.textMuted
                        }
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: BreakReminderService.phaseSubtitle
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.max(16, Theme.fontSizeBody)
                        font.weight: Font.Medium
                        color: Colors.text
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "看看窗外、远处墙面或走廊尽头，让眼部肌肉从近距离聚焦里松开。"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        color: Colors.textMuted
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        Layout.maximumWidth: Math.min(parent.width, Math.round(720 * Theme.uiScale))
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    Connections {
        target: BreakReminderService

        function onRemainingMsChanged() {
            _ringCanvas.requestPaint()
            _haloCanvas.requestPaint()
        }

        function onBreakProgressChanged() {
            _ringCanvas.requestPaint()
            _haloCanvas.requestPaint()
        }

        function onPhaseElapsedMsChanged() {
            _ringCanvas.requestPaint()
            _haloCanvas.requestPaint()
        }
    }

    NumberAnimation {
        id: _haloDrift
        target: root
        property: "_haloPhase"
        from: 0
        to: 1
        duration: Math.max(6000, Math.round(Theme.anim.moveDuration * 28))
        loops: Animation.Infinite
        running: true
    }

    on_HaloPhaseChanged: {
        _haloCanvas.requestPaint()
    }
}
