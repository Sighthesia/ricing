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

    signal prepared(int generation)

    function request(screenCount): void {
        generation += 1
        requestedScreenCount = Math.max(0, Number(screenCount) || 0)
        preparedScreenCount = 0
        preparedScreens = []
        ready = false
        snapshotUrl = ""

        var result = null
        if (snapshotProvider) {
            if (typeof snapshotProvider === "function")
                result = snapshotProvider(screen, requestedScreenCount, generation,
                                          function(index, url) {
                                              root.reportReady(generation, index, url)
                                          })
            else if (typeof snapshotProvider.request === "function")
                result = snapshotProvider.request(screen, requestedScreenCount, generation,
                                                  function(index, url) {
                                                      root.reportReady(generation, index, url)
                                                  })
        }

        if (result !== null && result !== undefined) {
            if (typeof result === "string")
                snapshotUrl = result
            else if (result.url)
                snapshotUrl = result.url
            if (result.ready !== false)
                finish(generation)
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
        var index = Math.max(0, Number(screenIndex) || 0)
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
        ready = true
        prepared(requestGeneration)
    }

    // The timeout deliberately resolves to an opaque-background-only state.
    Timer {
        id: fallbackTimer
        interval: Lazer.MotionTokens.medium
        repeat: false
        onTriggered: root.finish(root.generation)
    }
}
