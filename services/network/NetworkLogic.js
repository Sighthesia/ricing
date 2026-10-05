.pragma library

// Network plumbing for NetworkService: terse `nmcli -t` parsing (device table,
// wireless list, saved profiles, wired profiles), security classification,
// connect-strategy choice and stderr → user-facing message.
// Stateless and free of QML/Quickshell imports, matching the other
// services/ *.js siblings, so it can be read and reasoned about on its own.

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

// nmcli reports the AP's link rate as "1170 Mbit/s". A list row has room for
// roughly a dozen glyphs, and the shorter unit is unambiguous next to a
// percentage, so the unit is trimmed rather than the value. An empty rate is
// normal (some drivers omit it), and must stay empty instead of reading as 0.
function formatRate(rawValue) {
    var text = String(rawValue == null ? "" : rawValue).trim()
    if (text === "" || text === "--")
        return ""
    return text.replace(/\s*Mbit\/s\s*$/i, " Mb/s").replace(/\s+/g, " ").trim()
}

// Turn `nmcli -t -f SSID,SECURITY,SIGNAL,RATE,IN-USE device wifi list` output
// into the ssid-keyed map the service exposes. `savedBySsid` comes from
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
        var parts = splitTerse(line.trim(), 5)
        if (parts.length < 5)
            continue
        var ssid = parts[0].trim()
        if (!ssid)
            continue
        var security = normalizeSecurity(parts[1])
        var signal = parseInt(parts[2], 10) || 0
        var rate = formatRate(parts[3])
        var inUse = parts[4].trim() === "*"
        var profile = saved[ssid] || null
        var existing = !!profile
        if (!map[ssid]) {
            map[ssid] = {
                ssid: ssid,
                security: security,
                signal: signal,
                rate: rate,
                connected: inUse,
                existing: existing,
                savedName: profile ? profile.name : "",
                savedUuid: profile ? profile.uuid : ""
            }
            continue
        }
        // One SSID can ride several bands/routers: keep the best signal and
        // never let a weaker non-active band clear the active flag. The rate
        // follows whichever entry won the signal, and the active AP always
        // wins outright — its rate is the one the link is actually using.
        var entry = map[ssid]
        if (inUse) {
            entry.connected = true
            entry.signal = signal
            entry.rate = rate
        } else if (!entry.connected && signal > entry.signal) {
            entry.signal = signal
            entry.rate = rate
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
// not accept NAME and prints one "<field>:<value>" line per field that has a
// value, grouped per connection and separated by a blank line. Measured on this
// machine: a field with no value is not printed at all (it is not printed as an
// empty "<field>:" line either), so "absent" and "empty" are the same thing
// here — which is why the fields this needs are all optional.
//
// Every line names its own field, so parsing is order-independent and needs no
// positional guesswork — the earlier attempt to pair rows by position silently
// mismatched profiles to SSIDs.
function parseProfileDetail(detailText) {
    var out = []
    var groups = String(detailText == null ? "" : detailText).split(/\n[ \t]*\n/)
    for (var g = 0; g < groups.length; g++) {
        var lines = groups[g].split("\n")
        var entry = {
            uuid: "", ssid: "", keyMgmt: "", ifname: "",
            ip4Method: "", ip4Addresses: "", ip4Gateway: "", autoconnect: ""
        }
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
            } else if (field === "connection.interface-name") {
                entry.ifname = value
                sawField = true
            } else if (field === "ipv4.method") {
                entry.ip4Method = value
                sawField = true
            } else if (field === "ipv4.addresses") {
                entry.ip4Addresses = value
                sawField = true
            } else if (field === "ipv4.gateway") {
                entry.ip4Gateway = value
                sawField = true
            } else if (field === "connection.autoconnect") {
                entry.autoconnect = value
                sawField = true
            }
        }
        if (sawField && entry.uuid)
            out.push(entry)
    }
    return out
}

