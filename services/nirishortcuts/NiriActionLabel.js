.pragma library

// A short, human name for a niri bind's action.
//
// Most binds in a real config carry no `hotkey-overlay-title`, so the parser
// hands back the prettified action body - which for a shell shortcut is a whole
// `spawn "qs" "ipc" ... launcher toggle` command line. The title rail has room
// for two words, so the action has to be named rather than quoted.
//
// The naming is TRANSLATION KEYS, not text: this file stays language-free and
// returns `{ key, args }` for the caller to resolve through `Tr.q`, which is how
// every other string in the shell works. A key with no entry renders as the key
// itself, which is a visible miss rather than a silently wrong word.
//
// Ordered most-specific first. A rule that matches is the answer; the last rule
// is the fallback, so nothing ever comes back empty.

// The name of a spawn target, by the program that is being run.
var _SPAWN_TARGETS = [
    { match: ["kitty", "alacritty", "foot", "wezterm", "konsole", "gnome-terminal", "xterm"], key: "hint.action.terminal" },
    { match: ["firefox", "chromium", "google-chrome", "brave", "qutebrowser"], key: "hint.action.browser" },
    { match: ["code", "code-oss", "codium", "zed", "nvim", "vim", "emacs"], key: "hint.action.editor" },
    { match: ["dolphin", "nautilus", "thunar", "yazi", "ranger", "nemo"], key: "hint.action.fileManager" },
    { match: ["rofi", "wofi", "fuzzel"], key: "hint.action.runner" },
    { match: ["pavucontrol", "pavucontrol-qt", "pavucontrol-qt"], key: "hint.action.volumeControl" },
    { match: ["btop", "htop", "btm"], key: "hint.action.systemMonitor" },
    { match: ["pamixer", "wpctl"], key: "hint.action.volume" },
    { match: ["brightnessctl"], key: "hint.action.brightness" }
]

// niri's own actions, by their first token. Deliberately terse: the rail names
// what the key DOES, and a sentence would not fit.
var _NIRI_ACTIONS = {
    "focus-column-left": "hint.action.focusLeft",
    "focus-column-right": "hint.action.focusRight",
    "focus-column-first": "hint.action.focusFirst",
    "focus-column-last": "hint.action.focusLast",
    "focus-window-up": "hint.action.focusUp",
    "focus-window-down": "hint.action.focusDown",
    "focus-workspace-up": "hint.action.workspaceUp",
    "focus-workspace-down": "hint.action.workspaceDown",
    "focus-workspace": "hint.action.workspace",
    "focus-monitor-left": "hint.action.monitorLeft",
    "focus-monitor-right": "hint.action.monitorRight",
    "focus-monitor-up": "hint.action.monitorUp",
    "focus-monitor-down": "hint.action.monitorDown",
    "move-column-left": "hint.action.moveColumnLeft",
    "move-column-right": "hint.action.moveColumnRight",
    "move-window-up": "hint.action.moveWindowUp",
    "move-window-down": "hint.action.moveWindowDown",
    "move-column-to-workspace-up": "hint.action.moveColumnWorkspaceUp",
    "move-column-to-workspace-down": "hint.action.moveColumnWorkspaceDown",
    "move-window-to-workspace-up": "hint.action.moveWindowWorkspaceUp",
    "move-window-to-workspace-down": "hint.action.moveWindowWorkspaceDown",
    "move-column-to-monitor-left": "hint.action.moveColumnMonitorLeft",
    "move-column-to-monitor-right": "hint.action.moveColumnMonitorRight",
    "move-column-to-monitor-up": "hint.action.moveColumnMonitorUp",
    "move-column-to-monitor-down": "hint.action.moveColumnMonitorDown",
    "close-window": "hint.action.closeWindow",
    "toggle-window-floating": "hint.action.toggleFloating",
    "switch-focus-between-floating-and-tiling": "hint.action.switchFloatingTiling",
    "toggle-column-tabbed-display": "hint.action.toggleTabbed",
    "toggle-overview": "hint.action.overview",
    "show-hotkey-overlay": "hint.action.hotkeyOverlay",
    "maximize-column": "hint.action.maximizeColumn",
    "fullscreen-window": "hint.action.fullscreen",
    "center-column": "hint.action.centerColumn",
    "center-visible-columns": "hint.action.centerColumns",
    "switch-preset-column-width": "hint.action.presetWidth",
    "switch-preset-window-height": "hint.action.presetHeight",
    "reset-window-height": "hint.action.resetHeight",
    "set-column-width": "hint.action.columnWidth",
    "set-window-height": "hint.action.windowHeight",
    "consume-or-expel-window-left": "hint.action.consumeLeft",
    "consume-or-expel-window-right": "hint.action.consumeRight",
    "consume-window-into-column": "hint.action.consumeInto",
    "expel-window-from-column": "hint.action.expelFrom",
    "screenshot": "hint.action.screenshot",
    "screenshot-screen": "hint.action.screenshotScreen",
    "screenshot-window": "hint.action.screenshotWindow",
    "power-off-monitors": "hint.action.monitorsOff",
    "toggle-keyboard-shortcuts-inhibit": "hint.action.inhibitShortcuts",
    "quit": "hint.action.quit",
    "switch-layout": "hint.action.layout"
}

