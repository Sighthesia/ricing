import Quickshell.Io

// Capture one screen with grim into a per-generation PNG, then report the
// file URL (or nothing on failure) once before destroying the wrapper.
Process {
    id: process

    property int screenIndex: -1
    property string screenName: ""
    property string outputPath: ""
    property string directory: ""

    signal captured(int screenIndex, string url)

    // Wrap in sh so the runtime directory exists before grim writes into it;
    // positional arguments keep screen names and paths out of the command.
    command: ["sh", "-c", "mkdir -p \"$1\" && exec grim -o \"$2\" \"$3\"",
              "grim-wrapper", process.directory, process.screenName, process.outputPath]

    onExited: code => {
        captured(process.screenIndex,
                 code === 0 && process.outputPath !== "" ? "file://" + process.outputPath : "")
        process.destroy()
    }
}
