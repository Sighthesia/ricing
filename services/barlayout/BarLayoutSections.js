var widgetSpacing = 0

function sectionWidth(sectionModel) {
    if (!sectionModel || !sectionModel.length) {
        return 0
    }

    return sectionModel.reduce(
        (total, widget) => total + (widget.implicitWidth || widget.width || 0),
        0,
    )
}
