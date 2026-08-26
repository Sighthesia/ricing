import QtQuick
import QtTest
import "../../services/LauncherLogic.js" as Logic

// Lock the pure launcher contracts: prefix parsing, stable sorting,
// selection clamping, and keyboard action precedence.
TestCase {
    name: "LauncherLogic"

    // --- parseQuery ---

    function test_parseQuery_blankDefaultsToApps() {
        var blank = Logic.parseQuery("")
        compare(blank.mode, "apps")
        compare(blank.text, "")
        compare(blank.prefix, "")

        var whitespaceOnly = Logic.parseQuery("   ")
        compare(whitespaceOnly.mode, "apps")
        compare(whitespaceOnly.text, "")
    }

    function test_parseQuery_appText() {
        var parsed = Logic.parseQuery("firefox")
        compare(parsed.mode, "apps")
        compare(parsed.text, "firefox")
        compare(parsed.prefix, "")
    }

    function test_parseQuery_clipboardPrefix() {
        var parsed = Logic.parseQuery(">clip passwords")
        compare(parsed.mode, "clipboard")
        compare(parsed.text, "passwords")
        compare(parsed.prefix, ">clip ")
    }

    function test_parseQuery_shortcutPrefix() {
        var parsed = Logic.parseQuery(">key spawn terminal")
        compare(parsed.mode, "shortcuts")
        compare(parsed.text, "spawn terminal")
        compare(parsed.prefix, ">key ")
    }

    function test_parseQuery_prefixRequiresTrailingSpace() {
        var pending = Logic.parseQuery(">clip")
        compare(pending.mode, "apps")
        compare(pending.text, ">clip")
        compare(pending.prefix, "")
    }

    function test_parseQuery_whitespaceNormalization() {
        var padded = Logic.parseQuery("  fire   fox  ")
        compare(padded.mode, "apps")
        compare(padded.text, "fire fox")

        var prefixed = Logic.parseQuery("   >clip    token   ")
        compare(prefixed.mode, "clipboard")
        compare(prefixed.text, "token")

        var emptyPrefixBody = Logic.parseQuery(">key    ")
        compare(emptyPrefixBody.mode, "shortcuts")
        compare(emptyPrefixBody.text, "")
    }

    function test_parseQuery_defensiveNonStringInput() {
        var nullish = Logic.parseQuery(null)
        compare(nullish.mode, "apps")
        compare(nullish.text, "")
    }

    // --- sortResults ---

    function test_sortResults_contractOrder() {
        var input = [
            { id: "c", name: "zeta", favoriteWeight: 0, lastUsedAt: 100 },
            { id: "a", name: "beta", favoriteWeight: 10, lastUsedAt: 0 },
            { id: "b", name: "alpha", favoriteWeight: 5, lastUsedAt: 200 },
            { id: "d", name: "alpha", favoriteWeight: 5, lastUsedAt: 200 },
            { id: "e", name: "alpha", favoriteWeight: 5, lastUsedAt: 100 },
            { id: "f", name: "yonder", favoriteWeight: 5, lastUsedAt: 100 }
        ]
        var sorted = Logic.sortResults(input)
        var ids = sorted.map(function (item) { return item.id })
        compare(ids.join(","), "a,b,d,e,f,c")
    }

    function test_sortResults_stableIdentifierTiebreak() {
        var input = [
            { id: "z9", name: "same", favoriteWeight: 3, lastUsedAt: 50 },
            { id: "a1", name: "same", favoriteWeight: 3, lastUsedAt: 50 },
            { id: "m5", name: "same", favoriteWeight: 3, lastUsedAt: 50 }
        ]
        var ids = Logic.sortResults(input).map(function (item) { return item.id })
        compare(ids.join(","), "a1,m5,z9")
    }

    function test_sortResults_doesNotMutateInput() {
        var input = [
            { id: "b", name: "beta", favoriteWeight: 1, lastUsedAt: 0 },
            { id: "a", name: "alpha", favoriteWeight: 1, lastUsedAt: 0 }
        ]
        Logic.sortResults(input)
        compare(input[0].id, "b")
    }

    function test_sortResults_missingFieldsSortLast() {
        var sparse = [
            { id: "full", name: "full", favoriteWeight: 2, lastUsedAt: 10 },
            { id: "bare" }
        ]
        var ids = Logic.sortResults(sparse).map(function (item) { return item.id })
        compare(ids.join(","), "full,bare")
    }

    function test_sortResults_emptyAndNullish() {
        compare(Logic.sortResults([]).length, 0)
        verify(Logic.sortResults(null) !== null)
        compare(Logic.sortResults(null).length, 0)
    }

    // --- clampSelection ---

    function test_clampSelection_emptyList() {
        compare(Logic.clampSelection(0, 0), -1)
        compare(Logic.clampSelection(3, -1), -1)
    }

    function test_clampSelection_outOfRange() {
        compare(Logic.clampSelection(5, 3), 2)
        compare(Logic.clampSelection(-4, 3), 0)
        compare(Logic.clampSelection(2, 3), 2)
    }

    function test_clampSelection_defensiveIndex() {
        compare(Logic.clampSelection(NaN, 3), 0)
        compare(Logic.clampSelection("7", 10), 7)
    }

    // --- keyboardAction ---

    function test_keyboardAction_escapePrecedence() {
        compare(Logic.keyboardAction("escape", true, true, true), "clear")
        compare(Logic.keyboardAction("escape", false, true, true), "close")
        compare(Logic.keyboardAction("escape", true, false, false), "clear")
    }

    function test_escapeActionKeepsRoutePrefix() {
        var r = Logic.escapeAction(">clip foo")
        compare(r.action, "clear")
        compare(r.query, ">clip ")

        r = Logic.escapeAction(">clip ")
        compare(r.action, "close")

        r = Logic.escapeAction("fir")
        compare(r.action, "clear")
        compare(r.query, "")

        r = Logic.escapeAction("")
        compare(r.action, "close")
    }

    function test_keyboardAction_enterExecute() {
        compare(Logic.keyboardAction("enter", true, true, true), "execute")
        compare(Logic.keyboardAction("return", true, true, true), "execute")
        compare(Logic.keyboardAction("enter", false, true, true), "execute")
        compare(Logic.keyboardAction("enter", true, false, true), "none")
        compare(Logic.keyboardAction("enter", true, true, false), "none")
    }

    function test_keyboardAction_upDownNavigation() {
        compare(Logic.keyboardAction("up", true, false, true), "up")
        compare(Logic.keyboardAction("down", false, false, true), "down")
    }

    function test_keyboardAction_unknownKeyIsNone() {
        compare(Logic.keyboardAction("", true, true, true), "none")
        compare(Logic.keyboardAction("a", true, true, true), "none")
        compare(Logic.keyboardAction(null, true, true, true), "none")
    }

    function test_refilterSelectionResetsToFirstOnBroadening() {
        var apple = { id: "apple", displayName: "Apple" }
        var banana = { id: "banana", displayName: "Banana" }
        var avocado = { id: "avocado", displayName: "Avocado" }
        var full = [apple, banana, avocado]
        var narrowed = [avocado]

        // Narrowing keeps the anchored item.
        compare(Logic.refilterSelection(full, 2, narrowed), 0)
        compare(Logic.refilterSelection(narrowed, 0, narrowed), 0)

        // Broadening after a hit lands back on the first row.
        compare(Logic.refilterSelection(narrowed, 0, full), 0)
        compare(Logic.refilterSelection([banana], 0, full), 0)

        // Same-size sets keep the anchor only if the item survived.
        compare(Logic.refilterSelection([banana, avocado], 1, [apple, avocado]), 1)
        compare(Logic.refilterSelection([banana, avocado], 0, [apple, avocado]), 0)

        // Empty results always clear the selection.
        compare(Logic.refilterSelection(full, 1, []), -1)
    }

    function test_filterResultsUsesSearchTextAndKeepsIdentity() {
        var alpha = { id: "a", displayName: "Alpha", searchText: "alpha editor" }
        var beta = { id: "b", displayName: "Beta", searchText: "beta browser" }
        var pooled = [alpha, beta]

        var hit = Logic.filterResults(pooled, "edit")
        compare(hit.length, 1)
        compare(hit[0], alpha)

        compare(Logic.filterResults(pooled, ""), pooled)
        compare(Logic.filterResults(pooled, "   "), pooled)
        compare(Logic.filterResults([], "x").length, 0)
        verify(Logic.resultMatches(alpha, "ALPHA"))
        verify(!Logic.resultMatches(beta, "alpha"))
        verify(Logic.resultMatches(null, ""))
        verify(!Logic.resultMatches(null, "x"))
    }

    function test_lastMatchIndexCoversWindowSizing() {
        var alpha = { id: "a", displayName: "Alpha", searchText: "alpha editor" }
        var beta = { id: "b", displayName: "Beta", searchText: "beta browser" }
        var gamma = { id: "c", displayName: "Gamma", searchText: "gamma mail" }

        // Deep match reports its pool position; empty needle spans all.
        compare(Logic.lastMatchIndex([alpha, beta, gamma], "mail"), 2)
        compare(Logic.lastMatchIndex([alpha, beta, gamma], ""), 2)
        compare(Logic.lastMatchIndex([alpha, beta, gamma], "   "), 2)

        // No match, nullish input, and null items are safe.
        compare(Logic.lastMatchIndex([alpha, beta], "mail"), -1)
        compare(Logic.lastMatchIndex([], "x"), -1)
        compare(Logic.lastMatchIndex(null, "x"), -1)
        compare(Logic.lastMatchIndex([alpha, null, gamma], "mail"), 2)
    }

    function test_preservedSelectionKeepsSurvivorAndClampsOtherwise() {
        var alpha = { id: "a", displayName: "Alpha" }
        var beta = { id: "b", displayName: "Beta" }
        var gamma = { id: "c", displayName: "Gamma" }

        // Selected item still matches after the refilter.
        compare(Logic.preservedSelection([alpha, beta], 1, [gamma, beta]), 1)
        // Selected item vanished: old index clamps into the new bounds.
        compare(Logic.preservedSelection([alpha, beta], 1, [gamma]), 0)
        // No previous selection lands on the first row when results exist.
        compare(Logic.preservedSelection([], -1, [alpha, beta]), 0)
        compare(Logic.preservedSelection([alpha], 0, []), -1)
    }

    function test_poolMatchesComparesOrderedIds() {
        var first = [{ id: "a" }, { id: "b" }]
        verify(Logic.poolMatches(first, [{ id: "a" }, { id: "b" }]))
        verify(!Logic.poolMatches(first, [{ id: "a" }, { id: "c" }]))
        verify(!Logic.poolMatches(first, [{ id: "b" }, { id: "a" }]))
        verify(!Logic.poolMatches(first, [{ id: "a" }]))
        verify(!Logic.poolMatches(first, null))
    }
}
