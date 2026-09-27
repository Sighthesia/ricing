.pragma library

// Wallpaper reveal geometry: where the switch circle starts and how far it has
// to grow to swallow the screen. Pure math so it stays testable without QML.

// Distance from the reveal origin to the farthest corner of a surface. Growing
// the circle to this radius covers the whole surface from any origin, including
// one that sits on a screen edge.
function coverRadius(originX, originY, width, height) {
    var w = Math.max(0, Number(width) || 0)
    var h = Math.max(0, Number(height) || 0)
    if (w <= 0 || h <= 0)
        return 0
    var x = Math.min(Math.max(Number(originX) || 0, 0), w)
    var y = Math.min(Math.max(Number(originY) || 0, 0), h)
    var farX = Math.max(x, w - x)
    var farY = Math.max(y, h - y)
    return Math.sqrt(farX * farX + farY * farY)
}

// Project a global trigger point (screen coordinates) onto one screen. Returns
// null when the point belongs to a different screen, so the caller can fall back
// to that screen's centre instead of revealing from a mirrored position.
function localOrigin(pointX, pointY, screenX, screenY, width, height) {
    var w = Math.max(0, Number(width) || 0)
    var h = Math.max(0, Number(height) || 0)
    if (w <= 0 || h <= 0)
        return null
    var localX = (Number(pointX) || 0) - (Number(screenX) || 0)
    var localY = (Number(pointY) || 0) - (Number(screenY) || 0)
    if (localX < 0 || localY < 0 || localX > w || localY > h)
        return null
    return { x: localX, y: localY }
}
