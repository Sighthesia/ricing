.pragma library

// Pure Wi-Fi plumbing for NetworkService: terse `nmcli -t` parsing, security
// classification, connect-strategy choice and stderr → user-facing message.
// Stateless and free of QML/Quickshell imports so it stays runnable under
// plain qmltestrunner, matching the other services/ *.js siblings.

// nmcli -t escapes the field separator inside values, so a split on ":" is
// wrong for SSIDs like "Cafe:2.4G". Split escape-aware and cap the field
// count; everything past the last separator stays in the final field.
function splitTerse(line, count) {
    var text = line == null ? "" : String(line)
    var fields = []
    var current = ""
    for (var i = 0; i < text.length; i++) {
        var ch = text.charAt(i)
        if (ch === "\\" && i + 1 < text.length) {
            current += text.charAt(i + 1)
            i++
            continue
        }
        if (ch === ":" && fields.length < count - 1) {
            fields.push(current)
            current = ""
            continue
        }
        current += ch
    }
    fields.push(current)
    return fields
}

// Field value as nmcli meant it, with the terse escaping removed.
function unescapeTerse(value) {
    var text = value == null ? "" : String(value)
    if (text.indexOf("\\") === -1)
        return text
    var out = ""
    for (var i = 0; i < text.length; i++) {
        var ch = text.charAt(i)
        if (ch === "\\" && i + 1 < text.length) {
            out += text.charAt(i + 1)
            i++
            continue
        }
        out += ch
    }
    return out
}

// nmcli prints an empty field for open networks; the UI wants a visible "--".
function normalizeSecurity(value) {
    var text = value == null ? "" : String(value).trim()
    return text === "" ? "--" : text
}

// Turn `nmcli -t -f SSID,SECURITY,SIGNAL,IN-USE device wifi list` output into
// the ssid-keyed map the service exposes. `savedBySsid` comes from
// parseProfileList and decides the `existing` flag plus the exact profile
// uuid/name a connect should target.
function parseWifiList(text, savedBySsid) {
    var saved = savedBySsid || {}
    var map = {}
    var lines = String(text == null ? "" : text).split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i]
        if (!line || !line.trim())
            continue
        var parts = splitTerse(line.trim(), 4)
        if (parts.length < 4)
            continue
        var ssid = parts[0].trim()
        if (!ssid)
            continue
        var security = normalizeSecurity(parts[1])
        var signal = parseInt(parts[2], 10) || 0
        var inUse = parts[3].trim() === "*"
        var profile = saved[ssid] || null
        var existing = !!profile
        if (!map[ssid]) {
            map[ssid] = {
                ssid: ssid,
                security: security,
                signal: signal,
                connected: inUse,
                existing: existing,
                savedName: profile ? profile.name : "",
                savedUuid: profile ? profile.uuid : ""
            }
            continue
        }
        // One SSID can ride several bands/routers: keep the best signal and
        // never let a weaker non-active band clear the active flag.
        var entry = map[ssid]
        if (inUse) {
            entry.connected = true
            entry.signal = signal
        } else if (!entry.connected && signal > entry.signal) {
            entry.signal = signal
        }
        if (!entry.existing && existing) {
            entry.existing = true
            entry.savedName = profile.name
            entry.savedUuid = profile.uuid
        }
    }
    return map
}

// Read `nmcli -t -f <fields> connection show uuid …`. The detailed form does
// not accept NAME and prints one "<field>:<value>" line per requested field,
// grouped per connection and separated by a blank line; a field with an empty
// value contributes an empty line. Every line names its own field, so this is
// order-independent and needs no positional guesswork — the earlier attempt to
// pair rows by position silently mismatched profiles to SSIDs.
function parseProfileDetail(detailText) {
    var out = []
    var groups = String(detailText == null ? "" : detailText).split(/\n[ \t]*\n/)
    for (var g = 0; g < groups.length; g++) {
        var lines = groups[g].split("\n")
        var entry = { uuid: "", ssid: "", keyMgmt: "" }
        var sawField = false
        for (var l = 0; l < lines.length; l++) {
            var raw = lines[l]
            if (!raw || !raw.trim())
                continue
            var sep = raw.indexOf(":")
            if (sep <= 0)
                continue
            var field = raw.substring(0, sep)
            var value = unescapeTerse(raw.substring(sep + 1).trim())
            if (field === "802-11-wireless.ssid") {
                entry.ssid = value
                sawField = true
            } else if (field === "connection.uuid") {
                entry.uuid = value
                sawField = true
            } else if (field === "802-11-wireless-security.key-mgmt") {
                entry.keyMgmt = value
                sawField = true
            }
        }
        if (sawField && entry.uuid)
            out.push(entry)
    }
    return out
}

