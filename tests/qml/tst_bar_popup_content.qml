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
            var volMuteBtn = findByName(slider, "sliderMuteButton")
            verify(volMuteBtn !== null, "volume mute button should exist")
            verify(slider.muteRow.visible, "volume mute button visible")
            // Trigger slider interaction via signal emission.
            fake.setCalls = 0
            fake.last = -1
            slider.valueCommitted(0.8)
            compare(fake.setCalls, 1)
            compare(fake.last, 0.8)
            fake.toggleCalls = 0
            slider.toggleRequested()
            compare(fake.toggleCalls, 1)
            // Brightness content hidden, media hidden etc.
            verify(!findByName(item, "mediaContent").visible)
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
            compare(spectrum.height, 36)
            // No audio: the strip keeps its slot instead of collapsing.
            var emptyItem = createTemporaryObject(actionsComp, root, { actionKind: "media", payload: { title: "T" } })
            var emptySpectrum = findByName(emptyItem, "mediaSpectrum")
            verify(emptySpectrum !== null)
            verify(emptySpectrum.visible, "spectrum stays resident without values")
            compare(emptySpectrum.height, 36)
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

        function test_volumeAndBrightnessFollowLiveService() {
            var fakeVol = Qt.createQmlObject('import QtQuick; QtObject { property real sinkVolume: 0.42; property bool sinkMuted: true; function setSinkVolume(v){ sinkVolume=v } function toggleSinkMute(){ sinkMuted=!sinkMuted } }', root, "fakeVolLive")
            var volumeItem = createTemporaryObject(actionsComp, root, {
                actionKind: "volume",
                payload: { volumeService: fakeVol, volume: 0.1, muted: false }
            })
            var volumeSlider = findByName(volumeItem, "volumeSlider")
            compare(volumeItem.volumeValue, 0.42)
            compare(volumeSlider.value, 0.42)
            compare(volumeSlider.sliderControl.value, 42)
            verify(volumeSlider.muted)
            fakeVol.sinkVolume = 0.77
            fakeVol.sinkMuted = false
            compare(volumeItem.volumeValue, 0.77)
            compare(volumeSlider.value, 0.77)
            compare(volumeSlider.sliderControl.value, 77)
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
            verify(true, "no throw with null payload")
        }

        // Dummy for tryCompare helper.
        property int dummy: 0
    }
}
