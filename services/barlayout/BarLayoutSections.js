var widgetSpacing = 6

function sectionWidth(sectionModel) {
    if (!sectionModel || !sectionModel.length) {
        return 0
    }

    const totalWidth = sectionModel.reduce(
        (total, widget) => total + (widget.implicitWidth || widget.width || 0),
        0,
    )

    return totalWidth + Math.max(0, sectionModel.length - 1) * widgetSpacing
}
