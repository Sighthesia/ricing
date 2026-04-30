import QtQuick
import Quickshell
import qs.config
import qs.services
import "." as IslandCards
import "./SuperIslandWindowHintPresentationAdapter.js" as HintPresentationAdapter

// Registry that owns all card Component definitions and the event-to-component selection logic.
Item {
    id: registry

    // Shared values injected from the host widget.
    required property real pillHeight
    required property real flashRowHeight
    required property var currentTime
    required property bool hasPendingEvents
    required property real overlayExpandedWidth
    required property string phase
    required property real barExpandedTitleRevealProgress
    required property real barExpandedTitleRevealWidthProgress
    required property real attachedVerticalRevealProgress
    required property bool barExpandedSharedClockVisible
    required property bool barExpandedMainCardVisible
    required property real contentPaddingV

    // Public component references for direct Loader binding.
    readonly property Component idleComponent: _idleComponent
    readonly property Component overlayDeckMeasureComponent: _overlayDeckMeasureComponent
    readonly property Component windowHintMeasureCardComponent: _windowHintMeasureCardComponent
    readonly property Component windowHintBarExpandedMainMeasureCardComponent: _windowHintBarExpandedMainMeasureCardComponent
    readonly property Component windowHintBarExpandedDetachedMeasureCardComponent: _windowHintBarExpandedDetachedMeasureCardComponent

    // Returns the appropriate Component for a given event and track role.
    function componentForEvent(event, useStrip) {
        if (!event || event.type === "idle")
            return _idleComponent
        if (event.type === "window-hint") {
            const presentationKind = HintPresentationAdapter.windowHintPresentationKindForEvent(event, useStrip)

            if (!useStrip && presentationKind === "bar-expanded-main" && !registry.barExpandedMainCardVisible)
                return _emptyComponent

            if (presentationKind === "bar-expanded-main")
                return _windowHintBarExpandedMainCardComponent
            if (presentationKind === "bar-expanded-detached")
                return _windowHintBarExpandedDetachedCardComponent
            return _windowHintCardComponent
        }
        if (event.type === "media") {
            var showLyrics = SettingsService.data.mediaControl.showLyrics
                && SettingsService.data.mediaControl.preferLyrics
                && MediaControlService.hasLyrics
            if (showLyrics)
                return useStrip ? _stripLyricsCardComponent : _mainLyricsCardComponent
            return useStrip ? _stripMediaCardComponent : _mainMediaCardComponent
        }
        if (event.type === "workspace" || event.type === "window")
            return useStrip ? _stripWorkspaceCardComponent : _mainWorkspaceCardComponent
        if (event.priority === "critical" || event.subtitle !== "")
            return useStrip ? _stripNotificationCardComponent : _mainNotificationCardComponent
        return useStrip ? _stripCompactEventComponent : _compactEventComponent
    }

    // Clones an event object with a different presentation tag.
    function cloneEventWithPresentation(event, presentation) {
        const nextEvent = cloneEvent(event)
        nextEvent.presentation = presentation
        return nextEvent
    }

    // Deep-clones an event snapshot, filling missing fields with defaults.
    function cloneEvent(event) {
        const source = event || idleSnapshot()
        return {
            id: source.id || "",
            type: source.type || "idle",
            groupKey: source.groupKey || "idle",
            priority: source.priority || "passive",
            presentation: source.presentation || "baseline",
            relayReplace: !!source.relayReplace,
            sticky: !!source.sticky,
            title: source.title || "",
            subtitle: source.subtitle || "",
            icon: source.icon || "",
            workspaceLabel: source.workspaceLabel || "",
            workspaceId: source.workspaceId || "",
            workspaceIndex: source.workspaceIndex !== undefined ? source.workspaceIndex : -1,
            activeWorkspacePosition: source.activeWorkspacePosition !== undefined ? source.activeWorkspacePosition : -1,
            currentWindowId: source.currentWindowId || "",
            currentIndex: source.currentIndex !== undefined ? source.currentIndex : -1,
            timeoutMs: source.timeoutMs || 0,
            revision: source.revision || 0,
            timestamp: source.timestamp || 0
        }
    }

    // Returns the default idle snapshot used when no event is active.
    function idleSnapshot() {
        return {
            id: "idle",
            type: "idle",
            groupKey: "idle",
            priority: "passive",
            presentation: "baseline",
            relayReplace: false,
            title: Qt.formatDate(registry.currentTime, "M月d日") + " | " + Qt.formatDateTime(registry.currentTime, "hh:mm"),
            subtitle: "",
            icon: "",
            workspaceLabel: "",
            timeoutMs: 0,
            timestamp: Date.now()
        }
    }

    // Returns a display-safe event, falling back to idle snapshot.
    function displayEvent(event) {
        if (!event || event.type === "idle")
            return registry.idleSnapshot()
        return registry.cloneEvent(event)
    }

    // Empty placeholder used when a card should not render.
    Component {
        id: _emptyComponent

        Item {
            implicitWidth: 0
            implicitHeight: 0
            width: 0
            height: 0
        }
    }

    // Idle clock card used in the main track and measurement loaders.
    Component {
        id: _idleComponent

        IslandCards.IslandIdleClockCard {
            currentTime: registry.currentTime
            hasPendingEvents: registry.hasPendingEvents
            cardHeight: registry.pillHeight
        }
    }

    // Measurement-only overlay deck for control-center sizing.
    Component {
        id: _overlayDeckMeasureComponent

        IslandCards.ExpandedPanelDeck {
            width: registry.overlayExpandedWidth
            drawSurface: false
            measurementMode: true
        }
    }

    // Compact event card for the main track.
    Component {
        id: _compactEventComponent

        IslandCards.IslandCompactEventCard {
            event: eventData
            iconSource: resolvedIcon
            cardHeight: registry.pillHeight
        }
    }

    // Notification card with action buttons for the main track.
    Component {
        id: _mainNotificationCardComponent

        IslandCards.IslandNotificationActionCard {
            event: eventData
            iconSource: resolvedIcon
        }
    }

    // Media card in compact mode for the main track.
    Component {
        id: _mainMediaCardComponent

        IslandCards.IslandMediaCard {
            event: eventData
            iconSource: resolvedIcon
            compact: true
        }
    }

    // Lyrics card for the main track when synced lyrics are available.
    Component {
        id: _mainLyricsCardComponent

        IslandCards.IslandLyricsCard {
            event: eventData
            iconSource: resolvedIcon
        }
    }

    // Workspace card for the main track.
    Component {
        id: _mainWorkspaceCardComponent

        IslandCards.IslandWorkspaceCard {
            event: eventData
            iconSource: resolvedIcon
        }
    }

    // Default window-hint card presentation.
    Component {
        id: _windowHintCardComponent

        IslandCards.IslandWindowHintCard {
            event: eventData
        }
    }

    // Measurement-only window-hint card for sizing.
    Component {
        id: _windowHintMeasureCardComponent

        IslandCards.IslandWindowHintCard {
            event: eventData
            measurementMode: true
            hintData: WindowHintService.activeHint
        }
    }

    // Bar-expanded main window-hint card with title capsule reveal.
    Component {
        id: _windowHintBarExpandedMainCardComponent

        IslandCards.IslandWindowHintCard {
            event: registry.cloneEventWithPresentation(eventData, "bar-expanded-main")
            titleCapsuleRevealProgress: registry.phase === "hint-exit"
                ? registry.barExpandedTitleRevealProgress
                : Math.max(
                    registry.barExpandedTitleRevealProgress,
                    registry.barExpandedTitleRevealWidthProgress
                )
            outgoingClockOpacity: 1 - registry.attachedVerticalRevealProgress
            outgoingClockOffsetY: (1 - registry.attachedVerticalRevealProgress) * Math.max(8, registry.contentPaddingV * 2)
        }
    }

    // Measurement-only bar-expanded main window-hint card.
    Component {
        id: _windowHintBarExpandedMainMeasureCardComponent

        IslandCards.IslandWindowHintCard {
            event: registry.cloneEventWithPresentation(eventData, "bar-expanded-main")
            measurementMode: true
            hintData: WindowHintService.activeHint
            titleCapsuleRevealProgress: registry.phase === "hint-exit"
                ? registry.barExpandedTitleRevealProgress
                : Math.max(
                    registry.barExpandedTitleRevealProgress,
                    registry.barExpandedTitleRevealWidthProgress
                )
            outgoingClockOpacity: 1 - registry.attachedVerticalRevealProgress
            outgoingClockOffsetY: (1 - registry.attachedVerticalRevealProgress) * Math.max(8, registry.contentPaddingV * 2)
        }
    }

    // Bar-expanded detached window-hint card with relocated clock.
    Component {
        id: _windowHintBarExpandedDetachedCardComponent

        IslandCards.IslandWindowHintCard {
            event: registry.cloneEventWithPresentation(eventData, "bar-expanded-detached")
            relocatedClockOpacity: registry.attachedVerticalRevealProgress
            relocatedClockOffsetY: (1 - registry.attachedVerticalRevealProgress) * -Math.max(8, registry.contentPaddingV * 2)
            sharedClockActive: registry.barExpandedSharedClockVisible
        }
    }

    // Measurement-only bar-expanded detached window-hint card.
    Component {
        id: _windowHintBarExpandedDetachedMeasureCardComponent

        IslandCards.IslandWindowHintCard {
            event: registry.cloneEventWithPresentation(eventData, "bar-expanded-detached")
            measurementMode: true
            hintData: WindowHintService.activeHint
            relocatedClockOpacity: registry.attachedVerticalRevealProgress
            relocatedClockOffsetY: (1 - registry.attachedVerticalRevealProgress) * -Math.max(8, registry.contentPaddingV * 2)
            sharedClockActive: registry.barExpandedSharedClockVisible
        }
    }

    // Compact event card for the flash/strip track.
    Component {
        id: _stripCompactEventComponent

        IslandCards.IslandCompactEventCard {
            event: eventData
            iconSource: resolvedIcon
            cardHeight: registry.flashRowHeight
        }
    }

    // Notification card for the flash/strip track.
    Component {
        id: _stripNotificationCardComponent

        IslandCards.IslandNotificationActionCard {
            event: eventData
            iconSource: resolvedIcon
        }
    }

    // Media card in expanded mode for the flash/strip track.
    Component {
        id: _stripMediaCardComponent

        IslandCards.IslandMediaCard {
            event: eventData
            iconSource: resolvedIcon
            compact: false
        }
    }

    // Lyrics card for the flash/strip track when synced lyrics are available.
    Component {
        id: _stripLyricsCardComponent

        IslandCards.IslandLyricsCard {
            event: eventData
            iconSource: resolvedIcon
        }
    }

    // Workspace card for the flash/strip track.
    Component {
        id: _stripWorkspaceCardComponent

        IslandCards.IslandWorkspaceCard {
            event: eventData
            iconSource: resolvedIcon
        }
    }
}
