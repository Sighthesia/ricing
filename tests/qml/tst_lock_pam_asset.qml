import QtQuick
import QtTest

// Contract between the configured PamContext and the shipped PAM asset:
// whatever service name LockContext.qml configures must exist under
// assets/pam.d, carry a valid PAM header, authenticate through pam_unix,
// and never grant auth through pam_permit.
//
// Requires file reads: run with QML_XHR_ALLOW_FILE_READ=1.
Item {
    id: harness

    function readText(url) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url, false)
        xhr.send(null)
        return { status: xhr.status, text: xhr.responseText }
    }

    function readRepoFile(relativePath) {
        return readText(Qt.resolvedUrl("../../" + relativePath))
    }

    function configuredPamServiceName() {
        var context = readRepoFile("modules/lock/LockContext.qml")
        if (context.status !== 200)
            return ""
        var match = context.text.match(/config:\s*"([^"]+)"/)
        return match ? match[1] : ""
    }

    TestCase {
        name: "LockPamAsset"

        function test_pamContextDeclaresAConfiguredService() {
            verify(harness.configuredPamServiceName().length > 0,
                   "LockContext.qml must configure a PAM service name")
        }

        function test_pamContextPointsAtProjectAssetDirectory() {
            var context = harness.readRepoFile("modules/lock/LockContext.qml")
            compare(context.status, 200)
            verify(/configDirectory:\s*Quickshell\.shellPath\("assets\/pam\.d"\)/
                   .test(context.text),
                   "configDirectory must resolve to the shipped assets/pam.d")
        }

        function test_configuredPamAssetExists() {
            var service = harness.configuredPamServiceName()
            verify(service.length > 0)
            var asset = harness.readRepoFile("assets/pam.d/" + service)
            compare(asset.status, 200,
                    "assets/pam.d/" + service + " must exist so PamContext can authenticate")
        }

        function test_pamAssetHasValidHeaderAndUnixAuthStack() {
            var asset = harness.readRepoFile("assets/pam.d/"
                                             + harness.configuredPamServiceName())
            compare(asset.status, 200)
            verify(asset.text.indexOf("#%PAM-1.0") === 0,
                   "PAM asset must start with the #%PAM-1.0 header")
            verify(/^auth\s/m.test(asset.text), "PAM asset must define an auth stack")
            verify(/pam_unix\.so/.test(asset.text),
                   "PAM asset must authenticate through pam_unix.so")
        }

        function test_pamAssetNeverGrantsAuthThroughPermit() {
            var asset = harness.readRepoFile("assets/pam.d/"
                                             + harness.configuredPamServiceName())
            compare(asset.status, 200)
            var authLines = asset.text.split("\n").filter(function(line) {
                return /^auth\s/.test(line)
            })
            verify(authLines.length > 0)
            for (var i = 0; i < authLines.length; ++i)
                verify(authLines[i].indexOf("pam_permit.so") < 0,
                       "auth must never be granted through pam_permit: " + authLines[i])
        }
    }
}