// The shell's own IPC targets, from `NiriShortcutParser`'s action ids
// (`shell.<target>.<function>`).
var _SHELL_TARGETS = {
    "launcher": "hint.action.launcher",
    "island": "hint.action.launcher",
    "settings": "hint.action.settings",
    "mediaservice": "hint.action.media",
    "volumeservice": "hint.action.volume",
    "brightnessservice": "hint.action.brightness"
}

var _SHELL_FUNCTIONS = {
    "openclipboard": "hint.action.clipboard",
    "openshortcuts": "hint.action.shortcutList",
    "togglehistory": "hint.action.notifications",
    "togglednd": "hint.action.doNotDisturb",
    "playpause": "hint.action.playPause",
    "previous": "hint.action.previousTrack",
    "next": "hint.action.nextTrack"
}

// The first quoted argument of a spawn, lower-cased and reduced to its basename,
// so `/usr/bin/kitty` and `kitty` name the same program.
function _spawnProgram(detail) {
    var text = String(detail == null ? "" : detail)
    var tokens = _tokenize(text)
    for (var index = 0; index < tokens.length; index++) {
        var token = tokens[index]
        if (token === "spawn" || token === "spawn-sh" || token === "sh" || token === "-c")
            continue
        if (token.indexOf("-") === 0)
            continue
        var base = token
        var slash = base.lastIndexOf("/")
        if (slash >= 0 && slash < base.length - 1)
            base = base.slice(slash + 1)
        return base.toLowerCase()
    }
    return ""
}

// Splits an action body into argv-ish tokens, honouring double quotes so a
// quoted path stays one token. The parser has already collapsed whitespace
// between tokens without touching quoted text, so this only has to unquote.
function _tokenize(text) {
    var tokens = []
    var current = ""
    var started = false
    var quoted = false
    for (var index = 0; index < text.length; index++) {
        var character = text[index]
        if (character === "\\" && index + 1 < text.length) {
            current += text[index + 1]
            started = true
            index++
            continue
        }
        if (character === "\"") {
            quoted = !quoted
            started = true
            continue
        }
        if (!quoted && /\s/.test(character)) {
            if (started) {
                tokens.push(current)
                current = ""
                started = false
            }
            continue
        }
        current += character
        started = true
    }
    if (started)
        tokens.push(current)
    return tokens
}

// Does this spawn's argv invoke the shell itself? Every afloat shortcut is one
// of those, and they are the ones with a name worth showing.
function _shellInvocation(detail) {
    var lower = String(detail == null ? "" : detail).toLowerCase()
    return lower.indexOf("afloat-ipc") >= 0
        || lower.indexOf("quickshell/afloat") >= 0
        || lower.indexOf("\"launcher\"") >= 0
        || lower.indexOf("\"island\"") >= 0
}

