import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../modules/lazerbar/LazerSettingsLogic.js" as SettingsLogic

// Verify settings overlay state, geometry, and normalization helpers.
Item {
    TestCase {
        name: "LazerSettingsLogic"

        function test_panelGeometry() {
            compare(SettingsLogic.panelWidth(0), 0)
            compare(SettingsLogic.panelWidth(16), 16)
            compare(SettingsLogic.panelWidth(240), 240)
            compare(SettingsLogic.panelWidth(319), 319)
            compare(SettingsLogic.panelWidth(320), 320)
            compare(SettingsLogic.panelWidth(351), 320)
            compare(SettingsLogic.panelWidth(352), 320)
            compare(SettingsLogic.panelWidth(791), 759)
            compare(SettingsLogic.panelWidth(792), 760)
            compare(SettingsLogic.panelHeight(0), 0)
            compare(SettingsLogic.panelHeight(16), 16)
            compare(SettingsLogic.panelHeight(240), 240)
            compare(SettingsLogic.panelHeight(319), 319)
            compare(SettingsLogic.panelHeight(320), 320)
            compare(SettingsLogic.panelHeight(351), 320)
            compare(SettingsLogic.panelHeight(352), 320)
            compare(SettingsLogic.panelHeight(551), 519)
            compare(SettingsLogic.panelHeight(552), 520)
            compare(SettingsLogic.panelHeight(791), 617)
            compare(SettingsLogic.panelHeight(792), 618)
            compare(SettingsLogic.panelWidth(1920), 1040)
            compare(SettingsLogic.panelWidth(900), 760)
            compare(SettingsLogic.panelWidth(600), 568)
            compare(SettingsLogic.panelHeight(1080), 760)
            compare(SettingsLogic.panelHeight(540), 508)
            compare(SettingsLogic.navigationWidth(759), 168)
            compare(SettingsLogic.navigationWidth(760), 216)
        }

        function test_sidePanelWidth() {
            compare(SettingsLogic.sidePanelWidth(1920), 570)
            compare(SettingsLogic.sidePanelWidth(900), 570)
            compare(SettingsLogic.sidePanelWidth(500), 500)
            compare(SettingsLogic.sidePanelWidth(-20), 0)
            compare(SettingsLogic.sidebarWidth(true, 1920), 170)
            compare(SettingsLogic.sidebarWidth(false, 1920), 70)
            compare(SettingsLogic.sidebarWidth(true, 120), 120)
            compare(SettingsLogic.contentWidth(570, 170), 400)
            compare(SettingsLogic.contentWidth(470, 70), 400)
            compare(SettingsLogic.contentWidth(320, 70), 250)
            compare(SettingsLogic.contentWidth(-20, 70), 0)
        }

        function test_searchNormalizationAndMatching() {
            compare(SettingsLogic.normalizeSearchQuery("  PANEL  "), "panel")
            compare(SettingsLogic.normalizeSearchQuery(null), "")
            verify(SettingsLogic.matchesSearch("Panel opacity", "Range 0 to 1", "PANEL"))
            verify(SettingsLogic.matchesSearch("Blur", "Background effect", "effect"))
            verify(SettingsLogic.matchesSearch("Blur", "", ""))
            verify(!SettingsLogic.matchesSearch("Blur", "Background effect", "audio"))
        }

        function test_settingsConversions() {
            compare(SettingsLogic.timeoutSecondsToMs(1), 2000)
            compare(SettingsLogic.timeoutSecondsToMs(20), 15000)
            compare(SettingsLogic.categoryDirection(2, 0), -1)
        }

        function test_notificationAnchors() {
            var anchors = SettingsLogic.notificationAnchors("top-left")
            compare(anchors.top, true)
            compare(anchors.bottom, false)
            compare(anchors.left, true)
            compare(anchors.right, false)

            anchors = SettingsLogic.notificationAnchors("top-right")
            compare(anchors.top, true)
            compare(anchors.bottom, false)
            compare(anchors.left, false)
            compare(anchors.right, true)

            anchors = SettingsLogic.notificationAnchors("bottom-left")
            compare(anchors.top, false)
            compare(anchors.bottom, true)
            compare(anchors.left, true)
            compare(anchors.right, false)

            anchors = SettingsLogic.notificationAnchors("bottom-right")
            compare(anchors.top, false)
            compare(anchors.bottom, true)
            compare(anchors.left, false)
            compare(anchors.right, true)

            anchors = SettingsLogic.notificationAnchors("unknown")
            compare(anchors.top, true)
            compare(anchors.bottom, false)
            compare(anchors.left, false)
            compare(anchors.right, true)

            anchors = SettingsLogic.notificationAnchors(null)
            compare(anchors.top, true)
            compare(anchors.bottom, false)
            compare(anchors.left, false)
            compare(anchors.right, true)
        }

        function test_clampAndInvalidValues() {
            compare(SettingsLogic.clamp(12, 0, 10), 10)
            compare(SettingsLogic.clamp(-2, 0, 10), 0)
            compare(SettingsLogic.clamp(4, 10, 0), 4)
            compare(SettingsLogic.clamp(NaN, 0, 10), 0)
            compare(SettingsLogic.clamp(Infinity, 0, 10), 0)
            compare(SettingsLogic.panelWidth(NaN), 0)
            compare(SettingsLogic.panelWidth(Infinity), 0)
            compare(SettingsLogic.panelWidth("invalid"), 0)
            compare(SettingsLogic.panelHeight(NaN), 0)
            compare(SettingsLogic.panelHeight(Infinity), 0)
            compare(SettingsLogic.panelHeight("invalid"), 0)
            compare(SettingsLogic.navigationWidth(NaN), 168)
            compare(SettingsLogic.categoryDirection(NaN, 1), 0)
            compare(SettingsLogic.categoryDirection(1, Infinity), 0)
            compare(SettingsLogic.timeoutSecondsToMs(NaN), 2000)
            compare(SettingsLogic.timeoutSecondsToMs(Infinity), 2000)
        }

        function test_themeTokens() {
            compare(Lazer.LazerTheme.settingsPanel, "#ee24252d")
            compare(Lazer.LazerTheme.settingsPanelBorder, "#00000000")
            compare(Lazer.LazerTheme.settingsRail, "#1b1c22")
            compare(Lazer.LazerTheme.settingsRow, "#292a33")
            compare(Lazer.LazerTheme.settingsRowHover, "#363842")
            compare(Lazer.LazerTheme.settingsSelected, "#40eb1c60")
            compare(Lazer.LazerTheme.settingsScrimOpacity, 0.6)
            compare(Lazer.LazerTheme.settingsRadius, 16)
        }

        function test_motionTokens() {
            compare(Lazer.MotionTokens.settingsEnter, 320)
            compare(Lazer.MotionTokens.settingsExit, 240)
            compare(Lazer.MotionTokens.settingsScrim, 180)
            compare(Lazer.MotionTokens.settingsCategory, 160)
            compare(Lazer.MotionTokens.settingsSlide, 600)
            compare(Lazer.MotionTokens.settingsContentDelay, 200)
            compare(Lazer.MotionTokens.settingsSidebarFade, 500)
            compare(Lazer.MotionTokens.settingsSidebarStagger, 40)
            compare(Lazer.MotionTokens.settingsSidebarCollapse, 300)
        }
    }
}
