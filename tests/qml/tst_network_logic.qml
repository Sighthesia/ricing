import QtQuick
import QtTest
import "../../services/network/NetworkLogic.js" as Logic

// Unit-test the pure Wi-Fi plumbing: terse `nmcli -t` parsing (escaped SSIDs,
// multi-band duplicates), saved-profile lookup by SSID rather than by profile
// name, connect-strategy choice and stderr → user-facing message. These are
// the rules that made saved networks look unknown and every failure read the
// same inside the popup.
Item {
    TestCase {
        name: "NetworkTerseParsing"
        when: windowShown

        function test_splitTersePlainFields() {
            var parts = Logic.splitTerse("HomeWifi:WPA2:85:*", 4)
            compare(parts.length, 4)
            compare(parts[0], "HomeWifi")
            compare(parts[1], "WPA2")
            compare(parts[2], "85")
            compare(parts[3], "*")
        }

        function test_splitTerseEscapedSeparator() {
            // nmcli escapes the separator inside a value, so "Cafe:2.4G" must
            // not be read as two fields.
            var parts = Logic.splitTerse("Cafe\\:2.4G:WPA2:70:", 4)
            compare(parts.length, 4)
            compare(parts[0], "Cafe:2.4G")
            compare(parts[1], "WPA2")
            compare(parts[2], "70")
            compare(parts[3], "")
        }

        function test_splitTerseStopsAtFieldBudget() {
            var parts = Logic.splitTerse("a:b:c:d:e", 3)
            compare(parts.length, 3)
            compare(parts[0], "a")
            compare(parts[1], "b")
            compare(parts[2], "c:d:e")
        }

        function test_unescapeTerse() {
            compare(Logic.unescapeTerse("Cafe\\:2.4G"), "Cafe:2.4G")
            compare(Logic.unescapeTerse("back\\\\slash"), "back\\slash")
            compare(Logic.unescapeTerse("plain"), "plain")
            compare(Logic.unescapeTerse(undefined), "")
        }

        function test_parseWifiListMapsSsid() {
            // nmcli leaves the security field empty for an open network, and
            // omits the rate entirely for some drivers.
            var map = Logic.parseWifiList("HomeWifi:WPA2:85:405 Mbit/s:*\nCafe::40::", {})
            compare(Object.keys(map).length, 2)
            compare(map.HomeWifi.security, "WPA2")
            compare(map.HomeWifi.signal, 85)
            compare(map.HomeWifi.rate, "405 Mb/s", "the AP rate rides along with the row")
            verify(map.HomeWifi.connected)
            verify(!map.HomeWifi.existing)
            compare(map.Cafe.security, "--", "an empty security field reads as open")
            compare(map.Cafe.rate, "", "a missing rate stays empty instead of reading as 0")
            verify(!map.Cafe.connected)
        }

        function test_parseWifiListKeepsStrongestBand() {
            // One SSID on two radios: the active band must stay flagged and
            // keep its own signal and rate, not be overwritten by a stronger
            // idle one.
            var map = Logic.parseWifiList(
                "Net:WPA2:40:54 Mbit/s:\nNet:WPA2:90:1170 Mbit/s:*\nNet:WPA2:70:130 Mbit/s:", {})
            compare(Object.keys(map).length, 1)
            verify(map.Net.connected)
            compare(map.Net.signal, 90)
            compare(map.Net.rate, "1170 Mb/s", "the rate belongs to the band that won")
        }

        function test_parseWifiListActiveBandSignalWins() {
            var map = Logic.parseWifiList(
                "Net:WPA2:40:54 Mbit/s:*\nNet:WPA2:90:1170 Mbit/s:", {})
            verify(map.Net.connected)
            compare(map.Net.signal, 40, "a stronger idle band must not steal the row")
            compare(map.Net.rate, "54 Mb/s", "nor its rate")
        }

        function test_parseWifiListEscapedSsid() {
            var map = Logic.parseWifiList("Cafe\\:2.4G:WPA2:70:130 Mbit/s:", {})
            verify(map["Cafe:2.4G"] !== undefined, "escaped SSID is unescaped")
            compare(map["Cafe:2.4G"].signal, 70)
            compare(map["Cafe:2.4G"].rate, "130 Mb/s")
        }

        function test_parseWifiListSkipsHiddenAndJunk() {
            var map = Logic.parseWifiList(":WPA2:30:130 Mbit/s:\n\ngarbage\nCafe:WPA2:20:54 Mbit/s:", {})
            compare(Object.keys(map).length, 1)
            compare(map.Cafe.ssid, "Cafe")
        }

        function test_parseWifiListEmptyInput() {
            compare(Object.keys(Logic.parseWifiList("", {})).length, 0)
            compare(Object.keys(Logic.parseWifiList(null, null)).length, 0)
        }

        // The rate is what distinguishes two bands of one SSID, so a value the
        // driver spells differently must not end up on the row verbatim.
        function test_formatRateNormalisesTheUnit() {
            compare(Logic.formatRate("1170 Mbit/s"), "1170 Mb/s")
            compare(Logic.formatRate("  54 Mbit/s "), "54 Mb/s")
            compare(Logic.formatRate("130 Mbit/s"), "130 Mb/s")
            compare(Logic.formatRate("--"), "")
            compare(Logic.formatRate(""), "")
            compare(Logic.formatRate(null), "")
            compare(Logic.formatRate(undefined), "")
            // A unit this machine does not print today must survive intact
            // rather than be mangled into something that looks like a rate.
            compare(Logic.formatRate("1.2 Gbit/s"), "1.2 Gbit/s")
        }
    }

    TestCase {
        name: "NetworkProfileLookup"
        when: windowShown

        // NetworkManager renames a duplicate profile to "<name> 1", so the
        // profile name stops matching the SSID. Matching on name alone left
        // every such network looking unsaved, and each tap then asked for a
        // password / failed on a profile that actually existed.
        function test_parseProfileListMatchesSsidNotName() {
            var base = "Mate 40 Pro 1:uuid-a:802-11-wireless\n"
                + "Hasee-TA5NS:uuid-b:802-11-wireless\n"
                + "Mihomo:uuid-c:tun"
            // Real `nmcli -t -f …ssid,connection.uuid,…key-mgmt` output: one
            // "<field>:<value>" line per field, groups split by a blank line.
            var detail = "802-11-wireless.ssid:Mate 40 Pro\n"
                + "connection.uuid:uuid-a\n"
                + "802-11-wireless-security.key-mgmt:wpa-psk\n"
                + "\n"
                + "802-11-wireless.ssid:Hasee-TA5NS\n"
                + "connection.uuid:uuid-b\n"
                + "802-11-wireless-security.key-mgmt:sae\n"
                + "\n"
                + "connection.uuid:uuid-c\n"
            var result = Logic.parseProfileList(base, detail)
            verify(result.bySsid["Mate 40 Pro"] !== undefined, "saved by SSID")
            compare(result.bySsid["Mate 40 Pro"].name, "Mate 40 Pro 1")
            compare(result.bySsid["Mate 40 Pro"].uuid, "uuid-a")
            compare(result.bySsid["Mate 40 Pro"].keyMgmt, "wpa-psk")
            compare(result.bySsid["Hasee-TA5NS"].keyMgmt, "sae")
            verify(result.bySsid["Mihomo"] === undefined, "non-wireless profile is ignored")
            verify(result.byName["Mate 40 Pro 1"], "names are still indexed")
        }

        function test_parseProfileListIsOrderIndependent() {
            // Groups arriving in a different order must not cross profiles:
            // pairing rows by position did exactly that.
            var base = "Net A 1:uuid-a:802-11-wireless\nNet B 1:uuid-b:802-11-wireless"
            var forward = "802-11-wireless.ssid:Net A\nconnection.uuid:uuid-a\n"
                + "802-11-wireless-security.key-mgmt:wpa-psk\n\n"
                + "802-11-wireless.ssid:Net B\nconnection.uuid:uuid-b\n"
                + "802-11-wireless-security.key-mgmt:sae\n"
            var reversed = "802-11-wireless.ssid:Net B\nconnection.uuid:uuid-b\n"
                + "802-11-wireless-security.key-mgmt:sae\n\n"
                + "802-11-wireless.ssid:Net A\nconnection.uuid:uuid-a\n"
                + "802-11-wireless-security.key-mgmt:wpa-psk\n"
            var a = Logic.parseProfileList(base, forward).bySsid
            var b = Logic.parseProfileList(base, reversed).bySsid
            compare(a["Net A"].uuid, "uuid-a")
            compare(b["Net A"].uuid, "uuid-a")
            compare(a["Net B"].uuid, "uuid-b")
            compare(b["Net B"].uuid, "uuid-b")
        }

        function test_parseProfileListFallsBackToNames() {
            // A rejected detail call must not lose every saved network.
            var base = "HomeWifi:uuid-a:802-11-wireless"
            var result = Logic.parseProfileList(base, "")
            verify(result.bySsid["HomeWifi"] !== undefined)
            compare(result.bySsid["HomeWifi"].uuid, "uuid-a")
        }

        function test_parseProfileListFirstProfileWins() {
            var base = "Cafe:uuid-a:802-11-wireless\nCafe 1:uuid-b:802-11-wireless"
            var detail = "802-11-wireless.ssid:Cafe\nconnection.uuid:uuid-a\n"
                + "802-11-wireless-security.key-mgmt:wpa-psk\n\n"
                + "802-11-wireless.ssid:Cafe\nconnection.uuid:uuid-b\n"
                + "802-11-wireless-security.key-mgmt:wpa-psk\n"
            var result = Logic.parseProfileList(base, detail)
            compare(Object.keys(result.bySsid).length, 1)
            compare(result.bySsid["Cafe"].uuid, "uuid-a", "repeated scans must not flap")
        }

        function test_parseProfileListOpenProfileHasNoKeyMgmt() {
            var base = "OpenNet:uuid-a:802-11-wireless"
            var detail = "802-11-wireless.ssid:OpenNet\nconnection.uuid:uuid-a\n\n"
            var result = Logic.parseProfileList(base, detail)
            compare(result.bySsid["OpenNet"].keyMgmt, "")
        }

        function test_parseProfileDetailSkipsFieldlessGroups() {
            var rows = Logic.parseProfileDetail("connection.uuid:uuid-a\n\n\n")
            compare(rows.length, 1)
            compare(rows[0].uuid, "uuid-a")
            compare(rows[0].ssid, "")
        }

        function test_parseWifiListUsesProfileLookup() {
            var saved = { "Mate 40 Pro": { name: "Mate 40 Pro 1", uuid: "uuid-a" } }
            var map = Logic.parseWifiList("Mate 40 Pro:WPA2:60:130 Mbit/s:", saved)
            verify(map["Mate 40 Pro"].existing, "renamed profile still counts as saved")
            compare(map["Mate 40 Pro"].savedUuid, "uuid-a")
            compare(map["Mate 40 Pro"].savedName, "Mate 40 Pro 1")
        }
    }

    // The wired side: a profile is activated by tapping its row, so the panel
    // needs to know which port a profile belongs to, what addressing it will
    // hand out, and what each port's link is doing.
    TestCase {
        name: "NetworkWiredProfiles"
        when: windowShown

        // Verbatim shape of this machine's `nmcli -t … connection show` for the
        // two wired profiles that exist here: the direct-connect profile the
        // user needs (static, pinned to the spare port) and the DHCP one the
        // uplink is on.
        function wiredFixture() {
            return {
                base: "有线连接 1:uuid-dhcp:802-3-ethernet:enp117s0f3u1\n"
                    + "SDS804X-HD直连:uuid-static:802-3-ethernet:\n"
                    + "lo:uuid-lo:loopback:lo\n",
                detail: "connection.uuid:uuid-static\n"
                    + "connection.interface-name:enp2s0\n"
                    + "ipv4.method:manual\n"
                    + "ipv4.addresses:192.168.10.1/24\n"
                    + "connection.autoconnect:no\n"
                    + "\n"
                    + "connection.uuid:uuid-dhcp\n"
                    + "connection.interface-name:enp117s0f3u1\n"
                    + "ipv4.method:auto\n"
                    + "connection.autoconnect:yes\n"
                    + "\n"
                    + "connection.uuid:uuid-lo\n"
            }
        }

        function test_parseWiredProfilesReadsAddressing() {
            var f = wiredFixture()
            var profiles = Logic.parseWiredProfiles(f.base, f.detail)
            compare(profiles.length, 2, "only 802-3-ethernet profiles")
            var direct = profiles[0]
            compare(direct.name, "SDS804X-HD直连")
            compare(direct.uuid, "uuid-static")
            compare(direct.ifname, "enp2s0")
            compare(direct.method, "manual")
            compare(direct.addresses.length, 1)
            compare(direct.addresses[0], "192.168.10.1", "the prefix length is not part of the address")
            compare(direct.autoconnect, "no")
            var dhcp = profiles[1]
            compare(dhcp.method, "auto")
            compare(dhcp.addresses.length, 0, "a DHCP profile has no address until it is up")
        }

        // A rejected detail batch still names the profiles, which is enough to
        // activate one — losing the list would take the only way back.
        function test_parseWiredProfilesSurvivesARejectedDetailCall() {
            var f = wiredFixture()
            compare(Logic.parseWiredProfiles(f.base, "").length, 0)
            // The base listing alone carries no uuid detail, so the fallback the
            // service uses is the wireless name path; here the point is that
            // empty input is empty output rather than a throw.
            compare(Logic.parseWiredProfiles("", "").length, 0)
            compare(Logic.parseWiredProfiles(null, null).length, 0)
        }

        function test_splitAddresses() {
            compare(Logic.splitAddresses("192.168.10.1/24"), ["192.168.10.1"])
            compare(Logic.splitAddresses("10.0.0.2/24, 10.0.0.1/24"),
                ["10.0.0.2", "10.0.0.1"])
            compare(Logic.splitAddresses(""), [])
            compare(Logic.splitAddresses("--"), [])
            compare(Logic.splitAddresses(null), [])
        }

        function test_ipMethodLabel() {
            compare(Logic.ipMethodLabel("auto"), "DHCP")
            compare(Logic.ipMethodLabel(""), "DHCP")
            compare(Logic.ipMethodLabel("AUTO"), "DHCP")
            compare(Logic.ipMethodLabel("manual"), "Manual")
            compare(Logic.ipMethodLabel("link-local"), "Link-local")
            compare(Logic.ipMethodLabel("disabled"), "Disabled")
            compare(Logic.ipMethodLabel("weird-value"), "weird-value")
        }

        // The device table is one self-describing block per device; every line
        // names its own field, so an absent optional field is not a shift.
        function test_parseDeviceTableReadsLinkAndAddressing() {
            var text = "GENERAL.DEVICE:enp117s0f3u1\n"
                + "GENERAL.TYPE:ethernet\n"
                + "GENERAL.STATE:100 (connected)\n"
                + "GENERAL.REASON:0 (No reason given)\n"
                + "GENERAL.CONNECTION:有线连接 1\n"
                + "GENERAL.CON-UUID:uuid-dhcp\n"
                + "WIRED-PROPERTIES.CARRIER:on\n"
                + "IP4.ADDRESS[1]:192.168.42.82/24\n"
                + "IP4.GATEWAY:192.168.42.129\n"
                + "IP4.DNS[1]:192.168.42.129\n"
                + "IP6.ADDRESS[1]:fe80::9dc8:28ff:5b5:cc64/64\n"
                + "\n"
                + "GENERAL.DEVICE:wlo1\n"
                + "GENERAL.TYPE:wifi\n"
                + "GENERAL.STATE:100 (connected)\n"
                + "GENERAL.CONNECTION:光电科技协会 1\n"
                + "GENERAL.CON-UUID:uuid-wifi\n"
                + "IP4.ADDRESS[1]:192.168.1.132/24\n"
                + "IP4.GATEWAY:192.168.1.1\n"
                + "\n"
                + "GENERAL.DEVICE:enp2s0\n"
                + "GENERAL.TYPE:ethernet\n"
                + "GENERAL.STATE:30 (disconnected)\n"
                + "GENERAL.REASON:40 (Carrier/link changed)\n"
                + "GENERAL.CONNECTION:\n"
                + "GENERAL.CON-UUID:\n"
                + "WIRED-PROPERTIES.CARRIER:off\n"
            var devices = Logic.parseDeviceTable(text)
            compare(devices.length, 3)
            compare(devices[0].device, "enp117s0f3u1")
            verify(devices[0].connected)
            compare(devices[0].uuid, "uuid-dhcp",
                "the running connection's uuid is the only reliable disconnect handle")
            compare(devices[0].ip4[0], "192.168.42.82")
            compare(devices[0].gateway, "192.168.42.129")
            compare(devices[0].dns[0], "192.168.42.129")
            compare(devices[0].carrier, "on")
            // A connection name that is empty in one form and "--" in another
            // means the same thing.
            compare(devices[2].connection, "")
            compare(devices[2].uuid, "")
            compare(devices[2].carrier, "off")
            verify(!devices[2].connected)
            // A block with no GENERAL.DEVICE line is not a device.
            compare(Logic.parseDeviceTable("IP4.GATEWAY:1.2.3.4\n").length, 0)
            compare(Logic.parseDeviceTable("").length, 0)
            compare(Logic.parseDeviceTable(null).length, 0)
        }

        function test_linkStateLabel() {
            verify(Logic.linkStateLabel(null).text === "")
            compare(Logic.linkStateLabel({ connected: true, carrier: "on" }).text, "Connected")
            compare(Logic.linkStateLabel({ connected: false, carrier: "off" }).text, "No cable")
            compare(Logic.linkStateLabel({
                connected: false, carrier: "on", reason: "0 (No reason given)"
            }).text, "Disconnected")
            compare(Logic.linkStateLabel({
                connected: false, carrier: "", reason: "40 (Carrier/link changed)"
            }).text, "No cable")
            // Only an explicit false is a claim about management; a caller that
            // never computed the flag must not make a live port read as
            // unmanageable.
            compare(Logic.linkStateLabel({
                connected: true, carrier: "on", managed: false
            }).text, "Not managed")
            compare(Logic.linkStateLabel({ connected: true, carrier: "on" }).text,
                "Connected")
        }

        // The state this machine actually reports for enp2s0: NM holds the
        // profile up, the kernel says there is no link. Reading that as
        // "Connected" is how a panel tells the user a cable is fine when it is
        // not.
        function test_linkStateLabelPrefersCarrierOverNmsConnected() {
            compare(Logic.linkStateLabel({
                connected: true, carrier: "off", connection: "SDS804X-HD直连"
            }).text, "No cable")
            compare(Logic.linkStateLabel({
                connected: true, carrier: "off"
            }).tone, "idle", "a port with no link is not an active link")
        }

        // The leash on an activation, and why it is not NM's own number: NM
        // queues a no-cable activation for carrier-wait-timeout (120s), so the
        // panel needs its own bound, and a much tighter one when nothing is
        // plugged in.
        function test_wiredActivationTimeout() {
            compare(Logic.wiredActivationTimeout("off"), 4000)
            compare(Logic.wiredActivationTimeout("on"), 30000)
            // An unreported carrier is not a claim that there is no cable.
            compare(Logic.wiredActivationTimeout(""), 30000)
            compare(Logic.wiredActivationTimeout(undefined), 30000)
            verify(Logic.wiredActivationTimeout("off") < Logic.wiredActivationTimeout("on"))
        }

        // Grouping is what turns two independent reads into rows the user can
        // act on: each profile must land under the port it belongs to.
        function test_groupWiredProfilesPlacesEachProfileOnItsPort() {
            var f = wiredFixture()
            var devices = [
                { device: "enp117s0f3u1", type: "ethernet", managed: true, connected: true,
                  carrier: "on", connection: "有线连接 1", uuid: "uuid-dhcp",
                  ip4: ["192.168.42.82"] },
                { device: "enp2s0", type: "ethernet", managed: true, connected: false,
                  carrier: "off", reason: "40 (Carrier/link changed)", connection: "",
                  uuid: "", ip4: [] }
            ]
            var groups = Logic.groupWiredProfiles(devices,
                Logic.parseWiredProfiles(f.base, f.detail))
            compare(groups.length, 2, "one group per wired port")
            compare(groups[0].device, "enp117s0f3u1")
            compare(groups[0].profiles.length, 1)
            compare(groups[0].profiles[0].uuid, "uuid-dhcp")
            verify(groups[0].profiles[0].active, "the running profile is marked active")
            compare(groups[0].ip4, "192.168.42.82")
            compare(groups[1].device, "enp2s0")
            compare(groups[1].profiles.length, 1)
            compare(groups[1].profiles[0].name, "SDS804X-HD直连")
            verify(!groups[1].profiles[0].active)
            verify(!groups[1].profiles[0].stalePin, "the pin names a port that exists")
            compare(groups[1].profiles[0].addresses[0], "192.168.10.1")
        }

        function test_groupWiredProfilesCollectsDeadPins() {
            // A profile pinned to a port that is gone must still be visible —
            // the user cannot delete what they cannot see — and must be marked
            // so the panel can refuse the tap instead of eating a refusal.
            var devices = [
                { device: "enp2s0", type: "ethernet", managed: true, connected: false,
                  carrier: "off", connection: "", uuid: "", ip4: [] }
            ]
            var profiles = [{
                uuid: "uuid-static", name: "SDS804X-HD直连", ifname: "enp9s9",
                method: "manual", addresses: ["192.168.10.1"]
            }]
            var groups = Logic.groupWiredProfiles(devices, profiles)
            compare(groups.length, 2, "the orphan lands in its own trailing group")
            compare(groups[1].device, "")
            verify(groups[1].profiles[0].stalePin)
        }

        // Unmanaged ports are not the user's to configure, and a wireless
        // device must never appear in the wired list.
        function test_groupWiredProfilesSkipsUnmanagedAndWireless() {
            var devices = [
                { device: "wlo1", type: "wifi", managed: true, connected: true,
                  uuid: "uuid-wifi", ip4: ["192.168.1.132"] },
                { device: "enp3s0", type: "ethernet", managed: false, connected: false,
                  carrier: "on", uuid: "", ip4: [] }
            ]
            compare(Logic.groupWiredProfiles(devices, []).length, 0)
            // A device row that never computed the flag is still a port.
            compare(Logic.groupWiredProfiles(
                [{ device: "enp4s0", type: "ethernet", connected: false, uuid: "", ip4: [] }],
                []).length, 1)
        }

        function test_activeLinkDetailsPrefersWired() {
            var devices = [
                { device: "wlo1", type: "wifi", managed: true, connected: true,
                  connection: "光电科技协会 1", uuid: "uuid-wifi",
                  ip4: ["192.168.1.132"], gateway: "192.168.1.1", dns: ["1.1.1.1"] },
                { device: "enp117s0f3u1", type: "ethernet", managed: true, connected: true,
                  connection: "有线连接 1", uuid: "uuid-dhcp",
                  ip4: ["192.168.42.82"], gateway: "192.168.42.129", dns: ["192.168.42.129"] }
            ]
            var details = Logic.activeLinkDetails(devices)
            compare(details.device, "enp117s0f3u1")
            compare(details.ip4, "192.168.42.82")
            compare(details.gateway, "192.168.42.129")
            compare(details.dns.length, 1)
            // With only the wireless link up, that is the link described.
            compare(Logic.activeLinkDetails([devices[0]]).device, "wlo1")
            // Nothing up: an empty claim, not a stale address from a link that
            // went away.
            var none = Logic.activeLinkDetails([])
            compare(none.device, "")
            compare(none.ip4, "")
            compare(none.dns.length, 0)
        }

        // A direct-connect instrument link has no gateway by design, and its
        // address is the thing the user is checking — so it still wins when it
        // is the only wired link up, and answers "—" for a gateway it does not
        // have rather than borrowing the wireless link's.
        function test_activeLinkDetailsKeepsAGatewaylessWiredLink() {
            var devices = [
                { device: "wlo1", type: "wifi", managed: true, connected: true,
                  connection: "光电科技协会 1", uuid: "uuid-wifi",
                  ip4: ["192.168.1.132"], gateway: "192.168.1.1", dns: ["1.1.1.1"] },
                { device: "enp2s0", type: "ethernet", managed: true, connected: true,
                  connection: "SDS804X-HD直连", uuid: "uuid-static",
                  ip4: ["192.168.10.1"], gateway: "", dns: [] }
            ]
            var details = Logic.activeLinkDetails(devices)
            compare(details.device, "enp2s0")
            compare(details.ip4, "192.168.10.1")
            compare(details.gateway, "", "a link with no gateway has none to show")
            compare(details.dns.length, 0)
        }

        // With a wired uplink AND a wired instrument up, "the address" means the
        // routable one.
        function test_activeLinkDetailsPrefersTheRoutableWiredLink() {
            var devices = [
                { device: "enp2s0", type: "ethernet", managed: true, connected: true,
                  connection: "SDS804X-HD直连", uuid: "uuid-static",
                  ip4: ["192.168.10.1"], gateway: "", dns: [] },
                { device: "enp117s0f3u1", type: "ethernet", managed: true, connected: true,
                  connection: "有线连接 1", uuid: "uuid-dhcp",
                  ip4: ["192.168.42.82"], gateway: "192.168.42.129", dns: ["192.168.42.129"] }
            ]
            var details = Logic.activeLinkDetails(devices)
            compare(details.device, "enp117s0f3u1")
            compare(details.ip4, "192.168.42.82")
        }

        function test_profileAddressText() {
            compare(Logic.profileAddressText({ addresses: ["192.168.10.1"] }), "192.168.10.1")
            compare(Logic.profileAddressText({ addresses: [] }), "DHCP")
            compare(Logic.profileAddressText(null), "")
        }
    }

    TestCase {
        name: "NetworkSecurity"
        when: windowShown

        function test_securityKeyFor() {
            compare(Logic.securityKeyFor(""), "open")
            compare(Logic.securityKeyFor("--"), "open")
            compare(Logic.securityKeyFor("OPEN"), "open")
            compare(Logic.securityKeyFor("WPA2"), "wpa-psk")
            compare(Logic.securityKeyFor("WPA1 WPA2"), "wpa-psk")
            compare(Logic.securityKeyFor("WPA2 WPA3"), "wpa-psk")
            compare(Logic.securityKeyFor("SAE"), "sae")
            compare(Logic.securityKeyFor("WEP"), "wep")
        }

        function test_isEnterprise() {
            verify(Logic.isEnterprise("WPA2 802.1X"))
            verify(Logic.isEnterprise("WPA2 ENT"))
            verify(Logic.isEnterprise("WPA2 EAP"))
            verify(!Logic.isEnterprise("WPA2 WPA3"))
            verify(!Logic.isEnterprise(""))
            verify(!Logic.isEnterprise(undefined))
        }

        function test_isEnterpriseKeyMgmt() {
            verify(Logic.isEnterpriseKeyMgmt("802-1x"))
            verify(Logic.isEnterpriseKeyMgmt("wpa-eap"))
            verify(!Logic.isEnterpriseKeyMgmt("wpa-psk"))
            verify(!Logic.isEnterpriseKeyMgmt(""))
        }

        function test_isSecured() {
            verify(Logic.isSecured("WPA2"))
            verify(Logic.isSecured("WPA2 WPA3"))
            verify(!Logic.isSecured("--"))
            verify(!Logic.isSecured(""))
            verify(!Logic.isSecured("open"))
            verify(!Logic.isSecured(undefined))
        }
    }

    TestCase {
        name: "NetworkConnectPlan"
        when: windowShown

        function test_planActivatesSavedProfile() {
            compare(Logic.connectPlan({ uuid: "u", name: "n" }, false), "activate")
        }

        function test_planModifiesSavedProfileWithRetypedSecret() {
            compare(Logic.connectPlan({ uuid: "u", name: "n" }, true), "modify")
        }

        function test_planCreatesForUnknownNetwork() {
            compare(Logic.connectPlan(null, false), "create")
            compare(Logic.connectPlan(null, true), "create")
        }

        function test_activateArgsTargetsUuid() {
            // By uuid, never by name: a " 1" suffixed name is the real profile.
            var args = Logic.activateArgs("uuid-a", "wlo1")
            compare(args.join(" "), "connection up uuid uuid-a ifname wlo1")
        }

        function test_modifyArgsKeepsKeyMgmt() {
            // Forcing key-mgmt to wpa-psk would downgrade a WPA3 (SAE) profile.
            var args = Logic.modifyArgs("uuid-a", "hunter2")
            compare(args.join(" "),
                "connection modify uuid uuid-a 802-11-wireless-security.psk hunter2")
        }

        function test_createArgsCarriesEveryInput() {
            compare(Logic.createArgs("Cafe", "pw", true, "wlo1").join(" "),
                "device wifi connect Cafe password pw hidden yes ifname wlo1")
            compare(Logic.createArgs("OpenNet", "", false, "").join(" "),
                "device wifi connect OpenNet")
        }

        // The disconnect regression, stated as an argv shape: this machine's
        // connected SSID is "光电科技协会" while its profile is named
        // "光电科技协会 1", so `connection down id <ssid>` names a connection
        // that does not exist and the tap did nothing at all.
        function test_downArgsTargetsUuidNotTheSsid() {
            compare(Logic.downArgs("uuid-a", true).join(" "),
                "connection down uuid uuid-a")
            compare(Logic.downArgs("光电科技协会 1", false).join(" "),
                "connection down id 光电科技协会 1")
        }

        // An unresolvable handle must run nothing: `nmcli` would report success
        // and the link would stay up.
        function test_downArgsRefusesAnEmptyHandle() {
            compare(Logic.downArgs("", true).join(" "), "true")
            compare(Logic.downArgs(null, true).join(" "), "true")
        }

        function test_upArgsTargetsTheProfileUuidAlone() {
            // No ifname: a profile that is already pinned carries that pin, and
            // passing a mismatched one is the refusal this whole path exists to
            // avoid.
            compare(Logic.upArgs("uuid-static").join(" "),
                "connection up uuid uuid-static")
            compare(Logic.upArgs("").join(" "), "true")
            compare(Logic.upArgs(null).join(" "), "true")
        }
    }

    TestCase {
        name: "NetworkErrorMessages"
        when: windowShown

        // nmcli runs under LC_ALL=C in the service, so these needles are the
        // English strings it actually emits.
        function test_classifyCredentialFailure() {
            compare(Logic.classifyConnectError(
                "Error: Connection activation failed: Secrets were required, but not provided."),
            "Incorrect password")
            compare(Logic.classifyConnectError("Error: 4-IP address already assigned"),
            "4-IP address already assigned", "unmatched reasons pass through verbatim")
        }

        function test_classifyEnterprise() {
            compare(Logic.classifyConnectError(
                "Error: Connection activation failed: 802.1X supplicant took too long to respond."),
            "Enterprise (EAP) network — not supported")
        }

        function test_classifyMissingNetwork() {
            compare(Logic.classifyConnectError("Error: No network with SSID 'ZZZ' found."),
            "Network not found")
        }

        function test_classifyTimeout() {
            compare(Logic.classifyConnectError("Error: Connection activation timed out"),
            "Connection timeout")
        }

        function test_classifyUnknownConnection() {
            compare(Logic.classifyConnectError("Error: unknown connection 'MIFI-D9AD'."),
            "Saved profile is gone")
        }

        // A port with no cable is the failure a wired tap is most likely to
        // hit, and the one NetworkManager's own message does not name well.
        function test_classifyCarrierFailure() {
            compare(Logic.classifyConnectError(
                "Error: Connection activation failed: Carrier not present."),
            "No cable on this port")
            compare(Logic.classifyConnectError("Error: device has no carrier"),
            "No cable on this port")
        }

        // The dead-pin refusal a wired profile produces when its port is gone.
        function test_classifyMismatchedInterfaceName() {
            compare(Logic.classifyConnectError(
                "Error: Connection activation failed: "
                + "device 'enp2s0' is not compatible with profile 'SDS804X-HD直连'"),
            "No adapter matches this saved profile")
        }

        function test_classifySkipsWarningLines() {
            compare(Logic.classifyConnectError(
                "Warning: password for '802-11-wireless-security.psk' not given in 'passwd-file'\n"
                + "Error: Connection activation failed: No key available."),
            "Incorrect password")
        }

        function test_classifyTruncatesLongReason() {
            var message = Logic.classifyConnectError(
                "Error: " + new Array(200).join("x"))
            verify(message.length <= 72, "long reasons are trimmed, got " + message.length)
        }

        function test_classifyEmptyFallsBack() {
            compare(Logic.classifyConnectError(""), "Connection failed")
            compare(Logic.classifyConnectError("   "), "Connection failed")
        }

        function test_isCredentialFailure() {
            verify(Logic.isCredentialFailure("Incorrect password"))
            verify(!Logic.isCredentialFailure("Network not found"))
            verify(!Logic.isCredentialFailure(""))
        }
    }

    TestCase {
        name: "NetworkSignal"
        when: windowShown

        function test_signalLabelLadder() {
            compare(Logic.signalLabel(100), "Excellent")
            compare(Logic.signalLabel(80), "Excellent")
            compare(Logic.signalLabel(60), "Good")
            compare(Logic.signalLabel(35), "Fair")
            compare(Logic.signalLabel(15), "Poor")
            compare(Logic.signalLabel(0), "Weak")
        }

        function test_signalIconLadderIsMonotonic() {
            var rungs = [95, 70, 45, 20, 5].map(function (s) { return Logic.signalIcon(s, false, "full") })
            for (var i = 1; i < rungs.length; i++)
                verify(rungs[i] !== rungs[i - 1], "rung " + i + " repeats the previous glyph")
        }

        function test_signalIconFlagsLimitedConnectivity() {
            compare(Logic.signalIcon(90, true, "limited"), "")
            compare(Logic.signalIcon(90, true, "portal"), "")
            compare(Logic.signalIcon(90, true, "full"), Logic.signalIcon(90, false, "full"))
        }
    }
}
