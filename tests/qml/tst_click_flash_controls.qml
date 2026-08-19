import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer

// Exercise the shared click-flash contract across settings and common controls.
Item {
    width: 720
    height: 520

    QtObject { id: state; property int count: 0 }

    Lazer.LazerSettingsToggle { id: toggle }
    Lazer.LazerSettingsChoice {
        id: choice
        model: [
            { value: "auto", label: "自动" },
            { value: "dark", label: "深色模式" }
        ]
        currentValue: "auto"
    }
    Lazer.LazerSettingsRow {
        id: resetRow
        width: 320
        height: 50
        defaultValue: 1
        currentValue: 2
        resetCallback: function() { state.count++ }
        Lazer.LazerSettingsToggle {}
    }
    Lazer.IconButton { id: iconButton; source: "../../modules/lazerbar/icons/settings.svg" }
    Lazer.MusicControlButton { id: musicButton; iconSource: "../../modules/lazerbar/icons/play.svg" }
    Lazer.MenuItem { id: menuItem; label: "Action" }

    TestCase {
        name: "ClickFlashControls"

        function resetAnimation(animation, overlay) {
            animation.stop()
            overlay.opacity = 0
        }

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            toggle.enabled = true
            choice.enabled = true
            choice.closeMenu()
            resetRow.enabled = true
            iconButton.enabled = true
            musicButton.enabled = true
            menuItem.enabled = true
            resetAnimation(toggle.flashAnimationItem, toggle.flashOverlayItem)
            resetAnimation(choice.flashAnimationItem, choice.flashOverlayItem)
            resetAnimation(resetRow.flashAnimationItem, resetRow.flashOverlayItem)
            resetAnimation(iconButton.flashAnimationItem, iconButton.flashOverlayItem)
            resetAnimation(musicButton.flashAnimationItem, musicButton.flashOverlayItem)
            resetAnimation(menuItem.flashAnimationItem, menuItem.flashOverlayItem)
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
        }

        function test_sharedTokens() {
            compare(Lazer.MotionTokens.clickFlashOpacity, 0.3)
            compare(Lazer.MotionTokens.clickFlashDuration, 800)
            compare(Lazer.MotionTokens.clickFlashEasing, Easing.OutQuint)
        }

        function test_settingsControlsFlashAfterAcceptedAction() {
            toggle.activate()
            verify(toggle.flashActive)
            compare(toggle.flashOverlayItem.enabled, false)
            compare(toggle.flashAnimationItem.duration, Lazer.MotionTokens.clickFlashDuration)

            choice.openMenu()
            verify(choice.flashActive)
            choice.flashAnimationItem.stop()
            choice.flashOverlayItem.opacity = 0
            choice.selectValue("dark")
            verify(choice.flashActive)

            resetRow.activateReset()
            verify(resetRow.flashActive)
            compare(state.count, 1)
        }

        function test_commonControlsFlashAfterAcceptedAction() {
            iconButton.activate()
            verify(iconButton.flashActive)
            musicButton.activate()
            verify(musicButton.flashActive)
            menuItem.activate()
            verify(menuItem.flashActive)
        }

        function test_disabledActionsDoNotFlash() {
            toggle.enabled = false
            choice.enabled = false
            resetRow.enabled = false
            iconButton.enabled = false
            musicButton.enabled = false
            menuItem.enabled = false

            toggle.activate()
            choice.openMenu()
            resetRow.activateReset()
            iconButton.activate()
            musicButton.activate()
            menuItem.activate()

            compare(toggle.flashActive, false)
            compare(choice.flashActive, false)
            compare(resetRow.flashActive, false)
            compare(iconButton.flashActive, false)
            compare(musicButton.flashActive, false)
            compare(menuItem.flashActive, false)
            compare(state.count, 0)
        }

        function test_reducedMotionStopsAndHidesFlash() {
            iconButton.activate()
            verify(iconButton.flashActive)
            Lazer.MotionTokens.reducedMotionOverride = true
            compare(iconButton.flashActive, false)
            compare(iconButton.flashOverlayItem.opacity, 0)
            compare(iconButton.flashAnimationItem.running, false)

            toggle.activate()
            compare(toggle.flashActive, false)
            compare(toggle.flashOverlayItem.opacity, 0)
        }
    }
}
