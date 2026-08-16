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

        function test_layerStartAndInterpolation() {
            compare(SettingsLogic.sidebarStartX(), -170)
            compare(SettingsLogic.contentStartX(570), -570)
            compare(SettingsLogic.contentStartX(-20), 0)
            compare(SettingsLogic.contentStartX(NaN), -570)
            compare(SettingsLogic.interpolate(-570, 170, 0), -570)
            compare(SettingsLogic.interpolate(-570, 170, 1), 170)
            compare(SettingsLogic.interpolate(-570, 170, 0.5), -200)
            compare(SettingsLogic.interpolate(-170, 0, 0.25), -127.5)
            compare(SettingsLogic.interpolate(-170, 0, 2), 0)
            compare(SettingsLogic.interpolate(-170, 0, -1), -170)
            compare(SettingsLogic.interpolate(NaN, 0, 0.5), 0)
            compare(SettingsLogic.interpolate(0, NaN, 0.5), 0)
            compare(SettingsLogic.interpolate(-170, 0, NaN), -170)
        }

        function test_settingsConversions() {
            compare(SettingsLogic.timeoutSecondsToMs(1), 2000)
            compare(SettingsLogic.timeoutSecondsToMs(20), 15000)
            compare(SettingsLogic.categoryDirection(2, 0), -1)
        }

        function test_valuesEqual() {
            verify(SettingsLogic.valuesEqual(0.1 + 0.2, 0.3))
            verify(SettingsLogic.valuesEqual(5, 5))
            verify(!SettingsLogic.valuesEqual(5, 6))
            verify(SettingsLogic.valuesEqual("auto", "auto"))
            verify(!SettingsLogic.valuesEqual("auto", "dark"))
            verify(!SettingsLogic.valuesEqual(null, "auto"))
            verify(SettingsLogic.valuesEqual(true, true))
            verify(!SettingsLogic.valuesEqual(true, false))
        }

        function test_sliderFractionAndMapping() {
            compare(SettingsLogic.sliderFraction(0, 10, 5), 0.5)
            compare(SettingsLogic.sliderFraction(10, 0, 5), 0.5)
            compare(SettingsLogic.sliderFraction(0, 10, 20), 1)
            compare(SettingsLogic.sliderFraction(0, 10, -5), 0)
            compare(SettingsLogic.sliderFraction(0, 10, NaN), 0)
            compare(SettingsLogic.sliderFraction(4, 4, 4), 0)
            compare(SettingsLogic.sliderValueFromFraction(0, 10, 0.5, 1), 5)
            compare(SettingsLogic.sliderValueFromFraction(10, 0, 0.5, 1), 5)
            compare(SettingsLogic.sliderValueFromFraction(0, 10, 0.5, 3), 6)
            compare(SettingsLogic.sliderValueFromFraction(0, 10, 0.5, 0), 5)
            compare(SettingsLogic.sliderValueFromFraction(0, 10, 2, 1), 10)
            compare(SettingsLogic.sliderValueFromFraction(4, 4, 0.5, 1), 4)
            compare(SettingsLogic.sliderFractionForPosition(50, 100, 25), 0.5)
            compare(SettingsLogic.sliderFractionForPosition(0, 100, 25), 0)
            compare(SettingsLogic.sliderFractionForPosition(100, 100, 25), 1)
            compare(SettingsLogic.sliderFractionForPosition(50, 0, 25), 0)
            compare(SettingsLogic.sliderFractionForPosition(50, 100, NaN), 0)
        }

        function test_dropdownPlacement() {
            // Fits below -> place below at the header bottom, full height.
            var p = SettingsLogic.dropdownPlacement(100, 140, 60, 0, 400, 200)
            compare(p.y, 140)
            compare(p.above, false)
            compare(p.height, 60)
            // Requested height is capped, and the capped menu still fits below.
            p = SettingsLogic.dropdownPlacement(100, 140, 300, 0, 400, 200)
            compare(p.y, 140)
            compare(p.above, false)
            compare(p.height, 200)
            // Not enough room below, but above fits -> place above at full height.
            p = SettingsLogic.dropdownPlacement(100, 140, 60, 0, 160, 200)
            compare(p.y, 40)
            compare(p.above, true)
            compare(p.height, 60)
            // Plenty of room below even when the header sits near the top.
            p = SettingsLogic.dropdownPlacement(10, 50, 60, 0, 400, 200)
            compare(p.y, 50)
            compare(p.above, false)
            compare(p.height, 60)
            // Neither side fits -> clamp to the side with more space.
            p = SettingsLogic.dropdownPlacement(30, 70, 100, 0, 100, 200)
            compare(p.y, 0)
            compare(p.above, true)
            compare(p.height, 30)
            p = SettingsLogic.dropdownPlacement(10, 40, 100, 0, 100, 200)
            compare(p.y, 40)
            compare(p.above, false)
            compare(p.height, 60)
            // Invalid header input -> empty menu.
            p = SettingsLogic.dropdownPlacement(NaN, 140, 60, 0, 400, 200)
            compare(p.y, 0)
            compare(p.height, 0)
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

        function test_tooltipMeasurementConstraints() {
            // Short text keeps its natural width plus padding.
            compare(SettingsLogic.tooltipSurfaceWidth(53, 320, 368, 6, 24), 65)
            // The 24px minimum only guards empty text; short text is not stretched.
            compare(SettingsLogic.tooltipSurfaceWidth(10, 320, 368, 6, 24), 22)
            compare(SettingsLogic.tooltipSurfaceWidth(0, 320, 368, 6, 24), 24)
            // Theme maximum width caps the surface.
            compare(SettingsLogic.tooltipSurfaceWidth(600, 320, 368, 6, 24), 320)
            // Available content width caps it harder than the theme maximum.
            compare(SettingsLogic.tooltipSurfaceWidth(600, 320, 200, 6, 24), 200)
            compare(SettingsLogic.tooltipSurfaceWidth(600, 320, 100, 6, 24), 100)
            // Invalid inputs fall back to safe defaults.
            compare(SettingsLogic.tooltipSurfaceWidth(NaN, 320, 368, 6, 24), 24)
            compare(SettingsLogic.tooltipSurfaceWidth(53, NaN, 368, 6, 24), 65)
            compare(SettingsLogic.tooltipSurfaceWidth(53, 320, -20, 6, 24), 12)
            // Available surface width subtracts safe margins and padding.
            compare(SettingsLogic.tooltipAvailableSurfaceWidth(400, 10, 6), 368)
            compare(SettingsLogic.tooltipAvailableSurfaceWidth(100, 10, 6), 68)
            compare(SettingsLogic.tooltipAvailableSurfaceWidth(100, 60, 6), 0)
            compare(SettingsLogic.tooltipAvailableSurfaceWidth(-20, 10, 6), 0)
            compare(SettingsLogic.tooltipAvailableSurfaceWidth(400, NaN, 6), 388)
            compare(SettingsLogic.tooltipAvailableSurfaceWidth(400, 10, NaN), 380)
        }

        function test_rectsIntersect() {
            verify(SettingsLogic.rectsIntersect({ x: 0, y: 0, width: 10, height: 10 }, { x: 5, y: 5, width: 10, height: 10 }))
            verify(SettingsLogic.rectsIntersect({ x: 0, y: 0, width: 10, height: 10 }, { x: 9, y: 9, width: 10, height: 10 }))
            // Corner contact alone is not an intersection (zero area overlap).
            verify(!SettingsLogic.rectsIntersect({ x: 0, y: 0, width: 10, height: 10 }, { x: 10, y: 10, width: 10, height: 10 }))
            // Touching an edge is not an intersection (source fully left).
            verify(!SettingsLogic.rectsIntersect({ x: 0, y: 0, width: 10, height: 10 }, { x: 20, y: 0, width: 10, height: 10 }))
            verify(!SettingsLogic.rectsIntersect({ x: 0, y: 0, width: 10, height: 10 }, { x: 0, y: 20, width: 10, height: 10 }))
            // Zero-size and invalid rects never intersect.
            verify(!SettingsLogic.rectsIntersect({ x: 0, y: 0, width: 0, height: 10 }, { x: 0, y: 0, width: 10, height: 10 }))
            verify(!SettingsLogic.rectsIntersect({ x: 0, y: 0, width: 10, height: 0 }, { x: 0, y: 0, width: 10, height: 10 }))
            verify(!SettingsLogic.rectsIntersect(null, { x: 0, y: 0, width: 10, height: 10 }))
            verify(!SettingsLogic.rectsIntersect({ x: NaN, y: 0, width: 10, height: 10 }, { x: 0, y: 0, width: 10, height: 10 }))
            // Partial visibility is still an intersection.
            verify(SettingsLogic.rectsIntersect({ x: -5, y: 0, width: 10, height: 10 }, { x: 0, y: 0, width: 10, height: 10 }))
            verify(SettingsLogic.rectsIntersect({ x: 0, y: -5, width: 10, height: 10 }, { x: 0, y: 0, width: 10, height: 10 }))
        }

        function test_tooltipPlacementAboveAndBelow() {
            var p
            // Plenty of room above -> above, centered on the source.
            p = SettingsLogic.tooltipPlacement({ x: 100, y: 200, width: 100, height: 20 }, 100, 30, { x: 10, y: 10, width: 380, height: 500 }, 6)
            compare(p.side, "above")
            compare(p.y, 164)
            compare(p.x, 100)
            // Source near the top -> below.
            p = SettingsLogic.tooltipPlacement({ x: 100, y: 40, width: 100, height: 20 }, 100, 30, { x: 10, y: 10, width: 380, height: 500 }, 6)
            compare(p.side, "below")
            compare(p.y, 66)
            compare(p.x, 100)
            // Exactly enough space above is still above.
            p = SettingsLogic.tooltipPlacement({ x: 100, y: 46, width: 100, height: 20 }, 100, 30, { x: 10, y: 10, width: 380, height: 500 }, 6)
            compare(p.side, "above")
            compare(p.y, 10)
            // No gap -> zero gap placement still respects the boundary.
            p = SettingsLogic.tooltipPlacement({ x: 100, y: 20, width: 100, height: 20 }, 100, 30, { x: 10, y: 10, width: 380, height: 500 }, 0)
            compare(p.side, "below")
            compare(p.y, 40)
        }

        function test_tooltipPlacementClampsAndSideSelection() {
            var p
            // Wide tooltip on a left-edge source clamps to the safe margin.
            p = SettingsLogic.tooltipPlacement({ x: 0, y: 200, width: 100, height: 20 }, 300, 30, { x: 10, y: 10, width: 380, height: 500 }, 6)
            compare(p.x, 10)
            compare(p.side, "above")
            // Wide tooltip on a right-edge source clamps left.
            p = SettingsLogic.tooltipPlacement({ x: 390, y: 200, width: 100, height: 20 }, 300, 30, { x: 10, y: 10, width: 380, height: 500 }, 6)
            compare(p.x, 90)
            // Neither side fits -> the side with more space wins, y clamps.
            p = SettingsLogic.tooltipPlacement({ x: 100, y: 120, width: 100, height: 20 }, 100, 300, { x: 10, y: 10, width: 380, height: 200 }, 6)
            // aboveSpace = 110, belowSpace = 200 - 140 = 60 -> above wins.
            compare(p.side, "above")
            compare(p.y, 10)
            // Below has more space.
            p = SettingsLogic.tooltipPlacement({ x: 100, y: 30, width: 100, height: 20 }, 100, 300, { x: 10, y: 10, width: 380, height: 160 }, 6)
            // aboveSpace = 20, belowSpace = 160 - 50 = 110 -> below wins.
            compare(p.side, "below")
            compare(p.y, 10)
            // Tooltip taller than the bounds stays inside the bounds top.
            p = SettingsLogic.tooltipPlacement({ x: 100, y: 200, width: 100, height: 20 }, 100, 600, { x: 10, y: 10, width: 380, height: 300 }, 6)
            compare(p.y, 10)
            // Invalid source input -> safe fallback.
            p = SettingsLogic.tooltipPlacement({ x: NaN, y: 0, width: 10, height: 10 }, 100, 30, { x: 0, y: 0, width: 100, height: 100 }, 6)
            compare(p.side, "below")
            compare(p.x, 0)
            compare(p.y, 0)
        }

        function test_tooltipMeasurementUsesSurfacePaddingAndViewportWidth() {
            // The available value is the surface cap after both safe margins
            // and both text paddings have been reserved.
            compare(SettingsLogic.tooltipAvailableSurfaceWidth(240, 10, 6), 208)
            // A natural width equal to the text cap fills, but never exceeds,
            // the viewport-safe surface width.
            compare(SettingsLogic.tooltipSurfaceWidth(500, 320, 208, 6, 24), 208)
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
            compare(Lazer.LazerTheme.settingsAccent, "#765bff")
            compare(Lazer.LazerTheme.settingsControlSurface, "#25222e")
            compare(Lazer.LazerTheme.settingsPanel, "#18161d")
            compare(Lazer.LazerTheme.settingsPanelBorder, "#00000000")
            compare(Lazer.LazerTheme.settingsRail, "#131217")
            compare(Lazer.LazerTheme.settingsNavInactive, "#8a8795")
            compare(Lazer.LazerTheme.settingsRow, "#00000000")
            compare(Lazer.LazerTheme.settingsRowHover, "#363842")
            compare(Lazer.LazerTheme.settingsSelected, "#40765bff")
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
