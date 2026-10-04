import QtQuick
import QtTest
import "../../modules/bar" as Bar
import "../../modules/lazerbar" as Lazer

// Focused content contract tests for BarPopupIdentity / BarPopupActions / BarPopupSlider.
// Uses fake/injected callbacks so real singleton services are never mutated.
Item {
    id: root
    width: 400
    height: 800

    Component { id: identityComp; Bar.BarPopupIdentity {} }
    Component { id: sliderComp; Bar.BarPopupSlider {} }
    Component { id: actionsComp; Bar.BarPopupActions {} }

    // Recorder slots the injected fake services write into, so an assertion can
    // see which object the panel actually handed over.
    property var _movedStream: null
    property var _movedSink: null
    property var _pickedSink: null
    property var _pickedSource: null

    // Recursive search across children/data.
    function findByName(item, name) {
        if (!item)
            return null
        if (item.objectName === name)
            return item
        var kids = item.children
        if (kids) {
            for (var i = 0; i < kids.length; i++) {
                var r = findByName(kids[i], name)
                if (r)
                    return r
            }
        }
        var dataList = item.data
        if (dataList && dataList !== kids) {
            for (var j = 0; j < dataList.length; j++) {
                var d = dataList[j]
                if (!d || d === item)
                    continue
                // Avoid double-walk if already in children.
                var already = false
                if (kids) {
                    for (var k = 0; k < kids.length; k++) {
                        if (kids[k] === d) { already = true; break }
                    }
                }
                if (already)
                    continue
                var rd = findByName(d, name)
                if (rd)
                    return rd
            }
        }
        return null
    }

    // Collecting search across children/data.
    function findAllByName(item, name, result) {
        var found = result || []
        if (!item)
            return found
        if (item.objectName === name)
            found.push(item)
        var kids = item.children
        if (kids) {
            for (var i = 0; i < kids.length; i++)
                findAllByName(kids[i], name, found)
        }
        return found
    }

    TestCase {
        name: "BarPopupIdentity"
        when: windowShown

        function test_identityRendersRailAndText() {
            var item = createTemporaryObject(identityComp, root, {
                title: "Volume",
                iconSource: "",
                summary: "Speakers",
                hostWidth: 260
            })
            verify(item !== null, "identity should be created")
            verify(item.visible)
            compare(item.hostWidth, 260)
            compare(item.implicitHeight, 48)
            compare(item.height, 48)
            compare(item.color, Lazer.LazerTheme.settingsRail)
            var titleNode = findByName(item, "identityTitle")
            verify(titleNode !== null, "title text should exist")
            compare(titleNode.text, "Volume")
            compare(titleNode.elide, Text.ElideRight)
            var summaryNode = findByName(item, "identitySummary")
            verify(summaryNode !== null, "summary text should exist")
            compare(summaryNode.text, "Speakers")
            compare(summaryNode.color, Lazer.LazerTheme.textMuted)
            var iconNode = findByName(item, "identityIcon")
            verify(iconNode !== null, "icon image should exist")
            verify(!iconNode.visible, "empty iconSource should hide icon")
            // With icon source set, icon becomes visible and 16px.
            var item2 = createTemporaryObject(identityComp, root, {
                title: "T",
                iconSource: Qt.resolvedUrl("../../modules/lazerbar/icons/music.svg"),
                summary: "",
                hostWidth: 220
            })
            var icon2 = findByName(item2, "identityIcon")
            verify(icon2.visible, "icon with source should be visible")
            compare(icon2.width, 16)
            compare(icon2.height, 16)
        }

        function test_emptyIconAndSummaryCollapseTheHeader() {
            // The mod-key window hint runs its header with neither field set: it
            // supplies a title only, because the chips and the rows already show
            // both counts and the focused row already shows the app icon. That
            // only reads as "less redundant" if the two slots actually collapse.
            var bare = createTemporaryObject(identityComp, root, {
                title: "Workspace 2", iconSource: "", summary: "", hostWidth: 260
            })
            var full = createTemporaryObject(identityComp, root, {
                title: "Workspace 2",
                iconSource: Qt.resolvedUrl("../../modules/lazerbar/icons/music.svg"),
                summary: "2 windows", hostWidth: 260
            })
            verify(!findByName(bare, "identityIcon").visible, "icon must collapse")
            verify(!findByName(bare, "identitySummary").visible, "summary must collapse")
            verify(findByName(full, "identityIcon").visible, "icon shows when supplied")
            verify(findByName(full, "identitySummary").visible, "summary shows when supplied")

            // The collapsed icon slot must not leave a hole. A Row skips its
            // invisible children, so the text column has to move left by the
            // slot width plus the row spacing - otherwise a title-only header
            // sits 24px further right than every other header and reads as a
            // misalignment against the body below it.
            var bareText = findByName(bare, "identityTitle").parent
            var fullText = findByName(full, "identityTitle").parent
            var slot = findByName(full, "identityIcon").parent
            // Row children are positioned during layout, which lands a couple of turns
            // after a dynamically created object, not on the same frame.
            wait(30)
            compare(bareText.x, 0, "bare text column offset")
            compare(fullText.x, slot.width + 8, "full text column offset")
        }

        function test_identityFixedHeaderHeight() {
            var a = createTemporaryObject(identityComp, root, { title: "A", summary: "", hostWidth: 200 })
            var b = createTemporaryObject(identityComp, root, { title: "B", summary: "long summary", hostWidth: 300 })
            compare(a.height, 48)
            compare(b.height, 48)
            compare(a.implicitHeight, 48)
            compare(b.implicitHeight, 48)
            verify(b.width !== a.width, "explicit hostWidth should drive width")
        }

        function test_identityCloseHiddenByDefault() {
            var item = createTemporaryObject(identityComp, root, { title: "Bar", summary: "center", hostWidth: 260 })
            var closeBtn = findByName(item, "identityCloseButton")
            verify(closeBtn !== null, "close button should exist")
            verify(!closeBtn.visible, "hover menus must not show the header close button")
        }

        function test_identityCloseShownForPersistentMenu() {
            var item = createTemporaryObject(identityComp, root, {
                title: "Bar", summary: "center", hostWidth: 260, showClose: true
            })
            var closeBtn = findByName(item, "identityCloseButton")
            verify(closeBtn.visible, "persistent menus must show the header close button")
            compare(closeBtn.height, 32)
            var calls = 0
            item.closeRequested.connect(function() { calls++ })
            item.closeRequested()
            compare(calls, 1)
        }
    }

    TestCase {
        name: "BarPopupSlider"
        when: windowShown

        function test_sliderExposesSignalsAndMutedState() {
            var item = createTemporaryObject(sliderComp, root, {
                value: 0.42,
                muted: true,
                label: "Volume"
            })
            verify(item !== null)
            verify(item.visible)
            compare(item.value, 0.42)
            verify(item.muted)
            compare(item.label, "Volume")
            compare(item.sliderRow.labelText, "Volume")
            var muteBtn = findByName(item, "sliderMuteButton")
            verify(muteBtn !== null, "mute button should exist")
            verify(item.muteRow.visible, "mute button visible when showMute true")
            verify(item.showMute)
            verify(item.effectiveMuted)
            // Manual spy for valueCommitted and toggleRequested.
            var valueCalls = 0
            var lastValue = -1
            var toggleCalls = 0
            item.valueCommitted.connect(function(v){ valueCalls++; lastValue = v })
            item.toggleRequested.connect(function(){ toggleCalls++ })
            item.valueCommitted(0.77)
            compare(valueCalls, 1)
            compare(lastValue, 0.77)
            item.toggleRequested()
            compare(toggleCalls, 1)
        }

        function test_sliderValueNorm() {
            var item = createTemporaryObject(sliderComp, root, { value: 0.5, muted: false, label: "Test" })
            verify(Math.abs(item.clampedValue - 0.5) < 0.001)
            var fillNode = findByName(item, "sliderFill")
            verify(fillNode !== null)
            verify(item.sliderControl.displayValue >= 0)
            verify(fillNode.width >= 0)
            compare(item.sliderControl.nubItem.height, item.sliderControl.trackItem.height)
            verify(item.sliderControl.nubItem.color !== item.sliderControl.trackFillItem.color)
            verify(item.sliderRow.contentItem.x + item.sliderRow.contentItem.width
                    <= item.sliderRow.width - item.sliderRow.contentPadding + 0.5)
        }

        function test_sliderSilentOnInit() {
            var item = createTemporaryObject(sliderComp, root, { value: 0.42, muted: false, label: "Volume" })
            verify(!item.sliderControl.flashActive, "init must not flash")
        }

        function test_sliderFlashesOnExternalStep() {
            var item = createTemporaryObject(sliderComp, root, { value: 0.42, muted: false, label: "Volume" })
            verify(!item.sliderControl.flashActive)
            // Live follow (wheel on the bar icon) moves the value outside
            // the slider's own setValue path; the new step must still flash.
            item.value = 0.6
            verify(item.sliderControl.flashActive, "external step change should flash")
            tryCompare(item.sliderControl, "flashActive", false, 3000)
            item.value = 0.6
            wait(100)
            verify(!item.sliderControl.flashActive, "repeat of the same step must not flash")
        }

        function test_sliderOwnDragEchoDoesNotReflash() {
            var item = createTemporaryObject(sliderComp, root, { value: 0.42, muted: false, label: "Volume" })
            item.sliderControl.setValue(70)
            verify(item.sliderControl.flashActive, "own drag flashes once")
            tryCompare(item.sliderControl, "flashActive", false, 3000)
            // Service echo of our own drag carries the same step: silent.
            item.value = 0.7
            wait(100)
            verify(!item.sliderControl.flashActive, "echo of own drag must not flash again")
        }
    }

    TestCase {
        name: "BarPopupActions"
        when: windowShown

        function test_eachActionKindCreatesVisibleRoot() {
            var kinds = ["volume", "brightness", "media", "notifications", "tray"]
            for (var i = 0; i < kinds.length; i++) {
                var kind = kinds[i]
                var item = createTemporaryObject(actionsComp, root, { actionKind: kind, payload: null })
                verify(item !== null, "actions for " + kind + " should be created")
                verify(item.visible, "actions root should be visible for " + kind)
                var actionsRoot = findByName(item, "actionsRoot")
                verify(actionsRoot !== null, "actionsRoot should exist for " + kind)
                verify(actionsRoot.visible, "actionsRoot visible for " + kind)
            }
        }

        function test_theWindowHintFitsInsideItsOwnSurface() {
            // The hint's columns are the surface. If the surface is narrower than
            // the columns need, the overflow is clipped rather than reported - the
            // right column is simply drawn past the edge of the panel and cut off,
            // with nothing anywhere saying so.
            var three = [{ windowId: "10", title: "a", icon: "", isFocused: false },
                        { windowId: "11", title: "b", icon: "", isFocused: true }]
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "window-hint",
                payload: { hint: {
                    workspaceId: "42", activeWorkspacePosition: 1, previousActiveWorkspacePosition: 1,
                    windows: three,
                    previousWindows: [{ windowId: "20", title: "p", icon: "", isFocused: false }],
                    nextWindows: [{ windowId: "30", title: "n", icon: "", isFocused: false }]
                } }
            })
            wait(20)
            var body = findByName(item, "windowHintBody")
            var column = findByName(item, "actionsRoot")
            verify(body !== null, "the hint body should exist")
            // Two neighbours of 180, the active column of 360, and the gap between
            // each pair - plus the content column's own inset on each side. Without
            // the inset term the surface is 16px short and the right column is
            // clipped; without the two gaps it is 12px short and the right column is
            // clipped by exactly that much.
            //
            // The active column is TWICE a neighbour's, so the old `3 * 180 + 2 * 6`
            // is not merely stale - it is 180px narrower than the panel, and a
            // surface sized from it would crop the whole right-hand neighbour. Stated
            // as the five terms rather than as a product so the wide middle is
            // visible in the expectation.
            compare(body.width, 180 + 6 + 360 + 6 + 180,
                "the body is as wide as its two neighbours, the wide active column and "
                    + "the two gaps, was " + body.width)
            verify(item.implicitWidth >= body.width,
                "and the surface is at least that wide, was " + item.implicitWidth)
            compare(item.implicitWidth, body.width + item.contentInset * 2,
                "exactly the body plus the content column's inset")
            // What has to fit inside the content column is the PANEL.
            //
            // Read off the panel rather than off the strip's width, and deliberately
            // so: the strip has no width of its own any more, because every column
            // places itself from how far it is from the workspace the panel is
            // centred on. A strip read for a width would report 0 and pass here while
            // the columns it no longer bounds ran past the surface. At rest the panel
            // IS the widest thing painted - the active column's right edge is one
            // gutter before the panel's own - so the panel's extent is the honest
            // measurement of it.
            var strip = findByName(body, "windowHintStrip")
            verify(strip !== null, "the strip should exist")
            compare(strip.x, 0,
                "and the strip starts at - and stays at - the panel's left edge")
            verify(body.x + body.width <= column.width,
                "the panel ends inside the content column, was "
                    + (body.x + body.width) + " against " + column.width)
            // Mid-crossing there are `span + 3` columns for a three-column panel, so
            // spare ones sit outside the panel on purpose, and what keeps them off the
            // surface is this clip rather than the panel's width. Asserted separately
            // because a panel that fitted with no clip would paint a crossing's spare
            // columns over the desktop - which is a different fault from a cropped
            // right-hand column, and the one a width check cannot see.
            compare(body.clip, true,
                "and the crossing's spare columns are clipped, not merely off-panel")
            verify(column.x + column.width <= item.width,
                "and the content column ends inside the surface")
        }

        function test_theWindowHintKeepsThreeColumnsWhenNeighboursAreEmpty() {
            // The panel is a fixed three-column frame, so this surface width must
            // not depend on what the neighbour workspaces are running. A width that
            // shrank here would resize the layer-shell surface and its input region
            // while the key is still held.
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "window-hint",
                payload: { hint: {
                    workspaceId: "42", activeWorkspacePosition: 1, previousActiveWorkspacePosition: 1,
                    windows: [],
                    previousWindows: [],
                    nextWindows: []
                } }
            })
            wait(20)
            var body = findByName(item, "windowHintBody")
            compare(body.width, 180 + 6 + 360 + 6 + 180,
                "still a neighbour, a gutter, the wide active column, a gutter and a "
                    + "neighbour, was " + body.width)
            compare(item.implicitWidth, body.width + item.contentInset * 2)
            var column = findByName(item, "actionsRoot")
            // The active workspace is still the middle column, read from where the
            // focus highlight is placed rather than from a named column delegate.
            var wash = findByName(body, "windowHintFocusFrame")
            verify(wash !== null, "the focus highlight should exist")
            // One column plus the gap before it: the middle column starts a pitch in,
            // and the pitch is the column plus the gap.
            // The host's inset is declared to the body, and the band's whole geometry
            // depends on it: the band has to sit `bandWidgetGutter` from the SURFACE,
            // which is further out than the body's own edge, so without this number it
            // would measure against the body and sit twice as far in.
            compare(body.surfaceInset, item.contentInset,
                "the body is told how far the host insets it")

            // The WIDE middle slot starts one neighbour and one gutter in - and it is
            // the neighbours' pitch, not a third of the panel, that puts it there.
            // Then the card's own horizontal inset inside that slot: the clearance,
            // the indicator's width, and the clearance again - 8 + 3 + 8.
            compare(wash.x, 180 + 6 + 8 + 3 + 8,
                "and the active workspace is still the middle one, was " + wash.x)
            compare(wash.width, 360 - 2 * (8 + 3 + 8),
                "filling the wide slot less its padding, was " + wash.width)
            // The strip has no width of its own any more - every column places itself
            // from how far it is from the workspace the panel is centred on - so what
            // has to fit inside the content column is the PANEL, which is also the
            // widest thing in it. Measured on the panel rather than on the strip
            // because a strip measured at zero would have passed while the columns
            // it no longer bounds ran past the surface.
            verify(body.x + body.width <= column.width,
                "and the panel still ends inside the content column, was "
                    + (body.x + body.width) + " against " + column.width)
        }

        function test_volumeExposesSliderAndFakeCallback() {
            var fake = Qt.createQmlObject('import QtQuick; QtObject { property int setCalls: 0; property real last: -1; property int toggleCalls: 0; function setSinkVolume(v){ setCalls++; last=v } function toggleSinkMute(){ toggleCalls++ } }', root, "fakeVol")
            var item = createTemporaryObject(actionsComp, root, { actionKind: "volume", payload: { volumeService: fake, volume: 0.42, muted: true } })
            var slider = findByName(item, "volumeSlider")
            verify(slider !== null, "volumeSlider should exist for volume kind")
            verify(slider.visible, "volumeSlider visible")
            verify(findByName(item, "volumeContent").visible, "volumeContent visible")
            verify(!findByName(item, "brightnessContent").visible, "brightness hidden for volume")
            compare(slider.value, 0.42)
            verify(slider.muted)
            verify(slider.showMute, "volume exposes mute control")
            // The master row is BarAudioLevelRow: one 38px card with the mute as
            // a glyph button, not a second settings row underneath the slider.
            compare(slider.height, 38)
            var volMuteBtn = findByName(slider, "levelRowMute")
            verify(volMuteBtn !== null, "volume mute button should exist")
            verify(volMuteBtn.visible, "volume mute button visible")
            compare(findByName(slider, "levelRowValue").text, "42%")
            // Trigger slider interaction via signal emission.
            fake.setCalls = 0
            fake.last = -1
            slider.valueCommitted(0.8)
            compare(fake.setCalls, 1)
            compare(fake.last, 0.8)
            fake.toggleCalls = 0
            volMuteBtn.toggle()
            compare(fake.toggleCalls, 1)
            // Brightness content hidden, media hidden etc.
            verify(!findByName(item, "mediaContent").visible)
        }

        function test_masterRowKeepsOneRowSystemWithTheLists() {
            // The reason the master row was rebuilt: it used to be two stacked
            // settings rows at 112px standing directly above 38px device rows, so
            // the top of the panel read at a different scale from everything under
            // it. One row system is the fix, so the heights are part of the
            // contract rather than an incidental measurement.
            var speaker = fakeDevice(56, "alsa_output.speaker_sink", "Laptop Speakers", 0.4, false, "sysA")
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0.5; property bool sinkMuted: false;'
                + ' property var sinks: []; property var sources: []; property var streams: [];'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted } }',
                root, "fakeVolRowSystem")
            fake.sinks = [speaker]
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume", payload: { volumeService: fake }
            })
            var master = findByName(item, "volumeSlider")
            var deviceList = findByName(item, "outputDeviceList")
            compare(master.height, deviceList.rowHeight,
                "master row and device rows must share one row height")

            // Every label in the panel starts on the same vertical line. This was
            // the other half of the mess: device rows began at 10px while the
            // master and mixer labels began at 26px.
            compare(findByName(item, "levelRowLabel").x, 26)
            compare(findByName(item, "audioDeviceName").x, 26)
        }

        function test_masterRowControlsDoNotOverlap() {
            // Laid out from both edges: the label column is fixed, the value and
            // mute are pinned right, and the slider fills between. Measuring the
            // boxes is the only way this stays true - a binding change that
            // widened the value text would silently stack them.
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0.5; property bool sinkMuted: false;'
                + ' property var sinks: []; property var sources: []; property var streams: [];'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted } }',
                root, "fakeVolMasterOverlap")
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume", payload: { volumeService: fake }
            })
            var master = findByName(item, "volumeSlider")
            var label = findByName(master, "levelRowLabel")
            var slider = findByName(master, "levelRowSlider")
            var value = findByName(master, "levelRowValue")
            var mute = findByName(master, "levelRowMute")
            verify(label.x + label.width <= slider.x + 0.5, "label must not reach the slider")
            verify(slider.x + slider.width <= value.x + 0.5, "slider must not reach the value")
            verify(value.x + value.width <= mute.x + 0.5, "value must not reach the mute button")
            verify(mute.x + mute.width <= master.width + 0.5, "mute button stays inside the card")
            verify(slider.width >= 60, "slider keeps a usable drag target")
        }

        function test_brightnessExposesSlider() {
            var fakeB = Qt.createQmlObject('import QtQuick; QtObject { property int setCalls: 0; property real last: -1; function setBrightness(v){ setCalls++; last=v } }', root, "fakeBright")
            var item = createTemporaryObject(actionsComp, root, { actionKind: "brightness", payload: { brightnessService: fakeB, brightness: 0.33 } })
            var slider = findByName(item, "brightnessSlider")
            verify(slider !== null, "brightnessSlider should exist")
            verify(slider.visible)
            verify(findByName(item, "brightnessContent").visible)
            verify(!findByName(item, "volumeContent").visible)
            compare(slider.value, 0.33)
            verify(!slider.showMute, "brightness hides mute control")
            var brightMuteBtn = findByName(slider, "sliderMuteButton")
            verify(brightMuteBtn !== null, "brightness mute button node exists")
            verify(!slider.muteRow.visible, "brightness mute button not visible")
            fakeB.setCalls = 0
            slider.valueCommitted(0.6)
            compare(fakeB.setCalls, 1)
            compare(fakeB.last, 0.6)
        }

        function test_mediaExposesPreviousPlayNext() {
            var fakeM = Qt.createQmlObject('import QtQuick; QtObject { property int prev:0; property int play:0; property int nextCount:0; property int positionMs:65000; property int lengthMs:180000; property real lastSeek:-1; function previous(){ prev++ } function playPause(){ play++ } function next(){ nextCount++ } function setProgress(v){ lastSeek=v } }', root, "fakeMedia")
            var item = createTemporaryObject(actionsComp, root, { actionKind: "media", payload: { mediaService: fakeM, title: "Song title", artist: "Artist name" } })
            var prevBtn = findByName(item, "mediaPrevButton")
            var playBtn = findByName(item, "mediaPlayPauseButton")
            var nextBtn = findByName(item, "mediaNextButton")
            verify(prevBtn !== null, "prev button should exist")
            verify(playBtn !== null, "play button should exist")
            verify(nextBtn !== null, "next button should exist")
            verify(findByName(item, "mediaContent").visible)
            // Left cover plus right identity column.
            verify(findByName(item, "mediaCoverFrame") !== null, "cover frame should exist")
            verify(findByName(item, "mediaCoverImage") !== null, "cover image should exist")
            var titleNode = findByName(item, "mediaTitleText")
            verify(titleNode !== null, "title text should exist")
            compare(titleNode.text, "Song title")
            var artistNode = findByName(item, "mediaArtistText")
            verify(artistNode !== null, "artist text should exist")
            compare(artistNode.text, "Artist name")
            var posText = findByName(item, "mediaPositionText")
            var lenText = findByName(item, "mediaLengthText")
            verify(posText !== null, "position text should exist")
            verify(lenText !== null, "length text should exist")
            compare(posText.text, "1:05")
            compare(lenText.text, "3:00")
            // Draggable progress bar and thumb.
            verify(findByName(item, "mediaSeekArea") !== null, "seek area should exist")
            verify(findByName(item, "mediaProgressTrack") !== null, "progress track should exist")
            verify(findByName(item, "mediaProgressFill") !== null, "progress fill should exist")
            verify(findByName(item, "mediaProgressThumb") !== null, "progress thumb should exist")
            verify(findByName(item, "mediaProgressTap") !== null, "progress tap should exist")
            fakeM.positionMs = 70000
            tryCompare(posText, "text", "1:10", 500)
            // Seek routes through the media service.
            fakeM.lastSeek = -1
            item.handleMediaSeek(0.5)
            compare(fakeM.lastSeek, 0.5)
            fakeM.prev = 0; fakeM.play = 0; fakeM.nextCount = 0
            mouseClick(prevBtn, prevBtn.width/2, prevBtn.height/2, Qt.LeftButton)
            tryCompare(fakeM, "prev", 1, 500)
            mouseClick(playBtn, playBtn.width/2, playBtn.height/2, Qt.LeftButton)
            tryCompare(fakeM, "play", 1, 500)
            mouseClick(nextBtn, nextBtn.width/2, nextBtn.height/2, Qt.LeftButton)
            tryCompare(fakeM, "nextCount", 1, 500)
        }

        function test_mediaSpectrumStaysResident() {
            var item = createTemporaryObject(actionsComp, root, { actionKind: "media", payload: { title: "T", spectrumValues: [0.2, 0.5, 0.8] } })
            var spectrum = findByName(item, "mediaSpectrum")
            verify(spectrum !== null, "spectrum should exist")
            verify(spectrum.visible, "spectrum visible with values")
            compare(spectrum.height, 40)
            // No audio: the strip keeps its slot instead of collapsing.
            var emptyItem = createTemporaryObject(actionsComp, root, { actionKind: "media", payload: { title: "T" } })
            var emptySpectrum = findByName(emptyItem, "mediaSpectrum")
            verify(emptySpectrum !== null)
            verify(emptySpectrum.visible, "spectrum stays resident without values")
            compare(emptySpectrum.height, 40)
        }

        function test_notificationsExposesDndAndClear() {
            var fakeN = Qt.createQmlObject('import QtQuick; QtObject { property bool dndEnabled:false; property int readCalls:0; function markAllRead(){ readCalls++ } }', root, "fakeNotif")
            // Use onToggleDnd callback variant to avoid mutating singleton.
            var toggleCalls = 0
            var clearCallsOuter = 0
            var payload = {
                dndEnabled: true,
                onToggleDnd: function(){ toggleCalls++ },
                onMarkAllRead: function(){ clearCallsOuter++ },
                notificationService: fakeN
            }
            var item = createTemporaryObject(actionsComp, root, { actionKind: "notifications", payload: payload })
            var dndBtn = findByName(item, "notificationDndButton")
            var clearBtn = findByName(item, "notificationClearButton")
            verify(dndBtn !== null, "DND button should exist")
            verify(clearBtn !== null, "Clear button should exist")
            verify(findByName(item, "notificationsContent").visible)
            verify(item.notificationDnd, "dndEnabled should reflect payload")
            mouseClick(dndBtn, dndBtn.width/2, dndBtn.height/2, Qt.LeftButton)
            wait(20)
            verify(toggleCalls === 1, "onToggleDnd should have been called")
            mouseClick(clearBtn, clearBtn.width/2, clearBtn.height/2, Qt.LeftButton)
            wait(20)
            verify(clearCallsOuter === 1, "onMarkAllRead should have been called")
            // Also test fake service fallback when the callback is not present.
            var item2 = createTemporaryObject(actionsComp, root, { actionKind: "notifications", payload: { notificationService: fakeN, dndEnabled: false } })
            fakeN.readCalls = 0
            var clearBtn2 = findByName(item2, "notificationClearButton")
            mouseClick(clearBtn2, clearBtn2.width/2, clearBtn2.height/2, Qt.LeftButton)
            tryCompare(fakeN, "readCalls", 1, 500)
        }

        function test_trayRendersNativeMenuRows() {
            var open = { text: "Open", enabled: true, triggeredCalls: 0, triggered: function() { this.triggeredCalls++ } }
            var item = createTemporaryObject(actionsComp, root, { actionKind: "tray" })
            var menu = findByName(item, "trayMenuRoot")
            verify(menu !== null)
            menu.useStubEntries = true
            menu.menuHandle = { id: "stub" }
            menu.entries = [open]
            verify(findByName(item, "trayContent").visible)
            verify(findByName(item, "trayActivateButton") === null)
            compare(menu.rowCount, 1)
        }

        function test_trayEmptyStateWithoutHandle() {
            var item = createTemporaryObject(actionsComp, root, { actionKind: "tray", payload: {} })
            verify(findByName(item, "trayEmptyState").visible)
        }

        function test_traySubmenuAnchorsToParentRow() {
            // Panel hangs from the anchor row inside the primary vertical
            // range; backgrounds keep covering the full tray content.
            Lazer.MotionTokens.reducedMotionOverride = true
            function primaryRowsOf(target) {
                var found = []
                var all = findAllByName(target, "trayMenuRow")
                for (var i = 0; i < all.length; i++) {
                    if (all[i].level === 1)
                        found.push(all[i])
                }
                return found
            }
            try {
                var submenu = []
                for (var i = 0; i < 20; i++)
                    submenu.push({ text: "Child " + i, enabled: true })
                var item = createTemporaryObject(actionsComp, root, { actionKind: "tray" })
                var menu = findByName(item, "trayMenuRoot")
                verify(menu !== null)
                menu.useStubEntries = true
                menu.menuHandle = { id: "stub" }
                var primaries = [{ text: "Top", enabled: true },
                    { text: "More", enabled: true, hasChildren: true }]
                for (var p = 0; p < 6; p++)
                    primaries.push({ text: " filler " + p, enabled: true })
                menu.entries = primaries
                var anchor = null
                var primaryHeight = 0
                var stableP = 0
                for (var i = 0; i < 400 && (anchor === null || stableP < 5); i++) {
                    wait(10)
                    var prows = primaryRowsOf(menu)
                    if (prows.length >= 8 && prows[1].y > 0)
                        anchor = prows[1]
                    var curP = findByName(menu, "trayMenuFlick").height
                    if (anchor !== null && curP > 0 && curP === primaryHeight)
                        stableP++
                    else {
                        stableP = 0
                        primaryHeight = curP
                    }
                }
                verify(anchor !== null)
                verify(primaryHeight > 0)
                var more = menu.entryModel[1]
                var anchorBottom = anchor.mapToItem(menu, 0, 32).y
                menu.submenuEntries = submenu
                menu.openSubmenu(more, anchor)
                // Pin wiring: title top meets the anchor bottom edge. Wait
                // for submenu layout first: settled content pins the clamp.
                var subSettled = false
                for (var s = 0; s < 200 && !subSettled; s++) {
                    wait(10)
                    var subProbe = findByName(menu, "traySubmenuFlick")
                    subSettled = subProbe && subProbe.contentHeight > subProbe.height
                        && subProbe.height > 0
                }
                verify(subSettled)
                // Panel starts title-height above the trigger row so its first
                // row lands on it, clamped to stay inside the primary flick.
                compare(menu.submenuAnchorBottomY, anchorBottom)
                verify(menu.submenuSurface.y >= 0, "panel escapes the top of the menu")
                verify(menu.submenuSurface.y + menu.submenuSurface.height
                    <= primaryHeight + 0.5, "panel escapes the bottom of the menu")
                compare(findByName(menu, "traySubmenuTitleBlock").y, 0)
                // Backgrounds still cover the full tray content behind it.
                var trayBody = findByName(item, "trayContent")
                var bg = findByName(item, "trayContentBackground")
                verify(bg !== null)
                compare(bg.height, trayBody.height + 16)
            } finally {
                Lazer.MotionTokens.reducedMotionOverride = false
            }
        }

        function test_volumeAndBrightnessFollowLiveService() {
            var fakeVol = Qt.createQmlObject('import QtQuick; QtObject { property real sinkVolume: 0.42; property bool sinkMuted: true; function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted } }', root, "fakeVolLive")
            var volumeItem = createTemporaryObject(actionsComp, root, {
                actionKind: "volume",
                payload: { volumeService: fakeVol, volume: 0.1, muted: false }
            })
            var volumeSlider = findByName(volumeItem, "volumeSlider")
            var levelSlider = findByName(volumeSlider, "levelRowSlider")
            compare(volumeItem.volumeValue, 0.42)
            compare(volumeSlider.value, 0.42)
            compare(levelSlider.value, 42)
            compare(findByName(volumeSlider, "levelRowValue").text, "42%")
            verify(volumeSlider.muted)
            fakeVol.sinkVolume = 0.77
            fakeVol.sinkMuted = false
            compare(volumeItem.volumeValue, 0.77)
            compare(volumeSlider.value, 0.77)
            compare(levelSlider.value, 77)
            verify(!volumeSlider.muted)

            var fakeBright = Qt.createQmlObject('import QtQuick; QtObject { property real brightness: 0.33; function setBrightness(v){ brightness=v } }', root, "fakeBrightLive")
            var brightnessItem = createTemporaryObject(actionsComp, root, {
                actionKind: "brightness",
                payload: { brightnessService: fakeBright, brightness: 0.1 }
            })
            var brightnessSlider = findByName(brightnessItem, "brightnessSlider")
            compare(brightnessItem.brightnessValue, 0.33)
            compare(brightnessSlider.value, 0.33)
            fakeBright.brightness = 0.91
            compare(brightnessItem.brightnessValue, 0.91)
            compare(brightnessSlider.value, 0.91)
            compare(brightnessSlider.sliderControl.value, 91)
        }

        function test_fakeInjectionDoesNotMutateRealServices() {
            // Create with null payload and verify no exception and no mutation path taken.
            var item = createTemporaryObject(actionsComp, root, { actionKind: "volume", payload: null })
            var slider = findByName(item, "volumeSlider")
            verify(slider !== null)
            // Calling handler with null payload must not throw and must not require real Pipewire.
            slider.valueCommitted(0.9)
            slider.toggleRequested()
            // The mixer seams must be inert with no service at all, rather than
            // throwing on a null payload.
            item.setStreamVolume(null, 0.5)
            item.toggleStreamMute(null)
            item.moveStreamToSink(null, null)
            item.handleAudioSink(null)
            item.handleAudioSource(null)
            verify(true, "no throw with null payload")
        }

        // --- Device pickers and application mixer ---

        // Fakes must be QObjects: a plain JS record is copied on assignment, so
        // identity comparisons inside the components would see a fresh object
        // every time and every assertion about persistence would fail for a
        // reason that is not the bug.
        function fakeDevice(id, name, description, volume, muted, suffix) {
            return Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property int id: ' + id + ';'
                + ' property string name: "' + name + '";'
                + ' property string description: "' + description + '";'
                + ' property QtObject audio: QtObject { property real volume: ' + volume
                + '; property bool muted: ' + (muted ? "true" : "false") + ' } }',
                root, "fakeDevice" + (suffix || id))
        }

        function fakeStream(id, appName, mediaName, volume, muted, suffix) {
            return Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property int id: ' + id + ';'
                + ' property string name: "' + appName + '";'
                + ' property var properties: ({ "application.name": "' + appName + '",'
                + ' "media.name": "' + mediaName + '", "media.class": "Stream/Output/Audio" });'
                + ' property QtObject audio: QtObject { property real volume: ' + volume
                + '; property bool muted: ' + (muted ? "true" : "false") + ' } }',
                root, "fakeStream" + (suffix || id))
        }

        function test_volumePanelExposesBothDeviceListsAndTheMixer() {
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0.5; property bool sinkMuted: false;'
                + ' property var sinks: []; property var sources: []; property var streams: [];'
                + ' property var defaultSinkNode: null; property var defaultSourceNode: null;'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted } }',
                root, "fakeVolDevices")
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume",
                payload: { volumeService: fake, volume: 0.5, muted: false }
            })
            verify(findByName(item, "outputDeviceList") !== null, "output device list exists")
            verify(findByName(item, "inputDeviceList") !== null, "input device list exists")
            verify(findByName(item, "audioMixer") !== null, "mixer exists")
            // Master slider survives the restructure.
            verify(findByName(item, "volumeSlider") !== null, "master slider still exists")
            // Empty service means empty lists, not a crash and not a stale copy.
            compare(item.audioSinks.length, 0)
            compare(item.audioSources.length, 0)
            compare(item.audioStreams.length, 0)
        }

        function test_mixerRowBoxesDoNotOverlap() {
            // The regression the panel screenshot exposed: the media name ran
            // 26..304, the slider 148..278 and the route chip 222..310 on one
            // 344px row, so the media name was painted under the slider and the
            // chip sat across its end. Both lines are now laid out from the edges
            // they belong to, so the boxes cannot intersect.
            var stream = fakeStream(112, "Firefox", "\u7f51\u6613\u4e91\u97f3\u4e50", 1, false, "grid")
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0.5; property bool sinkMuted: false;'
                + ' property var sinks: []; property var sources: []; property var streams: [];'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted }'
                + ' function streamAppName(s){ return s && s.properties ? s.properties["application.name"] : "" }'
                + ' function streamMediaName(s){ return s && s.properties ? s.properties["media.name"] : "" }'
                + ' function streamLevel(s){ return s && s.audio ? s.audio.volume : 0 }'
                + ' function streamMuted(s){ return !s || !s.audio ? true : s.audio.muted }'
                + ' function streamRouteLabel(s){ return "TimeEar BTE-9" } }',
                root, "fakeVolGrid")
            fake.streams = [stream]
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume", payload: { volumeService: fake }
            })
            var row = findByName(item, "mixerRow0")
            verify(row !== null)
            var appName = findByName(row, "mixerAppName")
            var media = findByName(row, "mixerMediaName")
            var mute = findByName(row, "mixerMuteButton")
            var slider = findByName(row, "mixerSlider0")
            var percent = findByName(row, "mixerLevelText")
            var chip = findByName(row, "mixerRouteChip")

            // Identity line: glyph, name, media, then the mute button.
            verify(appName.x + appName.width <= media.x + 0.5, "app name must not reach the media name")
            verify(media.x + media.width <= mute.x + 0.5, "media name must not reach the mute button")
            // Control line: slider, percentage, route chip.
            verify(slider.x + slider.width <= percent.x + 0.5, "slider must not reach the percentage")
            verify(percent.x + percent.width <= chip.x + 0.5, "percentage must not reach the route chip")
            verify(chip.x + chip.width <= row.width + 0.5, "route chip stays inside the card")
            verify(slider.width >= 60, "slider keeps a usable drag target")
            // The route belongs on the control line, next to the level it acts
            // on; on the identity line it read as a subtitle for the application.
            verify(chip.y > appName.y, "route chip sits on the control line")
        }

        function test_deviceRowsRenderAndSelectTheCurrentDevice() {
            var speaker = fakeDevice(56, "alsa_output.speaker_sink", "Laptop Speakers", 0.4, false, "spk")
            var headset = fakeDevice(73, "bluez_output.94", "TimeEar BTE-9", 0.26, false, "hs")
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0.5; property bool sinkMuted: false;'
                + ' property var sinks: [];'
                + ' property var streams: [];'
                + ' property var defaultSinkNode: null;'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted } }',
                root, "fakeVolSinkList")
            fake.sinks = [speaker, headset]
            fake.defaultSinkNode = headset
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume", payload: { volumeService: fake }
            })
            var list = findByName(item, "outputDeviceList")
            compare(list.devices.length, 2)
            compare(list.currentDevice, headset)
            var first = findByName(item, "audioDeviceRow0")
            var second = findByName(item, "audioDeviceRow1")
            verify(first !== null && second !== null, "both device rows render")
            // The description is the label, so the mixer chip and this list name
            // a device identically.
            compare(findByName(first, "audioDeviceName").text, "Laptop Speakers")
            compare(findByName(second, "audioDeviceName").text, "TimeEar BTE-9")
            // Selection is a left band + a brightness step, not an accent fill.
            compare(findByName(first, "audioDeviceSelectedBar").opacity, 0)
            compare(findByName(second, "audioDeviceSelectedBar").opacity, 1)
            compare(findByName(first, "audioDeviceLevel").text, "40%")
        }

        function test_mutedDeviceShowsTheWordNotALevel() {
            var mutedSink = fakeDevice(56, "alsa.sink", "Laptop Speakers", 0.4, true, "muted")
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0; property bool sinkMuted: true;'
                + ' property var sinks: []; property var sources: []; property var streams: [];'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted } }',
                root, "fakeVolMuted")
            fake.sinks = [mutedSink]
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume", payload: { volumeService: fake }
            })
            compare(findByName(item, "OutputDeviceListView").count, 1)
            compare(findByName(item, "audioDeviceLevel").text, "Muted")
        }

        function test_sharedHardwareNameIsHoistedOutOfTheRows() {
            // On a machine with several devices behind one card, every row used
            // to begin "Ryzen HD Audio Controller ...", which pushed the only
            // words that tell the rows apart - Speaker, Stereo Microphone,
            // Digital Microphone - off the end of every row. The shared run is
            // stated once in the header instead.
            var mic1 = fakeDevice(57, "alsa.mic1", "Ryzen HD Audio Controller Stereo Microphone", 1, false, "hoist1")
            var mic2 = fakeDevice(58, "alsa.mic2", "Ryzen HD Audio Controller Digital Microphone", 1, false, "hoist2")
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0.5; property bool sinkMuted: false;'
                + ' property var sinks: []; property var sources: []; property var streams: [];'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted } }',
                root, "fakeVolHoist")
            fake.sources = [mic1, mic2]
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume", payload: { volumeService: fake }
            })
            var list = findByName(item, "inputDeviceList")
            compare(list.sharedPrefix, "Ryzen HD Audio Controller")
            // Scoped to the input section: the output section comes first in the
            // tree and legitimately has no scope text, so an unscoped lookup would
            // read the wrong one.
            compare(findByName(list, "audioSectionScope").text, "Ryzen HD Audio Controller")
            var listView = findByName(item, "InputDeviceListView")
            compare(findByName(listView.itemAtIndex(0), "audioDeviceName").text, "Stereo Microphone")
            compare(findByName(listView.itemAtIndex(1), "audioDeviceName").text, "Digital Microphone")
        }

        function test_nothingIsHoistedWhenNamesShareNothing() {
            // Two unrelated devices must each keep their full name; hoisting a
            // prefix they do not share would invent a scope that is not there.
            var speaker = fakeDevice(56, "alsa.sp.sink", "Ryzen HD Audio Controller Speaker", 0.4, false, "noshare1")
            var headset = fakeDevice(73, "bt.sink", "TimeEar BTE-9", 0.33, false, "noshare2")
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0.5; property bool sinkMuted: false;'
                + ' property var sinks: []; property var sources: []; property var streams: [];'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted } }',
                root, "fakeVolNoHoist")
            fake.sinks = [speaker, headset]
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume", payload: { volumeService: fake }
            })
            compare(findByName(item, "outputDeviceList").sharedPrefix, "")
            var listView = findByName(item, "OutputDeviceListView")
            compare(findByName(listView.itemAtIndex(0), "audioDeviceName").text,
                "Ryzen HD Audio Controller Speaker")
            compare(findByName(listView.itemAtIndex(1), "audioDeviceName").text, "TimeEar BTE-9")
        }

        function test_mixerRowRendersAppMediaLevelAndRoute() {
            var stream = fakeStream(112, "Firefox", "Tune", 0.5, false, "ff")
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0.5; property bool sinkMuted: false;'
                + ' property var sinks: []; property var sources: []; property var streams: [];'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted }'
                + ' function streamAppName(s){ return s && s.properties ? s.properties["application.name"] : "" }'
                + ' function streamMediaName(s){ return s && s.properties ? s.properties["media.name"] : "" }'
                + ' function streamLevel(s){ return s && s.audio ? s.audio.volume : 0 }'
                + ' function streamMuted(s){ return !s || !s.audio ? true : s.audio.muted }'
                + ' function streamRouteLabel(s){ return "TimeEar BTE-9" }'
                + ' function setStreamVolume(s,v){ s.audio.volume = v }'
                + ' function toggleStreamMute(s){ s.audio.muted = !s.audio.muted } }',
                root, "fakeVolMixer")
            fake.streams = [stream]
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume", payload: { volumeService: fake }
            })
            verify(findByName(item, "mixerRow0") !== null, "mixer row renders")
            compare(findByName(item, "mixerAppName").text, "Firefox")
            compare(findByName(item, "mixerMediaName").text, "Tune")
            compare(findByName(item, "mixerLevelText").text, "50%")
            compare(findByName(item, "mixerRouteLabel").text, "TimeEar BTE-9")
            compare(findByName(item, "mixerSlider0").value, 50)
        }

        function test_mixerRowDrivesTheServiceForLevelAndMute() {
            var stream = fakeStream(112, "Firefox", "Tune", 0.5, false, "drive")
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0.5; property bool sinkMuted: false;'
                + ' property var sinks: []; property var sources: []; property var streams: [];'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted }'
                + ' function streamAppName(s){ return s && s.properties ? s.properties["application.name"] : "" }'
                + ' function streamMediaName(s){ return s && s.properties ? s.properties["media.name"] : "" }'
                + ' function streamLevel(s){ return s && s.audio ? s.audio.volume : 0 }'
                + ' function streamMuted(s){ return !s || !s.audio ? true : s.audio.muted }'
                + ' function streamRouteLabel(s){ return "TimeEar BTE-9" }'
                + ' function setStreamVolume(s,v){ s.audio.volume = v }'
                + ' function toggleStreamMute(s){ s.audio.muted = !s.audio.muted } }',
                root, "fakeVolMixerDrive")
            fake.streams = [stream]
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume", payload: { volumeService: fake }
            })
            findByName(item, "mixerSlider0").valueModified(30)
            compare(stream.audio.volume, 0.3)
            findByName(item, "mixerMuteButton").toggleMute()
            verify(stream.audio.muted, "mute reaches the service")
        }

        function test_routeChipStaysDisabledUntilTheRouteIsRead() {
            // An unread route must read as unavailable, not as the default
            // device - naming a device the panel cannot vouch for is the failure
            // this guards.
            var stream = fakeStream(112, "Firefox", "Tune", 0.5, false, "unread")
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0.5; property bool sinkMuted: false;'
                + ' property var sinks: []; property var sources: []; property var streams: [];'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted }'
                + ' function streamAppName(s){ return s && s.properties ? s.properties["application.name"] : "" }'
                + ' function streamMediaName(s){ return s && s.properties ? s.properties["media.name"] : "" }'
                + ' function streamLevel(s){ return s && s.audio ? s.audio.volume : 0 }'
                + ' function streamMuted(s){ return !s || !s.audio ? true : s.audio.muted }'
                + ' function streamRouteLabel(s){ return "" } }',
                root, "fakeVolUnread")
            fake.streams = [stream]
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume", payload: { volumeService: fake }
            })
            var chip = findByName(item, "mixerRouteChip")
            verify(!chip.enabled, "chip disabled while the route is unknown")
            compare(findByName(item, "mixerRouteLabel").text, "Reading…")
            var mixer = findByName(item, "audioMixer")
            compare(mixer.routeMode, false)
        }

        function test_routePickerListsSinksAndReportsTheMove() {
            var stream = fakeStream(112, "Firefox", "Tune", 0.5, false, "pick")
            var alsa = fakeDevice(56, "alsa_output.speaker_sink", "Laptop Speakers", 0.4, false, "pickSpk")
            var bluez = fakeDevice(73, "bluez_output.94", "TimeEar BTE-9", 0.26, false, "pickHs")
            var moved = []
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0.5; property bool sinkMuted: false;'
                + ' property var sinks: []; property var sources: []; property var streams: [];'
                + ' property var defaultSinkNode: null;'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted }'
                + ' function streamAppName(s){ return s && s.properties ? s.properties["application.name"] : "" }'
                + ' function streamMediaName(s){ return s && s.properties ? s.properties["media.name"] : "" }'
                + ' function streamLevel(s){ return s && s.audio ? s.audio.volume : 0 }'
                + ' function streamMuted(s){ return !s || !s.audio ? true : s.audio.muted }'
                + ' function streamRouteLabel(s){ return "TimeEar BTE-9" }'
                + ' function moveStreamToSink(s, d){ root._movedStream = s; root._movedSink = d } }',
                root, "fakeVolPick")
            fake.streams = [stream]
            fake.sinks = [alsa, bluez]
            fake.defaultSinkNode = bluez
            root._movedStream = null
            root._movedSink = null
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume", payload: { volumeService: fake }
            })
            var mixer = findByName(item, "audioMixer")
            verify(!mixer.routeMode, "starts in mixer mode")

            mixer.openRoutePicker(stream)
            verify(mixer.routeMode, "route chip opens the picker")
            compare(findByName(item, "mixerHeaderTitle").text, "Output for Firefox")
            compare(findByName(item, "mixerList").count, 2)

            findByName(item, "mixerSinkRow0").choose()
            compare(root._movedSink, alsa, "picking a sink asks the service to move the stream")
            compare(root._movedStream, stream)
            // Returning to the mixer either way: a refused move must not strand
            // the user in a list that did nothing.
            verify(!mixer.routeMode, "picker closes after a choice")
        }

        function test_routePickerAlsoClosesFromItsHeader() {
            var stream = fakeStream(112, "Firefox", "Tune", 0.5, false, "back")
            var bluez = fakeDevice(73, "bluez_output.94", "TimeEar BTE-9", 0.26, false, "backHs")
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0.5; property bool sinkMuted: false;'
                + ' property var sinks: []; property var sources: []; property var streams: [];'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted }'
                + ' function streamAppName(s){ return s && s.properties ? s.properties["application.name"] : "" }'
                + ' function streamMediaName(s){ return s && s.properties ? s.properties["media.name"] : "" }'
                + ' function streamLevel(s){ return s && s.audio ? s.audio.volume : 0 }'
                + ' function streamMuted(s){ return !s || !s.audio ? true : s.audio.muted }'
                + ' function streamRouteLabel(s){ return "TimeEar BTE-9" } }',
                root, "fakeVolBack")
            fake.streams = [stream]
            fake.sinks = [bluez]
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume", payload: { volumeService: fake }
            })
            var mixer = findByName(item, "audioMixer")
            mixer.openRoutePicker(stream)
            verify(mixer.routeMode)
            findByName(item, "mixerHeader").goBack()
            verify(!mixer.routeMode, "header is the way back out of the picker")
        }

        function test_deviceActivationGoesThroughTheServiceSeam() {
            var alsa = fakeDevice(56, "alsa_output.speaker_sink", "Laptop Speakers", 0.4, false, "actSpk")
            var pickedSink = null
            var pickedSource = null
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0.5; property bool sinkMuted: false;'
                + ' property var sinks: []; property var sources: []; property var streams: [];'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted }'
                + ' function setAudioSink(d){ root._pickedSink = d }'
                + ' function setAudioSource(d){ root._pickedSource = d } }',
                root, "fakeVolActivate")
            fake.sinks = [alsa]
            root._pickedSink = null
            root._pickedSource = null
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume", payload: { volumeService: fake }
            })
            item.handleAudioSink(alsa)
            compare(root._pickedSink, alsa)
            item.handleAudioSource(alsa)
            compare(root._pickedSource, alsa)
        }

        function test_routePollingFollowsTheOpenKindAndStops() {
            // pactl is only worth spawning while the mixer is on screen, and the
            // singleton outlives every popup - so the panel owns the poll's life.
            var fake = Qt.createQmlObject('import QtQuick; QtObject {'
                + ' property real sinkVolume: 0.5; property bool sinkMuted: false;'
                + ' property var sinks: []; property var sources: []; property var streams: [];'
                + ' property bool polling: false;'
                + ' function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted }'
                + ' function setRoutePolling(on){ polling = on } }',
                root, "fakeVolPoll")
            var item = createTemporaryObject(actionsComp, root, {
                actionKind: "volume", payload: { volumeService: fake }
            })
            verify(fake.polling, "opening the volume kind starts the route poll")
            item.actionKind = "network"
            verify(!fake.polling, "leaving the volume kind stops it")
            item.actionKind = "volume"
            verify(fake.polling, "returning restarts it")
            // The host calls this on close, where the body's own `visible` never
            // changes - without it pactl would poll for the life of the shell.
            item.visible = false
            verify(!fake.polling, "hiding the body stops it too")
        }

        // Dummy for tryCompare helper.
        property int dummy: 0
    }
}
