import QtQuick
import QtTest
import "../../services/LauncherLogic.js" as Logic
import "../../services/launcher/LauncherCategories.js" as Categories

// Lock the category taxonomy: how one desktop entry or clipboard entry is
// bucketed, how the chip bar is ordered and counted, and how the lens
// narrows a pooled result set on top of the text filter.
Item {
    id: testRoot
    width: 400
    height: 300

    // --- fixtures ---

    function entry(categories) {
        return { id: "app.desktop", name: "App", comment: "", categories: categories }
    }

    function clipRow(preview, extra) {
        var row = { preview: preview == null ? "" : String(preview), mime: "text/plain" }
        if (extra)
            for (var key in extra)
                row[key] = extra[key]
        return row
    }

    function item(id, name, category) {
        return {
            id: id,
            displayName: name,
            description: "",
            searchText: (name + " " + category).toLowerCase(),
            category: category
        }
    }

    TestCase {
        name: "LauncherCategories"
        when: windowShown

        // --- application categories ---

        function test_appCategory_primaryFreedesktopBuckets() {
            compare(Categories.appCategoryOf(entry(["Game"])), "games")
            compare(Categories.appCategoryOf(entry(["Development", "IDE"])), "dev")
            compare(Categories.appCategoryOf(entry(["Network", "WebBrowser"])), "network")
            compare(Categories.appCategoryOf(entry(["AudioVideo", "Player"])), "media")
            compare(Categories.appCategoryOf(entry(["Graphics"])), "graphics")
            compare(Categories.appCategoryOf(entry(["Office", "Spreadsheet"])), "office")
            compare(Categories.appCategoryOf(entry(["System", "Filesystem"])), "system")
            compare(Categories.appCategoryOf(entry(["Utility"])), "utility")
        }

        function test_appCategory_familyPrefixesAndTerminals() {
            // Sub-category families resolve through their shared prefix.
            compare(Categories.appCategoryOf(entry(["ActionGame"])), "games")
            compare(Categories.appCategoryOf(entry(["VideoConference"])), "network")
            compare(Categories.appCategoryOf(entry(["AudioVideoEditing"])), "media")
            compare(Categories.appCategoryOf(entry(["TerminalEmulator"])), "dev")
        }

        function test_appCategory_bucketPrecedenceBeatsDeclarationOrder() {
            // Game must win over Utility regardless of how the entry orders
            // them, and a plain keyword inside another category must not
            // hijack the bucket ("video" is not "ide").
            compare(Categories.appCategoryOf(entry(["Game", "Utility"])), "games")
            compare(Categories.appCategoryOf(entry(["Utility", "Development"])), "dev")
            compare(Categories.appCategoryOf(entry(["Video"])), "media")
        }

        function test_appCategory_fallsBackToOther() {
            compare(Categories.appCategoryOf(entry([])), "other")
            compare(Categories.appCategoryOf(entry(["TotallyMadeUpCategory"])), "other")
            compare(Categories.appCategoryOf({ id: "x", name: "X" }), "other")
            compare(Categories.appCategoryOf(null), "other")
        }

        function test_appCategory_ignoresNonStringMembers() {
            compare(Categories.appCategoryOf(entry([null, "  ", "Game"])), "games")
        }

        // --- clipboard categories ---

        function test_clipCategory_images() {
            compare(Categories.clipCategoryOf(clipRow("anything", { isImage: true })), "image")
            compare(Categories.clipCategoryOf(clipRow("x", { mime: "image/png" })), "image")
            compare(Categories.clipCategoryOf(
                clipRow("[[binary data 12.3 KiB png 640x480]]")), "image")
        }

        function test_clipCategory_links() {
            compare(Categories.clipCategoryOf(clipRow("https://example.com/a")), "link")
            compare(Categories.clipCategoryOf(clipRow("www.example.com")), "link")
            compare(Categories.clipCategoryOf(clipRow("mailto:someone@example.com")), "link")
            compare(Categories.clipCategoryOf(clipRow("file:///home/user/notes.txt")), "link")
            // Prose that merely mentions a protocol stays text.
            compare(Categories.clipCategoryOf(clipRow("see https://example.com later")), "text")
        }

        function test_clipCategory_colors() {
            compare(Categories.clipCategoryOf(clipRow("#fff")), "color")
            compare(Categories.clipCategoryOf(clipRow("#FF8800")), "color")
            compare(Categories.clipCategoryOf(clipRow("#ff8800cc")), "color")
            compare(Categories.clipCategoryOf(clipRow("rgb(255, 136, 0)")), "color")
            compare(Categories.clipCategoryOf(clipRow("rgba(0,0,0,0.5)")), "color")
        }

        function test_clipCategory_numbers() {
            compare(Categories.clipCategoryOf(clipRow("42")), "number")
            compare(Categories.clipCategoryOf(clipRow("-3.5")), "number")
            compare(Categories.clipCategoryOf(clipRow("1,234.5")), "number")
            compare(Categories.clipCategoryOf(clipRow("1e5")), "number")
            compare(Categories.clipCategoryOf(clipRow("50%")), "number")
            compare(Categories.clipCategoryOf(clipRow("20px")), "number")
            compare(Categories.clipCategoryOf(clipRow("1.5 GB")), "number")
            // Two numbers are not one value.
            compare(Categories.clipCategoryOf(clipRow("3 items")), "text")
        }

        function test_clipCategory_code() {
            compare(Categories.clipCategoryOf(clipRow("def main():\n    pass")), "code")
            compare(Categories.clipCategoryOf(clipRow("#!/usr/bin/env python3")), "code")
            compare(Categories.clipCategoryOf(clipRow("#include <stdio.h>")), "code")
            compare(Categories.clipCategoryOf(clipRow("{\"name\": \"afloat\"}")), "code")
            compare(Categories.clipCategoryOf(clipRow("SELECT id FROM apps")), "code")
            compare(Categories.clipCategoryOf(clipRow("sudo pacman -Syu")), "code")
            compare(Categories.clipCategoryOf(clipRow("/usr/bin/git status")), "code")
            compare(Categories.clipCategoryOf(clipRow("const add = (a, b) => a + b")), "code")
            compare(Categories.clipCategoryOf(clipRow("body { color: red; }")), "code")
        }

        function test_clipCategory_plainTextStaysText() {
            compare(Categories.clipCategoryOf(clipRow("The quick brown fox")), "text")
            compare(Categories.clipCategoryOf(clipRow("if you want to change it, edit the file")), "text")
            compare(Categories.clipCategoryOf(clipRow("for example, this is a note")), "text")
            compare(Categories.clipCategoryOf(clipRow("Meeting notes: discuss pricing")), "text")
            compare(Categories.clipCategoryOf(clipRow("")), "text")
            compare(Categories.clipCategoryOf(clipRow("   ")), "text")
            compare(Categories.clipCategoryOf(null), "text")
        }

        // --- chip model ---

        function test_chipsFor_appsTaxonomyOrderWithLiveCounts() {
            var chips = Categories.chipsFor("apps",
                Logic.categorySummary([item("a", "Alpha", "games"),
                                       item("b", "Beta", "dev"),
                                       item("c", "Gamma", "games")], ""))
            compare(chips.length, 10)
            compare(chips[0].id, "")
            compare(chips[0].label, "All")
            compare(chips[0].count, 3)
            compare(chips[1].id, "games")
            compare(chips[1].count, 2)
            compare(chips[2].id, "dev")
            compare(chips[2].count, 1)
            // Every taxonomy chip keeps its slot even when empty, so the bar
            // never reflows while the user types.
            compare(chips[3].count, 0)
            compare(chips[9].id, "other")
        }

        function test_chipsFor_clipboardTaxonomy() {
            var chips = Categories.chipsFor("clipboard",
                Logic.categorySummary([item("a", "Alpha", "link"),
                                       item("b", "Beta", "link"),
                                       item("c", "Gamma", "image")], ""))
            compare(chips.length, 7)
            compare(chips[0].count, 3)
            compare(chips[1].id, "text")
            compare(chips[2].id, "link")
            compare(chips[2].count, 2)
            compare(chips[4].id, "image")
            compare(chips[4].count, 1)
        }

        function test_chipsFor_shortcutCategoriesBecomeExtraChips() {
            // Shortcut binds carry their own slugs, which ride the
            // "outside the taxonomy" path, sorted and capitalized.
            var chips = Categories.chipsFor("shortcuts",
                Logic.categorySummary([item("a", "Alpha", "windows"),
                                       item("b", "Beta", "windows"),
                                       item("c", "Gamma", "shell")], ""))
            compare(chips.length, 3)
            compare(chips[0].count, 3)
            compare(chips[1].id, "shell")
            compare(chips[1].label, "Shell")
            compare(chips[2].id, "windows")
            compare(chips[2].label, "Windows")
            compare(chips[2].count, 2)
        }

        function test_chipsFor_unknownModeIsAllOnly() {
            var chips = Categories.chipsFor("nonsense",
                Logic.categorySummary([item("a", "Alpha", "games")], ""))
            compare(chips.length, 2)
            compare(chips[0].count, 1)
            compare(chips[1].id, "games")
            compare(chips[1].label, "Games")
        }

        // --- category summary ---

        function test_categorySummary_countsFollowTextButSlotsDoNot() {
            var pool = [item("a", "Firefox", "network"),
                        item("b", "Steam", "games"),
                        item("c", "Gamma", "games")]
            var all = Logic.categorySummary(pool, "")
            compare(all.total, 3)
            compare(all.categories.length, 2)
            compare(all.categories[0].id, "network")
            compare(all.categories[0].count, 1)
            compare(all.categories[1].count, 2)

            // A query narrows the counts but keeps every chip addressable.
            var narrow = Logic.categorySummary(pool, "steam")
            compare(narrow.total, 1)
            compare(narrow.categories.length, 2)
            compare(narrow.categories[0].id, "network")
            compare(narrow.categories[0].count, 0)
            compare(narrow.categories[1].count, 1)
        }

        function test_categorySummary_unclassifiedItemsOnlyCountAsTotal() {
            var summary = Logic.categorySummary([item("a", "Alpha", ""),
                                                 item("b", "Beta", "")], "")
            compare(summary.total, 2)
            compare(summary.categories.length, 0)
        }

        function test_categorySummary_emptyPool() {
            var summary = Logic.categorySummary([], "")
            compare(summary.total, 0)
            compare(summary.categories.length, 0)
        }

        // --- lens filtering ---

        function test_filterResults_narrowsByCategoryAndText() {
            var pool = [item("a", "Firefox", "network"),
                        item("b", "Steam", "games"),
                        item("c", "Netscape", "network")]

            var all = Logic.filterResults(pool, "", "")
            compare(all.length, 3)

            var games = Logic.filterResults(pool, "", "games")
            compare(games.length, 1)
            compare(games[0].id, "b")

            var gamesWithText = Logic.filterResults(pool, "net", "games")
            compare(gamesWithText.length, 0)

            var networks = Logic.filterResults(pool, "net", "network")
            compare(networks.length, 2)

            // A two-argument call stays unfiltered, as before the lens.
            compare(Logic.filterResults(pool, "net").length, 2)
        }

        function test_filterResults_unclassifiedItemsHideBehindAChip() {
            var pool = [item("a", "Alpha", ""), item("b", "Beta", "games")]
            compare(Logic.filterResults(pool, "", "").length, 2)
            compare(Logic.filterResults(pool, "", "games").length, 1)
        }

        function test_matchesCategory() {
            var row = item("a", "Alpha", "games")
            verify(Logic.matchesCategory(row, ""))
            verify(Logic.matchesCategory(row, "games"))
            verify(!Logic.matchesCategory(row, "dev"))
            verify(!Logic.matchesCategory(null, "games"))
            verify(Logic.matchesCategory(item("b", "Beta", ""), ""))
            verify(!Logic.matchesCategory(item("b", "Beta", ""), "games"))
        }

        function test_lastMatchIndex_respectsTheCategoryLens() {
            var pool = [item("a", "Alpha", "games"),
                        item("b", "Beta", "network"),
                        item("c", "Gamma", "games")]
            // No text: everything is a match, full range.
            compare(Logic.lastMatchIndex(pool, "", ""), 2)
            // A category lens narrows the range to its own last row.
            compare(Logic.lastMatchIndex(pool, "", "games"), 2)
            compare(Logic.lastMatchIndex(pool, "", "network"), 1)
            compare(Logic.lastMatchIndex(pool, "", "office"), -1)
            // Deep matches hidden behind another chip must not stretch the
            // materialized window.
            compare(Logic.lastMatchIndex(pool, "alpha", "games"), 0)
            compare(Logic.lastMatchIndex(pool, "alpha", "network"), -1)
        }
    }
}