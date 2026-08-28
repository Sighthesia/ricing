import QtQuick
import "../lazerbar" as Lazer

// Prepare an optional desktop image without creating an interactive window.
QtObject {
    id: root

    property var screen: null
    property var snapshotProvider: null
    property url snapshotUrl: ""
    property bool ready: false
    property int generation: 0
    property int requestedScreenCount: 0
    property int preparedScreenCount: 0
    property var preparedScreens: []
    property var expectedScreens: []

    signal prepared(int generation)

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
        snapshotUrl = ""

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
            if (typeof result === "string")
                snapshotUrl = result
            else if (result.url)
                snapshotUrl = result.url
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
                || expectedScreens.indexOf(index) < 0)
            return
        if (preparedScreens.indexOf(index) >= 0)
            return
        var nextScreens = preparedScreens.slice()
        nextScreens.push(index)
        preparedScreens = nextScreens
        preparedScreenCount = nextScreens.length
        if (url)
            snapshotUrl = url
        if (preparedScreenCount >= requestedScreenCount)
            finish(requestGeneration)
    }

    function finish(requestGeneration): void {
        if (requestGeneration !== generation || ready)
            return
        fallbackTimer.stop()
        ready = true
        prepared(requestGeneration)
    }

    // The timeout deliberately resolves to an opaque-background-only state.
    property Timer fallbackTimer: Timer {
        interval: Lazer.MotionTokens.medium
        repeat: false
        onTriggered: root.finish(root.generation)
    }
}
