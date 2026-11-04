import AppKit

/// Opens this fork's releases without replacing the custom build with upstream Pin.
final class SparkleUpdater {

    func checkForUpdates() {
        guard let url = URL(string: "https://github.com/cut-hand/Pin/releases") else { return }
        NSWorkspace.shared.open(url)
    }

    var canCheckForUpdates: Bool { true }
}
