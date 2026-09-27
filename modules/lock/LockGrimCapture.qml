import Quickshell.Io

// Capture one screen with grim into a per-generation JPEG, then report the
// file URL (or nothing on failure) once before destroying the wrapper.
// JPEG keeps the pre-lock capture near-instant (~0.1s vs ~0.7s for PNG at
// 2880x1800); the shot is only a transient wave-reveal base, so q85 is
// visually indistinguishable once the curtain sweeps over it.
Process {
    id: process

    property int screenIndex: -1
    property string screenName: ""
    property string outputPath: ""
    property string directory: ""
    running: true

    signal captured(int screenIndex, string url)

    // grim's -o names the output device to capture; the image file is a
    // positional argument. Handing the path to -o made every capture fail with
    // "unknown output", which left the lock surface on its solid floor color.
    // An unnamed screen falls back to grim's union-of-outputs capture.
    readonly property var _grimArgs: {
        const args = ["grim", "-t", "jpeg", "-q", "85"]
        if (String(process.screenName || "") !== "")
            args.push("-o", String(process.screenName))
        args.push(String(process.outputPath || ""))
        // `sh -c` creates the runtime directory first, then hands the rest of
        // the argv to grim unchanged so paths need no escaping.
        return ["sh", "-c", "mkdir -p \"$1\" && shift && exec \"$@\"",
                "grim-wrapper", process.directory].concat(args)
    }

    command: process._grimArgs

    onExited: code => {
        captured(process.screenIndex,
                 code === 0 && process.outputPath !== "" ? "file://" + process.outputPath : "")
        process.destroy()
    }
}
