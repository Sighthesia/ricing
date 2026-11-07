.pragma library

// Pure row builder for the bar's right-click menu.
//
// The menu is a stack of pages: the root list, plus one drilled-down page per
// child (`widget-settings`, `add-widget`, `move`). Which rows exist, in what
// order, and inside which block is decided here, so the QML only draws them.
// Every label is an i18n KEY (the caller runs it through Tr.q) and every glyph
// is a symbolic name the caller resolves, which keeps this file free of Qt and
// readable without instantiating anything.

// Root page, in three blocks: what the bar does, what the widget does, and the
// shell underneath both. `block` is where a block starts; a block is drawn as
// its own card and the gap between blocks carries the grouping, so no section
// header row is needed.
//
// `trailing` picks the readout on the right: "layout" prints the layout-mode
// word, "chevron" prints a disclosure arrow, anything else prints nothing.
var rootRows = [
    { id: "layout", action: "toggleLayoutMode", label: "context.layoutMode",
      glyph: "lazer:layout.svg", trailing: "layout", block: 0 },
    { id: "move", child: "move", label: "context.moveWidget",
      glyph: "lazer:widget-move.svg", trailing: "chevron", needsWidget: true, block: 0 },
    { id: "settings", child: "widget-settings", label: "context.widgetSettings",
      glyph: "lazer:settings.svg", trailing: "chevron", needsWidget: true, block: 1 },
    { id: "add", child: "add-widget", label: "context.addWidgets",
      glyph: "lazer:widget-add.svg", trailing: "chevron", block: 1 },
    { id: "remove", action: "remove", label: "context.removeWidget",
      glyph: "lazer:widget-remove.svg", needsWidget: true, block: 1 },
    { id: "shell", action: "openShellSettings", label: "context.shellSettings",
      glyph: "lazer:desktop.svg", block: 2 },
]

// Move page: the three routes a widget can take, gathered in one place instead
// of occupying three root rows.
var moveRows = [
    { id: "left", action: "moveLeft", label: "context.moveLeft",
      glyph: "lazer:chevron-left.svg", needsWidget: true },
    { id: "right", action: "moveRight", label: "context.moveRight",
      glyph: "lazer:chevron-right.svg", needsWidget: true },
    { id: "section", action: "moveToSection", label: "context.moveToSection",
      glyph: "lazer:sidebar-return.svg", needsWidget: true },
]

function copyRow(row) {
    return {
        "id": String(row.id || ""),
        "action": String(row.action || ""),
        "child": String(row.child || ""),
        "label": String(row.label || ""),
        "glyph": String(row.glyph || ""),
        "trailing": String(row.trailing || ""),
        "needsWidget": row.needsWidget === true,
        "block": Number(row.block !== undefined ? row.block : 0),
    }
}

// Rows a context can actually use: a row that names a widget drops out of an
// empty-area menu rather than greying an already-tight list.
function visible(rows, hasWidget) {
    var out = []
    for (var index = 0; index < rows.length; index++) {
        if (rows[index].needsWidget === true && !hasWidget)
            continue
        out.push(copyRow(rows[index]))
    }
    return out
}

function rowsForRoot(hasWidget) {
    return visible(rootRows, hasWidget)
}

function rowsForMove(hasWidget) {
    return visible(moveRows, hasWidget)
}

// The root rows split into their declared blocks. A block that filtered out
// completely leaves no empty card behind.
function rootBlocks(hasWidget) {
    var rows = rowsForRoot(hasWidget)
    var blocks = []
    var current = []
    var currentBlock = -1

    for (var index = 0; index < rows.length; index++) {
        var row = rows[index]
        if (row.block !== currentBlock) {
            if (current.length > 0)
                blocks.push(current)
            current = []
            currentBlock = row.block
        }
        current.push(row)
    }
    if (current.length > 0)
        blocks.push(current)
    return blocks
}

// Title key for a drilled-down page. The root page has no title of its own, so
// its header is the menu's plain face.
function pageTitleKey(page) {
    if (page === "widget-settings")
        return "context.widgetSettings"
    if (page === "add-widget")
        return "context.addWidgets"
    if (page === "move")
        return "context.moveWidget"
    return ""
}