// The IPC function name inside a spawn command line: the last quoted word after
// `call`/`afloat-ipc`, which is how both routes are written.
function _ipcFunction(detail) {
    var tokens = _tokenize(String(detail == null ? "" : detail))
    var target = ""
    for (var index = tokens.length - 1; index >= 0; index--) {
        var token = tokens[index].toLowerCase()
        if (_SHELL_FUNCTIONS[token] !== undefined)
            return token
        if (token === "launcher" || token === "island" || token === "settings")
            target = token
    }
    return target
}

// `{ key, args }` for one bind entry, or null when there is nothing to say.
//
// `entry.title` wins whenever the config supplied one: the user wrote that name
// for the key, and second-guessing it would be the panel arguing with the file.
// The parser only fills `title` from the action body when no overlay title was
// written, which is why the distinction has to come from `detail` and `actionId`
// rather than from `title` being empty.
function labelForEntry(entry) {
    if (!entry)
        return null

    var actionId = String(entry.actionId == null ? "" : entry.actionId)
    var detail = String(entry.detail == null ? "" : entry.detail)
    var title = String(entry.title == null ? "" : entry.title)

    // 0. A name the config supplied wins outright. The user wrote it for this
    //    key, and the panel second-guessing it would be the panel arguing with
    //    the file.
    var overlayTitle = String(entry.overlayTitle == null ? "" : entry.overlayTitle)
    if (overlayTitle !== "")
        return { key: "hint.action.named", args: { name: overlayTitle } }

    // 1. The shell's own IPC routes, which are what most of this config is.
    if (_shellInvocation(detail) || actionId.indexOf("shell.") === 0) {
        var fn = _ipcFunction(detail)
        if (fn !== "" && _SHELL_FUNCTIONS[fn] !== undefined)
            return { key: _SHELL_FUNCTIONS[fn] }
        var parts = actionId.split(".")
        if (parts.length === 3) {
            var target = parts[1].toLowerCase()
            var shellFn = parts[2].toLowerCase()
            if (_SHELL_FUNCTIONS[shellFn] !== undefined)
                return { key: _SHELL_FUNCTIONS[shellFn] }
            if (_SHELL_TARGETS[target] !== undefined)
                return { key: _SHELL_TARGETS[target] }
        }
        if (fn !== "")
            return { key: _SHELL_TARGETS[fn] || "hint.action.launcher" }
    }

    // 2. niri's own actions, by their first token.
    var tokens = _tokenize(detail)
    if (tokens.length > 0) {
        var head = tokens[0].toLowerCase()

        // `focus-workspace 3` / `move-column-to-workspace 3` FIRST: the number is
        // the whole point of the key (nine keys, nine workspaces), and the generic
        // map below would name all nine identically. Checked before the map
        // because these heads are actions in their own right.
        if (tokens.length > 1) {
            if (head === "focus-workspace")
                return { key: "hint.action.workspace", args: { index: tokens[1] } }
            if (head === "move-column-to-workspace")
                return { key: "hint.action.moveColumnToWorkspace", args: { index: tokens[1] } }
            if (head === "move-window-to-workspace")
                return { key: "hint.action.moveWindowToWorkspace", args: { index: tokens[1] } }
        }

        if (_NIRI_ACTIONS[head] !== undefined)
            return { key: _NIRI_ACTIONS[head] }

        if (head === "spawn" || head === "spawn-sh") {
            var program = _spawnProgram(detail)
            for (var index = 0; index < _SPAWN_TARGETS.length; index++) {
                var rule = _SPAWN_TARGETS[index]
                if (rule.match.indexOf(program) >= 0)
                    return { key: rule.key }
            }
            if (program !== "")
                return { key: "hint.action.run", args: { name: program } }
        }
    }

    // 3. The prettified action text, which is `title`'s own fallback.
    if (title !== "")
        return { key: "hint.action.named", args: { name: title } }

    // 4. The action's own words, prettified. Last resort, and still better than
    //    an empty rail.
    if (detail !== "")
        return { key: "hint.action.named", args: { name: detail } }

    return null
}
