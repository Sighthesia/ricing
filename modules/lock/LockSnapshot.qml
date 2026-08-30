import QtQuick
import "../lazerbar" as Lazer

// Prepare optional per-screen desktop images without creating an interactive window.
QtObject {
    id: root

    property var screen: null
    property var snapshotProvider: null
    // One URL slot per screen index; a surface binds only its own slot and
    // keeps the opaque fallback whenever its slot is empty.
    property var screenUrls: []
    property bool ready: false
    property int generation: 0
    property int requestedScreenCount: 0
    property int preparedScreenCount: 0
    property var preparedScreens: []
    property var expectedScreens: []

    signal prepared(int generation)

    // Resolve one surface's image slot; any out-of-range or non-integer index
    // resolves to the opaque fallback instead of another screen's image.
    function snapshotUrlFor(screenIndex): string {
        var index = Number(screenIndex)
        if (!isFinite(index) || index !== Math.floor(index) || index < 0)
            return ""
        return screenUrls[index] || ""
    }

    function request(screenCount): void {
        fallbackTimer.stop()
        generation += 1
        requestedScreenCount = Math.max(0, Math.floor(Number(screenCount) || 0))
        preparedScreenCount = 0
        preparedScreens = []
        expectedScreens = []
        for (var screenIndex = 0; screenIndex < requestedScreenCount; ++screenIndex)
            expectedScreens.push(screenIndex)
        ready = false
        screenUrls = []

        var requestGeneration = generation

        var result = null
        if (snapshotProvider) {
            if (typeof snapshotProvider === "function")
                result = snapshotProvider(screen, requestedScreenCount, requestGeneration,
                                          function(index, url) {
                                              root.reportReady(requestGeneration, index, url)
                                          })
            else if (typeof snapshotProvider.request === "function")
                result = snapshotProvider.request(screen, requestedScreenCount, requestGeneration,
                                                  function(index, url) {
                                                      root.reportReady(requestGeneration, index, url)
                                                  })
        }

        if (result !== null && result !== undefined) {
            // A synchronous result carries no screen index, so it can only
            // ever describe screen 0; every other screen falls back.
            var url = typeof result === "string" ? result : (result.url || "")
            root.storeUrl(requestGeneration, 0, url)
            if (result.ready !== false)
                finish(requestGeneration)
            else
                fallbackTimer.restart()
            return
        }

        if (requestedScreenCount === 0) {
            finish(generation)
            return
        }

        fallbackTimer.restart()
    }

    function reportReady(requestGeneration, screenIndex, url): void {
        if (requestGeneration !== generation || ready)
            return
        var index = Number(screenIndex)
        if (!isFinite(index) || index !== Math.floor(index)
                || index < 0 || index >= requestedScreenCount
                || expectedScreens.indexOf(index) < 0)
            return
        if (preparedScreens.indexOf(index) >= 0)
            return
        var nextScreens = preparedScreens.slice()
        nextScreens.push(index)
        preparedScreens = nextScreens
        preparedScreenCount = nextScreens.length
        root.storeUrl(requestGeneration, index, url || "")
        if (preparedScreenCount >= requestedScreenCount)
            finish(requestGeneration)
    }

    // Store one screen's URL immutably so reassignment notifies slot bindings.
    function storeUrl(requestGeneration, screenIndex, url): void {
        if (requestGeneration !== generation)
            return
        var nextUrls = screenUrls.slice()
        nextUrls[screenIndex] = url || ""
        screenUrls = nextUrls
    }

    function finish(requestGeneration): void {
        if (requestGeneration !== generation || ready)
            return
        fallbackTimer.stop()
        ready = true
        prepared(requestGeneration)
    }

    // The timeout deliberately resolves to an opaque-background-only state.
    // Screenshot providers may widen the window so real captures still land
    // before the lock commits.
    property int fallbackIntervalMs: Lazer.MotionTokens.medium
    property Timer fallbackTimer: Timer {
        interval: root.fallbackIntervalMs
        repeat: false
        onTriggered: root.finish(root.generation)
    }
}
