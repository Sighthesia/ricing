import QtQuick
import QtTest
import "../../services/volume/VolumeLogic.js" as Logic

// Unit-test the pure plumbing behind the volume panel's device pickers and
// application mixer.
//
// The payloads below are copied verbatim from a live PipeWire 1.6.9 /
// WirePlumber 1.6.9 session on this machine, including the parts that are easy
// to get wrong: pulse and pipewire numbering genuinely differ (`Sink Input
// #1351` is pipewire node 112), the sink a sink-input reports is an index into
// pulse's own numbering, and pactl's JSON collapses a non-ASCII `media.name` to
// "(null)". Nothing here may be satisfied by a plausible-looking fixture that
// the real output would not produce.
Item {
    id: root

    // Real `pactl -f json list sink-inputs` output, one Firefox stream.
    readonly property string realSinkInputs: '[{"index":1351,"driver":"PipeWire","owner_module":null,'
        + '"client":"104","sink":699,"sample_specification":"float32le 2ch 48000Hz",'
        + '"channel_map":"front-left,front-right","format":"pcm","corked":false,"mute":false,'
        + '"volume":{"front-left":{"value":32768,"value_percent":"50%","db":"-18.06 dB"}},'
        + '"balance":0.00,"buffer_latency_usec":0.00,"sink_latency_usec":0.00,'
        + '"resample_method":"PipeWire","properties":{"client.api":"pipewire-pulse",'
        + '"application.name":"Firefox","application.process.id":"16491",'
        + '"module-stream-restore.id":"sink-input-by-application-name:Firefox",'
        + '"media.name":"(null)","pulse.corked":"false","node.name":"Firefox",'
        + '"media.class":"Stream/Output/Audio","port.group":"stream.0",'
        + '"client.id":"89","object.id":"112","object.serial":"1351"}}]'

    // Real `pactl -f json list sinks` output. Note 56 and 699 here, against
    // pipewire node ids 56 and 73 for the same two devices.
    readonly property string realSinks: '[{"name":"alsa_output.pci-0000_74_00.6.HiFi__Speaker__sink",'
        + '"index":56,"driver":"PipeWire","flags":[]},'
        + '{"name":"bluez_output.94_29_57_00_B0_49.1","index":699,"driver":"PipeWire","flags":[]}]'

    function joined() {
        return root.realSinkInputs + "\n" + Logic.ROUTE_SECTION_MARKER + "\n" + root.realSinks
    }

    TestCase {
        name: "StreamClassification"
        when: windowShown

        function test_playbackStreamIsRecognised() {
            var node = Qt.createQmlObject('import QtQuick; QtObject { property bool isStream: true;'
                + ' property bool isSink: true; property var audio: ({}) }', root, "playback")
            verify(Logic.isPlaybackStream(node))
        }

        function test_captureStreamIsNotAnOutputMixerRow() {
            // Measured live: a recording stream is `isStream && !isSink`. It
            // belongs with the input device, never in the output mixer.
            var node = Qt.createQmlObject('import QtQuick; QtObject { property bool isStream: true;'
                + ' property bool isSink: false; property var audio: ({}) }', root, "capture")
            verify(!Logic.isPlaybackStream(node))
        }

        function test_hardwareSinkIsNotAnApplication() {
            var node = Qt.createQmlObject('import QtQuick; QtObject { property bool isStream: false;'
                + ' property bool isSink: true; property var audio: ({}) }', root, "hardwareSink")
            verify(!Logic.isPlaybackStream(node))
        }

        function test_mediaClassOutranksIsSink() {
            // A node whose properties HAVE landed is classified by
            // `media.class`, so a mislabelled `isSink` cannot smuggle a capture
            // stream into the output mixer.
            var node = Qt.createQmlObject('import QtQuick; QtObject { property bool isStream: true;'
                + ' property bool isSink: true; property var audio: ({});'
                + ' property var properties: ({ "media.class": "Stream/Input/Audio" }) }',
                root, "mislabelled")
            verify(!Logic.isPlaybackStream(node))
        }

        function test_unboundNodeFallsBackToIsSink() {
            // `properties` is invalid until the node is bound, so an early read
            // must not classify every stream out of the mixer.
            var node = Qt.createQmlObject('import QtQuick; QtObject { property bool isStream: true;'
                + ' property bool isSink: true; property var audio: ({});'
                + ' property var properties: ({}) }', root, "unbound")
            verify(Logic.isPlaybackStream(node))
        }

        function test_nodeWithoutAudioIsNotAStream() {
            var node = Qt.createQmlObject('import QtQuick; QtObject { property bool isStream: true;'
                + ' property bool isSink: true; property var audio: null }', root, "noAudio")
            verify(!Logic.isPlaybackStream(node))
        }

        function test_theShellIsNeverItsOwnMixerRow() {
            var node = Qt.createQmlObject('import QtQuick; QtObject { property bool isStream: true;'
                + ' property bool isSink: true; property var audio: ({});'
                + ' property var properties: ({ "media.class": "Stream/Output/Audio",'
                + ' "application.name": "quickshell" }) }', root, "shell")
            verify(Logic.isShellStream(node))
        }

        function test_aRealApplicationIsNotFiltered() {
            var node = Qt.createQmlObject('import QtQuick; QtObject { property bool isStream: true;'
                + ' property bool isSink: true; property var audio: ({});'
                + ' property var properties: ({ "media.class": "Stream/Output/Audio",'
                + ' "application.name": "Firefox" }) }', root, "firefox")
            verify(!Logic.isShellStream(node))
        }
    }

    TestCase {
        name: "RouteTableParsing"
        when: windowShown

        function test_splitsTheTwoDocuments() {
            var sections = Logic.splitSections(root.joined())
            verify(sections !== null)
            verify(sections.sinkInputs.indexOf("1351") !== -1)
            verify(sections.sinks.indexOf("bluez_output") !== -1)
        }

        function test_missingMarkerIsNotSilentlyAnEmptyTable() {
            // An empty table reads as "every app follows the default device",
            // which is a wrong claim rather than a stale one - so a payload
            // without the marker must report failure, not `{}`.
            compare(Logic.splitSections("[]"), null)
        }

        function test_parsesTheRealPayload() {
            var sections = Logic.splitSections(root.joined())
            var routes = Logic.parseStreamRoutes(sections.sinkInputs, sections.sinks)
            verify(routes !== null)
            compare(Object.keys(routes).length, 1)
            var route = Logic.routeFor(routes, 112)
            verify(route !== null)
            // The join that makes this feature possible at all: pulse says
            // 1351, pipewire says 112, and the row is a pipewire node.
            compare(route.pulseIndex, 1351)
            compare(route.sinkIndex, 699)
            compare(route.sinkName, "bluez_output.94_29_57_00_B0_49.1")
        }

        function test_joinsByNodeIdNotByApplicationName() {
            // Two streams from one application, which is the ordinary case for
            // a browser. Matching on `application.name` would hand both rows the
            // same route; matching on node id keeps them separate.
            var inputs = '[{"index":1351,"sink":699,"properties":{"application.name":"Firefox",'
                + '"media.name":"Song A","object.id":"112"}},'
                + '{"index":1402,"sink":56,"properties":{"application.name":"Firefox",'
                + '"media.name":"Song B","object.id":"117"}}]'
            var sinks = '[{"name":"bluez_output.94_29_57_00_B0_49.1","index":699},'
                + '{"name":"alsa_output.pci-0000_74_00.6.HiFi__Speaker__sink","index":56}]'
            var routes = Logic.parseStreamRoutes(inputs, sinks)
            compare(Object.keys(routes).length, 2)
            compare(Logic.routeFor(routes, 112).sinkName, "bluez_output.94_29_57_00_B0_49.1")
            compare(Logic.routeFor(routes, 117).sinkName, "alsa_output.pci-0000_74_00.6.HiFi__Speaker__sink")
        }

        function test_unknownNodeIdHasNoRoute() {
            var routes = Logic.parseStreamRoutes(root.realSinkInputs, root.realSinks)
            // A stream that appeared after the read must read as "unknown", not
            // as the device some other row happens to be on.
            compare(Logic.routeFor(routes, 999), null)
            compare(Logic.routeFor(null, 112), null)
        }

        function test_malformedPayloadIsRejectedRatherThanEmptied() {
            compare(Logic.parseStreamRoutes("not json", root.realSinks), null)
            compare(Logic.parseStreamRoutes(root.realSinkInputs, "{"), null)
            // A genuinely empty list is the one case that may publish empty.
            compare(Object.keys(Logic.parseStreamRoutes("[]", "[]")).length, 0)
        }

        function test_entryWithoutObjectIdIsSkippedNotGuessed() {
            var inputs = '[{"index":1351,"sink":699,"properties":{"application.name":"Firefox"}}]'
            var routes = Logic.parseStreamRoutes(inputs, root.realSinks)
            // Without the join key there is no safe answer, so the entry is
            // dropped rather than matched by name.
            compare(Object.keys(routes).length, 0)
        }
    }

    TestCase {
        name: "RowLabelsAndLevels"
        when: windowShown

        function test_appNamePrefersTheApplicationOverTheNodeName() {
            var node = Qt.createQmlObject('import QtQuick; QtObject { property string name: "firefox";'
                + ' property var properties: ({ "application.name": "Firefox",'
                + ' "media.name": "Tune" }) }', root, "labels")
            compare(Logic.streamAppName(node), "Firefox")
            compare(Logic.streamMediaName(node), "Tune")
        }

        function test_appNameFallsBackToTheNodeName() {
            var node = Qt.createQmlObject('import QtQuick; QtObject { property string name: "pw-cat";'
                + ' property var properties: ({}) }', root, "fallback")
            compare(Logic.streamAppName(node), "pw-cat")
        }

        function test_pactlNullMediaNameIsNotShownAsText() {
            // pactl's JSON prints a non-ASCII media name as the literal string
            // "(null)"; surfacing that would put "(null)" on a mixer row.
            var node = Qt.createQmlObject('import QtQuick; QtObject { property string name: "Firefox";'
                + ' property var properties: ({ "media.name": "(null)",'
                + ' "media.title": "Real Title" }) }', root, "nullMedia")
            compare(Logic.streamMediaName(node), "Real Title")
        }

        function test_idleStreamShowsNoMediaLine() {
            var node = Qt.createQmlObject('import QtQuick; QtObject { property string name: "Firefox";'
                + ' property var properties: ({ "application.name": "Firefox" }) }', root, "idle")
            compare(Logic.streamMediaName(node), "")
        }

        function test_levelIsClampedFromTheRawPipewireValue() {
            // A live source was sitting at 1.5; an unbounded read would push a
            // 0..1 slider past its end.
            var loud = Qt.createQmlObject('import QtQuick; QtObject { property var audio: ({ volume: 1.5 }) }', root, "loud")
            compare(Logic.streamLevel(loud), 1)
            var quiet = Qt.createQmlObject('import QtQuick; QtObject { property var audio: ({ volume: -1 }) }', root, "quiet")
            compare(Logic.streamLevel(quiet), 0)
        }

        function test_deadNodeDoesNotProduceNaN() {
            compare(Logic.streamLevel(null), 0)
            compare(Logic.streamMuted(null), true)
            var broken = Qt.createQmlObject('import QtQuick; QtObject { property var audio: ({ volume: "x" }) }', root, "broken")
            compare(Logic.streamLevel(broken), 0)
        }

        function test_sinkLabelPrefersTheDeviceDescription() {
            // The same name has to read identically in the mixer chip and in the
            // device list above it, so both resolve through the device list.
            var devices = [{ name: "bluez_output.94_29_57_00_B0_49.1", description: "TimeEar BTE-9" }]
            compare(Logic.sinkLabel("bluez_output.94_29_57_00_B0_49.1", devices), "TimeEar BTE-9")
        }

        function test_sinkLabelFallsBackToTheRawName() {
            var devices = [{ name: "alsa_output.pci-0000_74_00.6.HiFi__Speaker__sink", description: "" }]
            compare(Logic.sinkLabel("alsa_output.pci-0000_74_00.6.HiFi__Speaker__sink", devices),
                "alsa_output.pci-0000_74_00.6.HiFi__Speaker__sink")
            compare(Logic.sinkLabel("", devices), "")
        }
    }

    TestCase {
        name: "SharedDeviceNamePrefix"
        when: windowShown

        function test_hoistsTheHardwareCardNameOutOfEveryRow() {
            // Verbatim from this machine. Three rows all began "Ryzen HD Audio
            // Controller", which pushed the only words that tell them apart off
            // the end of each row - the panel showed three rows that all read the
            // same and were all elided at the same place.
            compare(Logic.sharedLabelPrefix([
                "Ryzen HD Audio Controller Speaker",
                "TimeEar BTE-9"
            ]), "", "unrelated names share nothing")

            compare(Logic.sharedLabelPrefix([
                "Ryzen HD Audio Controller Stereo Microphone",
                "Ryzen HD Audio Controller Digital Microphone"
            ]), "Ryzen HD Audio Controller")
        }

        function test_trimsOnlyTheSharedRun() {
            var prefix = Logic.sharedLabelPrefix([
                "Ryzen HD Audio Controller Stereo Microphone",
                "Ryzen HD Audio Controller Digital Microphone"
            ])
            compare(Logic.trimLabelPrefix("Ryzen HD Audio Controller Stereo Microphone", prefix),
                "Stereo Microphone")
            compare(Logic.trimLabelPrefix("Ryzen HD Audio Controller Digital Microphone", prefix),
                "Digital Microphone")
        }

        function test_aRowOutsideTheSharedRunKeepsItsWholeName() {
            // A list of three where only two share a prefix: the third must not be
            // mangled by a prefix it has nothing to do with.
            var labels = [
                "Ryzen HD Audio Controller Stereo Microphone",
                "Ryzen HD Audio Controller Digital Microphone",
                "TimeEar BTE-9"
            ]
            var prefix = Logic.sharedLabelPrefix(labels)
            compare(prefix, "Ryzen HD Audio Controller")
            compare(Logic.trimLabelPrefix(labels[2], prefix), "TimeEar BTE-9")
        }

        function test_nothingIsHoistedForOneRow() {
            // A single device has nothing to disambiguate against, so hoisting
            // would strip its only identifying words for no gain.
            compare(Logic.sharedLabelPrefix(["Ryzen HD Audio Controller Speaker"]), "")
            compare(Logic.trimLabelPrefix("Ryzen HD Audio Controller Speaker", ""),
                "Ryzen HD Audio Controller Speaker")
        }

        function test_aPrefixThatConsumesARowIsRejected() {
            // If trimming would leave one row blank, the whole hoist is refused -
            // an empty row is worse than a repeated prefix.
            compare(Logic.sharedLabelPrefix(["Radeon HD Audio", "Radeon HD Audio"]), "")
            // Same reason, reached a different way: two rows are literally the
            // prefix and a third extends it.
            compare(Logic.sharedLabelPrefix(["Razer", "Razer", "Razer Naga"]), "")
        }

        function test_oneSharedWordIsNotEnoughForAMajority() {
            // Three unrelated devices that happen to share one word. The run they
            // do share ("Mic Input") is the whole of two rows, so hoisting it
            // would leave those rows nameless and the header would repeat what
            // the rows already say. Refused.
            compare(Logic.sharedLabelPrefix(["Mic Input", "Mic Input", "Line Input"]), "")
            // Every row carries this one and it consumes none of them, so it does
            // earn its place.
            compare(Logic.sharedLabelPrefix(["Razer Naga", "Razer Viper"]), "Razer")
        }

        function test_aRunOnlyOneLabelCarriesIsNotAPrefix() {
            // "Ryzen HD Audio Controller Speaker" and "TimeEar BTE-9" have a long
            // run in common in the trivial sense that the first label is entirely
            // made of it - and hoisting it would leave one row blank while
            // inventing a hardware scope the second device has nothing to do with.
            compare(Logic.sharedLabelPrefix(["Ryzen HD Audio Controller Speaker", "TimeEar BTE-9"]), "")
        }

        function test_partialWordOverlapIsNotAPrefix() {
            // "Mic" and "Microphone" share three letters but not a word; cutting
            // mid-word would produce nonsense labels.
            compare(Logic.sharedLabelPrefix(["Mic Input", "Microphone Input"]), "")
        }

        function test_trailingPunctuationIsNotCarriedIntoTheHeader() {
            compare(Logic.sharedLabelPrefix(["Razer - BlackWidow", "Razer - Naga"]), "Razer")
            compare(Logic.trimLabelPrefix("Razer - Naga", "Razer"), "Naga")
        }

        function test_emptyAndBlankInputsAreSafe() {
            compare(Logic.sharedLabelPrefix([]), "")
            compare(Logic.sharedLabelPrefix(null), "")
            compare(Logic.sharedLabelPrefix(["", "  "]), "")
            compare(Logic.trimLabelPrefix("", "Razer"), "")
            compare(Logic.trimLabelPrefix("Razer Naga", null), "Razer Naga")
        }
    }
}