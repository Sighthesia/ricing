import QtQuick

// Render a shared attached-island background for one bar section.
Item {
    id: root

    property color fillColor: "#242424dd"
    property color borderColor: "#14ffffff"
    property int horizontalPadding: 18
    property int verticalPadding: 8
    property int earRadius: 12
    property int bodyRadius: 14
    property real contentWidth: 0
    property real contentHeight: 0
    property int surfaceHeight: 0

    readonly property bool hasContent: contentWidth > 0 && contentHeight > 0 && surfaceHeight > 0
    readonly property int bodyWidth: hasContent ? Math.max(contentWidth + horizontalPadding * 2, 0) : 0
    readonly property int bodyHeight: hasContent ? Math.max(contentHeight + verticalPadding * 2, surfaceHeight) : 0

    implicitWidth: hasContent ? bodyWidth + earRadius * 2 : 0
    implicitHeight: hasContent ? bodyHeight : 0
    width: implicitWidth
    height: implicitHeight

    // Paint the left attachment as an inner quarter-circle ear.
    Canvas {
        id: leftEar

        x: 0
        y: 0
        width: root.earRadius
        height: root.earRadius
        antialiasing: true
        visible: root.hasContent
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

    // Paint the adaptive center body between the edge decorations.
    Canvas {
        id: centerBody

        x: root.earRadius
        y: 0
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
            ctx.moveTo(0, 0);
            ctx.lineTo(w, 0);
            ctx.lineTo(w, h - radius);
            ctx.quadraticCurveTo(w, h, w - radius, h);
            ctx.lineTo(radius, h);
            ctx.quadraticCurveTo(0, h, 0, h - radius);
            ctx.closePath();
            ctx.fill();
            ctx.stroke();
        }
        onHeightChanged: requestPaint()
        onWidthChanged: requestPaint()
    }

    // Paint the right attachment as a mirrored inner quarter-circle ear.
    Canvas {
        id: rightEar

        x: root.earRadius + root.bodyWidth
        y: 0
        width: root.earRadius
        height: root.earRadius
        antialiasing: true
        visible: root.hasContent
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
