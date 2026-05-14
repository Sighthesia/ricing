import QtQuick

// Render a shared attached-island background for one bar section.
Item {
    id: root

    property color fillColor: "#ffa742"
    property color borderColor: "#14ffffff"
    property int horizontalPadding: 18
    property int verticalPadding: 8
    property int earRadius: 24
    property int bodyRadius: 14
    property real contentWidth: 0
    property real contentHeight: 0
    property int surfaceHeight: 0
    property string screenName: ""

    // Section type determines the ear layout: "center" keeps both top ears,
    // "left" mirrors the right layout with a top-right ear and a bottom-left ear,
    // and "right" keeps the left top ear while rotating the right ear down onto
    // the screen edge.
    property string sectionType: "center"

    readonly property bool hasContent: contentWidth > 0 && contentHeight > 0 && surfaceHeight > 0
    readonly property int bodyWidth: hasContent ? Math.max(contentWidth + horizontalPadding * 2, 0) : 0
    readonly property int totalHeight: hasContent ? Math.max(contentHeight + verticalPadding * 2, surfaceHeight) : 0

    // Center keeps two top ears; side bottom ears now render in dedicated overlay windows.
    readonly property bool isCenter: sectionType === "center"
    readonly property bool isLeft: sectionType === "left"
    readonly property bool isRight: sectionType === "right"
    readonly property bool hasLeftTopEar: isCenter || isRight
    readonly property bool hasTopRightEar: isCenter || isLeft
    readonly property int bodyHeight: hasContent ? totalHeight : 0
    readonly property int bodyY: 0
    readonly property int bodyX: hasLeftTopEar ? earRadius : 0

    implicitWidth: hasContent ? bodyWidth + (hasLeftTopEar ? earRadius : 0) + (hasTopRightEar ? earRadius : 0) : 0
    implicitHeight: hasContent ? totalHeight : 0
    width: implicitWidth
    height: implicitHeight

    // Paint the shared left top ear for center and right sections.
    Canvas {
        id: leftEar

        z: 0
        x: 0
        y: 0
        width: root.earRadius
        height: root.earRadius
        antialiasing: true
        visible: root.hasContent && root.hasLeftTopEar
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var h = height;
            var curve = Math.min(w, h);
            ctx.clearRect(0, 0, w, h);
            ctx.fillStyle = root.fillColor;
            ctx.strokeStyle = root.borderColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(w, 0);
            ctx.lineTo(w, h);
            ctx.arc(0, h, curve, 0, -Math.PI / 2, true);
            ctx.closePath();
            ctx.fill();
            ctx.stroke();
        }
        onHeightChanged: requestPaint()
        onWidthChanged: requestPaint()
    }

    // Paint the adaptive body between the edge decorations.
    Canvas {
        id: centerBody

        z: 0
        x: root.bodyX
        y: root.bodyY
        width: root.bodyWidth
        height: root.bodyHeight
        antialiasing: true
        visible: root.hasContent
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var h = height;
            var radius = Math.min(root.bodyRadius, w / 2, h / 2);
            ctx.clearRect(0, 0, w, h);
            ctx.fillStyle = root.fillColor;
            ctx.strokeStyle = root.borderColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            if (root.isRight) {
                // Only bottom-left corner rounded.
                ctx.moveTo(0, 0);
                ctx.lineTo(w, 0);
                ctx.lineTo(w, h);
                ctx.lineTo(radius, h);
                ctx.quadraticCurveTo(0, h, 0, h - radius);
            } else if (root.isLeft) {
                // Only bottom-right corner rounded.
                ctx.moveTo(0, 0);
                ctx.lineTo(w, 0);
                ctx.lineTo(w, h - radius);
                ctx.quadraticCurveTo(w, h, w - radius, h);
                ctx.lineTo(0, h);
            } else {
                // Center: both bottom corners rounded.
                ctx.moveTo(0, 0);
                ctx.lineTo(w, 0);
                ctx.lineTo(w, h - radius);
                ctx.quadraticCurveTo(w, h, w - radius, h);
                ctx.lineTo(radius, h);
                ctx.quadraticCurveTo(0, h, 0, h - radius);
            }
            ctx.closePath();
            ctx.fill();
            ctx.stroke();
        }
        onHeightChanged: requestPaint()
        onWidthChanged: requestPaint()
    }

    // Paint the shared right top ear for center and left sections.
    Canvas {
        id: rightEar

        z: 0
        x: root.bodyX + root.bodyWidth - 1
        y: 0
        width: root.earRadius
        height: root.earRadius
        antialiasing: true
        visible: root.hasContent && root.hasTopRightEar
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var h = height;
            var curve = Math.min(w, h);
            ctx.clearRect(0, 0, w, h);
            ctx.fillStyle = root.fillColor;
            ctx.strokeStyle = root.borderColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(0, h);
            ctx.arc(w, h, curve, Math.PI, -Math.PI / 2, false);
            ctx.closePath();
            ctx.fill();
            ctx.stroke();
        }
        onHeightChanged: requestPaint()
        onWidthChanged: requestPaint()
    }

}