// Which of several profiles for one SSID should a tap actually activate?
// NetworkManager pins a profile to the adapter it was created on, and adapter
// names move around (wlan0 → wlo1, predictable names dropped). A profile still
// pinned to a device that no longer exists is dead: NM refuses it with
// "not compatible … (mismatching interface name)" and the user can do nothing
// about it from the panel. So rank by usability against the live adapter, and
// only then fall back to the first profile seen.
function profileRank(profile, liveDevice) {
    if (!profile)
        return 3
    var pin = profile.ifname ? String(profile.ifname) : ""
    if (!pin)
        return 0                   // unpinned: usable on any adapter
    if (liveDevice && pin === String(liveDevice))
        return 1                   // pinned to the adapter we actually have
    return 2                       // pinned to an adapter that is gone
}

// A profile pinned to an adapter that is not the one we have can be repaired
// instead of abandoned: re-pointing it at the live adapter is exactly what
// NetworkManager would have written had the user connected from that adapter,
// and it keeps the stored secret, so nothing has to be retyped.
function isStaleAdapterPin(profile, liveDevice) {
    if (!profile || !profile.ifname || !liveDevice)
        return false
    return String(profile.ifname) !== String(liveDevice)
}

// Build the saved-profile lookup from two nmcli calls:
//
//   nmcli -t -f NAME,UUID,TYPE connection show
//   nmcli -t -f 802-11-wireless.ssid,connection.uuid,
//   802-11-wireless-security.key-mgmt,connection.interface-name,
//   ipv4.method,ipv4.addresses,ipv4.gateway,connection.autoconnect
//   connection show uuid <uuids…>
//
// Matching on profile NAME alone is not enough: NetworkManager appends " 1"
// to a duplicate name, so a saved SSID can live under a name the scan never
// sees — those networks read as unsaved, and every connect against them missed
// (or created yet another duplicate profile).
function parseProfileList(baseText, detailText, liveDevice) {
    var base = parseConnectionBase(baseText)
    var bySsid = {}
    var byName = base.byName
    var meta = base.meta

    var details = parseProfileDetail(detailText)
    var matched = {}
    for (var d = 0; d < details.length; d++) {
        var row = details[d]
        if (!row.ssid)
            continue
        var owner = meta[row.uuid]
        matched[row.uuid] = true
        var candidate = {
            name: owner ? owner.name : row.uuid,
            uuid: row.uuid,
            keyMgmt: row.keyMgmt,
            ifname: row.ifname
        }
        // Only a better-ranked profile may displace the current pick, so
        // repeated scans over an unchanged profile set stay stable.
        if (profileRank(candidate, liveDevice)
                < profileRank(bySsid[row.ssid], liveDevice))
            bySsid[row.ssid] = candidate
    }

    // Name fallback: still correct whenever NM kept the SSID as the profile
    // name, and it is the whole lookup when the detail call was rejected.
    for (var uuid in meta) {
        var info = meta[uuid]
        if (info.type !== "802-11-wireless" || matched[uuid])
            continue
        var fallback = { name: info.name, uuid: uuid, keyMgmt: "", ifname: "" }
        if (profileRank(fallback, liveDevice)
                < profileRank(bySsid[info.name], liveDevice))
            bySsid[info.name] = fallback
    }
    return { bySsid: bySsid, byName: byName }
}