// Build the saved-profile lookup from two nmcli calls:
//
//   nmcli -t -f NAME,UUID,TYPE connection show
//   nmcli -t -f 802-11-wireless.ssid,connection.uuid,\
//   802-11-wireless-security.key-mgmt connection show uuid <uuids…>
//
// Matching on profile NAME alone is not enough: NetworkManager appends " 1"
// to a duplicate name, so a saved SSID can live under a name the scan never
// sees — those networks read as unsaved, and every connect against them missed
// (or created yet another duplicate profile).
function parseProfileList(baseText, detailText) {
    var bySsid = {}
    var byName = {}
    var meta = {}

    var baseLines = String(baseText == null ? "" : baseText).split("\n")
    for (var b = 0; b < baseLines.length; b++) {
        var line = baseLines[b]
        if (!line || !line.trim())
            continue
        var parts = splitTerse(line.trim(), 3)
        if (parts.length < 3)
            continue
        var name = parts[0].trim()
        var uuid = parts[1].trim()
        var type = parts[2].trim()
        if (!name || !uuid)
            continue
        byName[name] = true
        meta[uuid] = { name: name, type: type }
    }

    var details = parseProfileDetail(detailText)
    var matched = {}
    for (var d = 0; d < details.length; d++) {
        var row = details[d]
        if (!row.ssid)
            continue
        var owner = meta[row.uuid]
        matched[row.uuid] = true
        // First profile wins: NM never has two usable profiles for one SSID,
        // and a stable pick keeps repeated scans from flapping.
        if (!bySsid[row.ssid])
            bySsid[row.ssid] = {
                name: owner ? owner.name : row.uuid,
                uuid: row.uuid,
                keyMgmt: row.keyMgmt
            }
    }

    // Name fallback: still correct whenever NM kept the SSID as the profile
    // name, and it is the whole lookup when the detail call was rejected.
    for (var uuid in meta) {
        var info = meta[uuid]
        if (info.type !== "802-11-wireless" || matched[uuid])
            continue
        if (!bySsid[info.name])
            bySsid[info.name] = { name: info.name, uuid: uuid, keyMgmt: "" }
    }
    return { bySsid: bySsid, byName: byName }
}

// WPA-PSK family vs. everything else. "open" means no secret is needed.
function securityKeyFor(security) {
    var s = String(security == null ? "" : security).toLowerCase()
    if (!s || s === "--" || s === "open" || s === "none")
        return "open"
    if (s.indexOf("wep") !== -1)
        return "wep"
    if (s.indexOf("sae") !== -1 && s.indexOf("wpa2") === -1)
        return "sae"
    if (s.indexOf("wpa") !== -1)
        return "wpa-psk"
    return s
}

// True when the AP (or the saved profile) needs an 802.1X exchange, which
// this build cannot drive.
function isEnterprise(security) {
    var s = String(security == null ? "" : security).toUpperCase()
    if (!s)
        return false
    return s.indexOf("802.1X") !== -1 || s.indexOf("802-1X") !== -1
        || s.indexOf("EAP") !== -1 || s.indexOf("ENTERPRISE") !== -1
        || s.indexOf("WPA2 ENT") !== -1 || s.indexOf("WPA3 ENT") !== -1
        || s.indexOf("WPA ENT") !== -1
}

function isEnterpriseKeyMgmt(keyMgmt) {
    var s = String(keyMgmt == null ? "" : keyMgmt).toLowerCase()
    return s === "802-1x" || s === "wpa-eap" || s === "leap" || s === "peap"
}

// Does a tap on this row need credentials typed in first?
function isSecured(security) {
    var text = security == null ? "" : String(security).trim()
    return text !== "" && text !== "--" && text.toLowerCase() !== "open"
}

// How to reach an SSID:
//   activate — a saved profile exists, just bring it up
//   modify   — a saved profile exists but the user retyped its password
//   create   — no profile; let `nmcli device wifi connect` make one
function connectPlan(savedProfile, hasPassword) {
    if (savedProfile && savedProfile.uuid)
        return hasPassword ? "modify" : "activate"
    return "create"
}

