import QtQuick

// Render the center dock zone as a reusable attached island surface.
// Keep the label centered while the surface morphs around its contents.
Item {
    id: root

    property string label: "QuickShell"
    property color fillColor: "#242424dd"
    property color textColor: "#ffffff"
    readonly property int horizontalPadding: 18
    readonly property int verticalPadding: 8
    readonly property int earRadius: 12
    readonly property int bodyRadius: 14
    readonly property int bodyWidth: labelText.implicitWidth + horizontalPadding * 2
    readonly property int bodyHeight: Math.max(labelText.implicitHeight + verticalPadding * 2, 30)

    implicitWidth: bodyWidth + earRadius * 2
    implicitHeight: bodyHeight

    // Paint the left attachment as a top-attached patch with an inner quarter-circle edge.
    Canvas {
        id: leftEar

        x: 0
        y: 0
        width: root.earRadius
        height: root.earRadius
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var h = height;
            var curve = Math.min(w, h);
            ctx.clearRect(0, 0, w, h);
            ctx.fillStyle = root.fillColor;
            ctx.strokeStyle = "rgba(255, 255, 255, 0.08)";
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
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var h = height;
            var radius = Math.min(root.bodyRadius, w / 2, h / 2);
            ctx.clearRect(0, 0, w, h);
            ctx.fillStyle = root.fillColor;
            ctx.strokeStyle = "rgba(255, 255, 255, 0.08)";
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

    // Paint the right attachment as a mirrored top-attached patch.
    Canvas {
        id: rightEar

        x: root.earRadius + root.bodyWidth
        y: 0
        width: root.earRadius
        height: root.earRadius
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            var h = height;
            var curve = Math.min(w, h);
            ctx.clearRect(0, 0, w, h);
            ctx.fillStyle = root.fillColor;
            ctx.strokeStyle = "rgba(255, 255, 255, 0.08)";
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

    // Center the status label inside the adaptive island body.
    Text {
        id: labelText

        anchors.centerIn: centerBody
        text: root.label
        color: root.textColor
        font.pixelSize: 14
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

}