// `nmcli -t -f NAME,UUID,TYPE connection show` → the name/uuid/type of every
// saved profile. Shared by the wireless and the wired lookup so both agree on
// which names belong to which type.
//
// The field budget is deliberately generous rather than exactly 3: nmcli escapes
// a colon inside a value, so any column beyond the third can be split off
// safely — and capping the budget at 3 would fold the rest of the row into the
// type field, which then matches nothing and silently empties the whole wired
// list the moment a fourth column is requested.
function parseConnectionBase(baseText) {
    var byName = {}
    var meta = {}
    var baseLines = String(baseText == null ? "" : baseText).split("\n")
    for (var b = 0; b < baseLines.length; b++) {
        var line = baseLines[b]
        if (!line || !line.trim())
            continue
        var parts = splitTerse(line.trim(), 8)
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
    return { byName: byName, meta: meta }
}

// "1.2.3.4/24, 1.2.3.5/24" → ["1.2.3.4", "1.2.3.5"]. The prefix length is a
// routing detail; a row that names an address wants the address.
function splitAddresses(raw) {
    var text = String(raw == null ? "" : raw).trim()
    if (text === "" || text === "--")
        return []
    var out = []
    var parts = text.split(/[,;]/)
    for (var i = 0; i < parts.length; i++) {
        var one = parts[i].trim()
        if (one === "")
            continue
        var slash = one.indexOf("/")
        out.push(slash > 0 ? one.substring(0, slash) : one)
    }
    return out
}

// Saved 802-3-ethernet profiles, with the addressing a static-IP profile exists
// for. A wired profile is activated by uuid, so the name is presentation only
// and never a handle.
function parseWiredProfiles(baseText, detailText) {
    var base = parseConnectionBase(baseText)
    var out = []
    var details = parseProfileDetail(detailText)
    for (var d = 0; d < details.length; d++) {
        var row = details[d]
        var owner = base.meta[row.uuid]
        if (!owner || owner.type !== "802-3-ethernet")
            continue
        out.push({
            uuid: row.uuid,
            name: owner.name,
            type: owner.type,
            ifname: row.ifname,
            method: row.ip4Method,
            addresses: splitAddresses(row.ip4Addresses),
            gateway: row.ip4Gateway,
            autoconnect: row.autoconnect
        })
    }
    return out
}

// IPv4 addressing method → the word a user reads on a profile row. A DHCP
// profile has no address until it is up, so its row must not look empty.
function ipMethodLabel(method) {
    var m = String(method == null ? "" : method).trim().toLowerCase()
    if (m === "" || m === "auto")
        return "DHCP"
    if (m === "manual")
        return "Manual"
    if (m === "link-local")
        return "Link-local"
    if (m === "shared")
        return "Shared"
    if (m === "disabled")
        return "Disabled"
    return m
}

// `nmcli -t -f GENERAL.DEVICE,… device show` → one entry per device, with the
// link's own addressing. The device block is delimited by GENERAL.DEVICE and
// every other line names its field, so a block is self-describing regardless
// of which optional fields the driver omitted.
function parseDeviceTable(text) {
    var out = []
    var blocks = String(text == null ? "" : text).split(/\n[ \t]*\n/)
    for (var b = 0; b < blocks.length; b++) {
        var lines = blocks[b].split("\n")
        var entry = {
            device: "", type: "", state: "", reason: "",
            connection: "", uuid: "", carrier: "",
            ip4: [], gateway: "", dns: [], ip6: []
        }
        var sawDevice = false
        for (var l = 0; l < lines.length; l++) {
            var raw = lines[l]
            if (!raw || !raw.trim())
                continue
            var sep = raw.indexOf(":")
            if (sep <= 0)
                continue
            var field = raw.substring(0, sep)
            var value = unescapeTerse(raw.substring(sep + 1).trim())
            if (field === "GENERAL.DEVICE") {
                entry.device = value
                sawDevice = true
            } else if (field === "GENERAL.TYPE") {
                entry.type = value
            } else if (field === "GENERAL.STATE") {
                entry.state = value
            } else if (field === "GENERAL.REASON") {
                entry.reason = value
            } else if (field === "GENERAL.CONNECTION") {
                entry.connection = normalizeConnectionName(value)
            } else if (field === "GENERAL.CON-UUID") {
                entry.uuid = value
            } else if (field === "WIRED-PROPERTIES.CARRIER") {
                entry.carrier = value.toLowerCase()
            } else if (field.indexOf("IP4.ADDRESS[") === 0) {
                entry.ip4.push(stripPrefixLength(value))
            } else if (field === "IP4.GATEWAY") {
                entry.gateway = value
            } else if (field.indexOf("IP4.DNS[") === 0) {
                entry.dns.push(value)
            } else if (field.indexOf("IP6.ADDRESS[") === 0) {
                entry.ip6.push(stripPrefixLength(value))
            }
        }
        if (!sawDevice || !entry.device)
            continue
        var state = entry.state
        entry.managed = state.indexOf("(unmanaged)") === -1
        entry.connected = state.indexOf("(connected)") !== -1
        out.push(entry)
    }
    return out
}

// nmcli prints "--" for an empty connection name in some forms and nothing in
// others; both mean "no profile".
function normalizeConnectionName(value) {
    var text = String(value == null ? "" : value).trim()
    return text === "--" ? "" : text
}

function stripPrefixLength(value) {
    var text = String(value == null ? "" : value).trim()
    var slash = text.indexOf("/")
    return slash > 0 ? text.substring(0, slash) : text
}

// Wired port state → the label and the tone a header row shows. "No cable" is
// the answer the user actually needs on a port that is present but silent: it
// separates "nothing plugged in" from "plugged in but nothing activated".
//
// Carrier is checked *before* NetworkManager's own connected state, because the
// two genuinely disagree on this machine: NM reports enp2s0 as connected (it is
// holding a static address) while the kernel reports NO-CARRIER. "Connected"
// there is a claim about a profile being up, not about a link existing, and the
// user needs the link.
//
// An absent `managed` flag is not a claim that the port is unmanaged — only an
// explicit false is, so a caller that never computed it cannot make a live port
// disappear behind that word.
function linkStateLabel(entry) {
    if (!entry)
        return { text: "", tone: "idle" }
    if (entry.managed === false)
        return { text: "Not managed", tone: "idle" }
    if (entry.carrier === "off")
        return { text: "No cable", tone: "idle" }
    if (entry.connected)
        return { text: "Connected", tone: "active" }
    if (String(entry.reason || "").indexOf("Carrier") !== -1
            || String(entry.reason || "").indexOf("40 ") === 0)
        return { text: "No cable", tone: "idle" }
    return { text: "Disconnected", tone: "idle" }
}

// Every managed wired port, each carrying the saved profiles that belong to it.
// A profile pinned to a port names it outright; an unpinned one follows the
// port it is currently up on; a profile pinned to a port that no longer exists
// is collected in one trailing group rather than silently dropped — the user
// needs to see the profile exists in order to get rid of it.
function groupWiredProfiles(devices, profiles) {
    var groups = []
    var byName = {}
    var i, j, k
    for (i = 0; i < devices.length; i++) {
        var device = devices[i]
        if (!device || device.type !== "ethernet" || device.managed === false)
            continue
        var group = {
            device: device.device,
            state: device.state,
            reason: device.reason,
            connected: device.connected,
            carrier: device.carrier,
            connection: device.connection,
            uuid: device.uuid,
            ip4: device.ip4 && device.ip4.length ? device.ip4[0] : "",
            profiles: []
        }
        groups.push(group)
        byName[group.device] = group
    }
    var loose = { device: "", connected: false, carrier: "", ip4: "", profiles: [] }
    for (j = 0; j < profiles.length; j++) {
        var profile = profiles[j]
        if (!profile || !profile.uuid)
            continue
        var pin = profile.ifname ? String(profile.ifname) : ""
        var target = null
        if (pin && byName[pin]) {
            target = byName[pin]
        } else {
            // Unpinned, or pinned to a port that is gone: the port it is
            // actually up on is the only port it can be shown under.
            for (k = 0; k < groups.length; k++) {
                if (groups[k].uuid && groups[k].uuid === profile.uuid) {
                    target = groups[k]
                    break
                }
            }
        }
        var item = {
            uuid: profile.uuid,
            name: profile.name,
            method: profile.method,
            methodLabel: ipMethodLabel(profile.method),
            addresses: profile.addresses || [],
            gateway: profile.gateway || "",
            autoconnect: profile.autoconnect || "",
            // A pin that points at an absent port is dead weight: activation
            // is refused, and the row has to say so before the tap, not after.
            stalePin: !!(pin && !byName[pin]),
            active: !!(target && target.uuid && target.uuid === profile.uuid)
        }
        if (target)
            target.profiles.push(item)
        else
            loose.profiles.push(item)
    }
    if (loose.profiles.length > 0)
        groups.push(loose)
    return groups
}

// The address the user is most likely to type next: the live IPv4 of a link,
// falling back to the first configured address of a static profile so a row
// never reads as though it carries no addressing at all.
function profileAddressText(item) {
    if (!item)
        return ""
    var parts = []
    if (item.addresses && item.addresses.length)
        parts.push(item.addresses.join(", "))
    else
        parts.push(ipMethodLabel(item.method))
    return parts.join(" · ")
}

// The live link a details block describes.
//
// Wired first when it is up, because that is the link the user chose on purpose
// (a direct-connect instrument lives there, and its address is the thing being
// checked). Among several wired links, one that carries a gateway wins — it is
// the routable one, and on a machine with both a wired uplink and a wired
// instrument the uplink is what "the address" means. A link with no gateway
// answers honestly with "—" rather than borrowing another link's numbers.
function activeLinkDetails(devices) {
    var ethernet = null
    var routableEthernet = null
    var wifi = null
    for (var i = 0; i < devices.length; i++) {
        var device = devices[i]
        if (!device || device.managed === false || !device.connected)
            continue
        if (device.type === "ethernet") {
            if (!ethernet)
                ethernet = device
            if (!routableEthernet && device.gateway)
                routableEthernet = device
        } else if (device.type === "wifi" && !wifi) {
            wifi = device
        }
    }
    var link = routableEthernet || ethernet || wifi
    if (!link)
        return { device: "", type: "", connection: "", ip4: "", gateway: "", dns: [] }
    return {
        device: link.device,
        type: link.type,
        connection: link.connection,
        ip4: link.ip4 && link.ip4.length ? link.ip4[0] : "",
        gateway: link.gateway || "",
        dns: link.dns ? link.dns.slice() : []
    }
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
//   activate — a saved profile exists and is usable as-is
//   modify   — repair it first: re-point a dead adapter pin and/or rewrite
//              the stored secret the user retyped
//   create   — no usable profile; let `nmcli device wifi connect` make one
function connectPlan(savedProfile, hasPassword, liveDevice) {
    if (!savedProfile || !savedProfile.uuid)
        return "create"
    if (isStaleAdapterPin(savedProfile, liveDevice) || hasPassword)
        return "modify"
    return "activate"
}

function activateArgs(uuid, device) {
    var args = ["connection", "up", "uuid", uuid]
    if (device)
        args.push("ifname", device)
    return args
}

// Only the properties that actually need changing are written. The PSK goes in
// alone when just the secret is stale, so a WPA3 (SAE) profile keeps its
// key-mgmt; the adapter pin is only rewritten when it points at a device that
// is gone.
function modifyArgs(uuid, password, device, repoint) {
    var args = ["connection", "modify", "uuid", uuid]
    if (repoint && device)
        args.push("connection.interface-name", device)
    if (password != null && String(password) !== "")
        args.push("802-11-wireless-security.psk", String(password))
    return args
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

// How long a wired activation may run before it is called failed. A port the
// kernel reports as having no carrier gets a short leash: NetworkManager queues
// such an activation and cancels it after carrier-wait-timeout (120s by default),
// so the panel must not sit on that number. Four seconds is long enough for a
// cable that is already in hand to register, and short enough that the failure
// arrives while the user is still looking at the row.
function wiredActivationTimeout(carrier) {
    return carrier === "off" ? 4000 : 30000
}

function upArgs(uuid) {
    if (!uuid || String(uuid) === "")
        return ["true"]
    // No ifname: a wired profile that is already pinned to its port carries
    // that pin, and passing a mismatched one is exactly the refusal
    // "not compatible … (mismatching interface name)" comes from.
    return ["connection", "up", "uuid", String(uuid)]
}

// Deactivate by uuid, not by name. NetworkManager renames duplicate profiles
// ("SSID 1"), so the SSID a scan reports is frequently not the connection id
// `nmcli` accepts — and a disconnect aimed at the SSID silently does nothing.
function downArgs(uuidOrName, isUuid) {
    var handle = String(uuidOrName == null ? "" : uuidOrName).trim()
    if (handle === "")
        return ["true"]
    return ["connection", "down", isUuid ? "uuid" : "id", handle]
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
    if (lower.indexOf("carrier") !== -1
            || lower.indexOf("no link") !== -1
            || lower.indexOf("link down") !== -1)
        return "No cable on this port"
    if (lower.indexOf("no suitable device") !== -1
            || lower.indexOf("not compatible") !== -1
            || lower.indexOf("mismatching interface name") !== -1
            || lower.indexOf("incompatible") !== -1)
        return "No adapter matches this saved profile"
    if (lower.indexOf("not available") !== -1
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
