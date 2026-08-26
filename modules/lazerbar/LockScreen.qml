pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import "../../services" as Services

// Session-lock window: the protocol instantiates one surface per output and
// grants exclusive keyboard focus, so no Variants or layershell wiring here.
// Visibility is driven entirely by Services.LockService.locked.
WlSessionLock {
    id: sessionLock

    locked: Services.LockService.locked

    LockSurface { lock: sessionLock }
}
