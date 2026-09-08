import DownloadWatchCore
import Foundation

func log(_ message: String) {
    FileHandle.standardError.write(Data("\(ISO8601DateFormatter().string(from: Date())) \(message)\n".utf8))
}

let args = Array(CommandLine.arguments.dropFirst())
if args == ["--version"] {
    print("downloadwatch 0.2.0")
    exit(0)
}
if args.contains("--help") || args.contains("-h") {
    print("Usage: downloadwatch [directory]\nDefault: ~/Downloads\nCopies new or changed files after 2 seconds of stable size and modification time.\nTemporary downloads, hidden files, directories and symlinks are ignored.\nEach completed file replaces the clipboard. Stop with Ctrl-C.")
    exit(0)
}
guard args.count <= 1, args.first?.hasPrefix("-") != true else {
    log("Usage: downloadwatch [directory]")
    exit(2)
}
let path = args.first.map { NSString(string: $0).expandingTildeInPath }
    ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
let watcher = Watcher(directory: URL(fileURLWithPath: path, isDirectory: true),
    copy: { try Watcher.copyFile($0) }, report: log, invalidated: { exit(1) })
do {
    try watcher.start()
    log("Watching \(watcher.directory.path)")
    dispatchMain()
} catch {
    log("Cannot watch \(path): \(error.localizedDescription)")
    exit(1)
}
