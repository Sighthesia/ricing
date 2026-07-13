import QtQuick
import "../../services" as Services

// Sample the wallpaper at the surface's screen region and derive glass edge colors.
// Bright/saturated wallpaper areas produce colorful glass edges; dark areas stay
// restrained toward the static theme color.  Falls back to theme colors when the
// wallpaper is unavailable, empty, or not yet loaded.
// The output is opaque — each caller applies its own alpha (glow/highlight intensity
// and hover multiplier) so existing Behaviors on the parent's glassGlowColor and
// glassHighlightColor animate the transition smoothly.
Item {
    id: root

    // Surface screen position and size in global compositor coordinates.
    property real surfaceScreenX: 0
    property real surfaceScreenY: 0
    property real surfaceWidth: 0
    property real surfaceHeight: 0

    // The screen that contains this surface.
    property real screenWidth: 1
    property real screenHeight: 1

    // Static fallback color sources for dark or un-sampled regions.
    property color fallbackColor: Services.SettingsService.appearance.glassThemeAdaptive
        ? Services.Color.mPrimary
        : Services.Color.mOutline
    property color fallbackHighlightColor: Services.SettingsService.appearance.glassThemeAdaptive
        ? Services.Color.mPrimary
        : Services.Color.mOnSurface

    // Output: wallpaper-influenced base color (opaque, caller applies alpha).
    readonly property color baseColor: _effectiveBase
    readonly property color baseHighlightColor: _effectiveHighlight

    // True when the wallpaper image is loaded and ready for sampling.
    readonly property bool wallpaperReady: _img.status === Image.Ready

    // --- internal ---

    // Raw sampled wallpaper color at the surface's screen region.
    property color _rawSample: "transparent"

    // Derived from _rawSample, blends with fallback.
    readonly property color _effectiveBase: wallpaperReady && _rawSample.a > 0.01
        ? _deriveFromWallpaper(_rawSample, fallbackColor)
        : fallbackColor
    readonly property color _effectiveHighlight: wallpaperReady && _rawSample.a > 0.01
        ? _deriveFromWallpaper(_rawSample, fallbackHighlightColor)
        : fallbackHighlightColor

    // Load wallpaper at a small size for efficient sampling.
    Image {
        id: _img
        source: Services.WallpaperService.currentWallpaper
            ? "file://" + Services.WallpaperService.currentWallpaper
            : ""
        sourceSize { width: 160 }
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    // 8x8 pixel canvas for reading wallpaper pixel data at the surface region.
    Canvas {
        id: _canvas
        width: 8
        height: 8
        visible: false

        function sample() {
            if (_img.status === Image.Ready)
                requestPaint()
        }

        onPaint: {
            var ctx = getContext("2d")
            if (!ctx || _img.status !== Image.Ready) return

            var iw = _img.sourceSize.width
            var ih = _img.sourceSize.height
            if (iw <= 0 || ih <= 0) return

            // Compute the visible crop region matching PreserveAspectCrop.
            var imgAR = iw / ih
            var screenAR = screenWidth / screenHeight
            var cropX = 0, cropY = 0, cropW = iw, cropH = ih
            if (imgAR > screenAR) {
                // Image wider than screen — crop horizontal bands.
                cropW = ih * screenAR
                cropX = (iw - cropW) / 2
            } else {
                // Image taller than screen — crop vertical bands.
                cropH = iw / screenAR
                cropY = (ih - cropH) / 2
            }

            // Surface center UV on screen.
            var u = (surfaceScreenX + surfaceWidth / 2) / screenWidth
            var v = (surfaceScreenY + surfaceHeight / 2) / screenHeight
            u = Math.max(0.0, Math.min(1.0, u))
            v = Math.max(0.0, Math.min(1.0, v))

            // Map to image source coordinates and sample a small region.
            var sx = cropX + u * cropW
            var sy = cropY + v * cropH
            var sw = Math.max(1, (surfaceWidth / screenWidth) * cropW)
            var sh = Math.max(1, (surfaceHeight / screenHeight) * cropH)

            ctx.clearRect(0, 0, width, height)
            ctx.drawImage(_img,
                sx - sw / 2, sy - sh / 2, sw, sh,
                0, 0, width, height)

            // Average pixel data.
            var imageData = ctx.getImageData(0, 0, width, height)
            var data = imageData.data
            var r = 0, g = 0, b = 0, count = 0
            for (var i = 0; i < data.length; i += 4) {
                r += data[i]
                g += data[i + 1]
                b += data[i + 2]
                count++
            }

            if (count > 0)
                _rawSample = Qt.rgba(r / count / 255, g / count / 255, b / count / 255, 1.0)
        }

        Connections {
            target: _img
            function onStatusChanged() { _canvas.sample() }
        }
    }

    // Blend sampled wallpaper color with the corresponding fallback.
    // Weighting: bright/saturated regions let wallpaper dominate;
    // dark regions stay closer to the static theme color.
    function _deriveFromWallpaper(sampled, fallback) {
        // Relative luminance (sRGB coefficients).
        var lum = 0.2126 * sampled.r + 0.7152 * sampled.g + 0.0722 * sampled.b
        var maxC = Math.max(sampled.r, sampled.g, sampled.b)
        var minC = Math.min(sampled.r, sampled.g, sampled.b)
        var sat = maxC > 0.01 ? (maxC - minC) / maxC : 0

        // Wallpaper influence weight.
        // Minimum 0.05 so even dark regions get a subtle hint.
        var wpWeight = Math.min(1.0, Math.max(0.05, (lum - 0.12) * 1.8 + sat * 1.0))

        return Qt.rgba(
            sampled.r * wpWeight + fallback.r * (1 - wpWeight),
            sampled.g * wpWeight + fallback.g * (1 - wpWeight),
            sampled.b * wpWeight + fallback.b * (1 - wpWeight),
            1.0
        )
    }

    // Resample when inputs change.
    onSurfaceScreenXChanged: _canvas.sample()
    onSurfaceScreenYChanged: _canvas.sample()
    onSurfaceWidthChanged: _canvas.sample()
    onSurfaceHeightChanged: _canvas.sample()
    onScreenWidthChanged: _canvas.sample()
    onScreenHeightChanged: _canvas.sample()

    Connections {
        target: Services.WallpaperService
        function onWallpaperChanged() {
            // Image status change triggers canvas.sample() via the existing connection.
        }
    }
}