function activateArgs(uuid, device) {
    var args = ["connection", "up", "uuid", uuid]
    if (device)
        args.push("ifname", device)
    return args
}

// Only the secret is rewritten; key-mgmt stays whatever the profile was built
// with, so a WPA3 (SAE) profile is not silently downgraded to wpa-psk.
function modifyArgs(uuid, password) {
    return ["connection", "modify", "uuid", uuid,
        "802-11-wireless-security.psk", password == null ? "" : String(password)]
}

function createArgs(ssid, password, hidden, device) {
    var args = ["device", "wifi", "connect", ssid]
    if (password)
        args.push("password", String(password))
    if (hidden)
        args.push("hidden", "yes")
    if (device)
        args.push("ifname", device)
    return args
}

function downArgs(uuidOrName) {
    return ["connection", "down", "id", uuidOrName]
}

function deleteArgs(uuid) {
    return ["connection", "delete", "uuid", uuid]
}

// First meaningful line of an nmcli stderr dump, minus the "Error:" prefix.
function firstErrorLine(text) {
    var lines = String(text == null ? "" : text).split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (!line)
            continue
        if (line.toLowerCase().indexOf("warning:") === 0)
            continue
        line = line.replace(/^error:\s*/i, "")
        return line.length > 72 ? line.substring(0, 71) + "…" : line
    }
    return ""
}

// nmcli runs under LC_ALL=C in this service, so these needles are stable.
// Anything unmatched falls through to the raw first line, which beats a
// blanket "Connection failed" — that string is what made every failure look
// identical in the popup.
function classifyConnectError(rawText) {
    var text = String(rawText == null ? "" : rawText)
    if (!text.trim())
        return "Connection failed"
    var lower = text.toLowerCase()
    if (lower.indexOf("secrets were required") !== -1
            || lower.indexOf("no secrets provided") !== -1
            || lower.indexOf("invalid password") !== -1
            || lower.indexOf("no key") !== -1
            || lower.indexOf("pre-shared key") !== -1
            || lower.indexOf("authentication failed") !== -1)
        return "Incorrect password"
    if (lower.indexOf("802-1x") !== -1 || lower.indexOf("802.1x") !== -1
            || lower.indexOf("supplicant") !== -1)
        return "Enterprise (EAP) network — not supported"
    if (lower.indexOf("no network with ssid") !== -1)
        return "Network not found"
    if (lower.indexOf("timed out") !== -1 || lower.indexOf("timeout") !== -1)
        return "Connection timeout"
    if (lower.indexOf("unknown connection") !== -1)
        return "Saved profile is gone"
    if (lower.indexOf("no suitable device") !== -1
            || lower.indexOf("not available") !== -1
            || lower.indexOf("no wifi device") !== -1
            || lower.indexOf("wifi is disabled") !== -1
            || lower.indexOf("rf-kill") !== -1)
        return "Wi-Fi adapter unavailable"
    return firstErrorLine(text) || "Connection failed"
}

// A credential failure on a network we already hold a profile for is
// recoverable: offer the password row again instead of a dead end.
function isCredentialFailure(message) {
    var m = String(message == null ? "" : message)
    return m === "Incorrect password"
}

// Signal strength → Nerd Font glyph / short label, shared by the bar pill and
// the popup rows so both read the same ladder.
function signalIcon(signal, connected, connectivity) {
    var s = Number(signal) || 0
    if (connected) {
        if (connectivity === "limited")
            return "\uf2d2"   // wifi-exclamation
        if (connectivity === "portal" || connectivity === "unknown")
            return "\uf2d4"   // wifi-question
    }
    if (s >= 80)
        return "\uf1eb"   // wifi (full)
    if (s >= 60)
        return "\uf2eb"   // wifi-3
    if (s >= 35)
        return "\uf2ea"   // wifi-2
    if (s >= 15)
        return "\uf2e9"   // wifi-1
    return "\uf2e8"                   // wifi-0
}

function signalLabel(signal) {
    var s = Number(signal) || 0
    if (s >= 80)
        return "Excellent"
    if (s >= 60)
        return "Good"
    if (s >= 35)
        return "Fair"
    if (s >= 15)
        return "Poor"
    return "Weak"
}
