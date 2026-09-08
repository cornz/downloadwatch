import AppKit
import XCTest
@testable import DownloadWatchCore

final class WatcherTests: XCTestCase {
    func testDownloadLifecycleAndNativeClipboard() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clipboard = NSPasteboard.withUniqueName()
        defer { clipboard.releaseGlobally() }
        let existing = directory.appendingPathComponent("existing.txt")
        try Data("old".utf8).write(to: existing)
        var copied: [URL] = []
        let done = expectation(description: "Completed download copied as native file")
        let watcher = Watcher(directory: directory, settle: 0.6, copy: { url in
            try Watcher.copyFile(url, to: clipboard)
            copied.append(url)
            done.fulfill()
        })
        try watcher.start()
        defer { watcher.stop() }
        let temporary = directory.appendingPathComponent("report.pdf.crdownload")
        let destination = directory.appendingPathComponent("report.pdf")
        try Data("partial".utf8).write(to: temporary)
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("link.txt"),
                                                  withDestinationURL: existing)
        try Data("hidden".utf8).write(to: directory.appendingPathComponent(".hidden"))
        // Leave the temporary file stable longer than the settling window.
        RunLoop.main.run(until: Date().addingTimeInterval(1.0))
        XCTAssertTrue(copied.isEmpty)
        try FileManager.default.moveItem(at: temporary, to: destination)
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))
        let handle = try FileHandle(forWritingTo: destination)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(" finished".utf8))
        try handle.close()
        RunLoop.main.run(until: Date().addingTimeInterval(0.45))
        XCTAssertTrue(copied.isEmpty, "A write must reset the settling window")
        wait(for: [done], timeout: 3)
        XCTAssertEqual(copied.map { $0.resolvingSymlinksInPath() }, [destination.resolvingSymlinksInPath()])
        let urls = clipboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        XCTAssertEqual(urls?.map { $0.resolvingSymlinksInPath() }, [destination.resolvingSymlinksInPath()])
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        XCTAssertEqual(copied.count, 1, "Must not repeatedly overwrite the clipboard")
    }

    func testChangedExistingFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("existing.txt")
        try Data("old".utf8).write(to: file)
        let done = expectation(description: "Existing file edit copied")
        let watcher = Watcher(directory: directory, settle: 0.5, copy: { url in
            XCTAssertEqual(url.lastPathComponent, "existing.txt")
            done.fulfill()
        })
        try watcher.start()
        defer { watcher.stop() }
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(" changed".utf8))
        try handle.close()
        wait(for: [done], timeout: 3)
    }

    func testDeletedPendingFileIsNotCopied() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var copied = false
        let watcher = Watcher(directory: directory, settle: 0.5, copy: { _ in copied = true })
        try watcher.start()
        defer { watcher.stop() }
        let file = directory.appendingPathComponent("removed.txt")
        try Data("test".utf8).write(to: file)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        try FileManager.default.removeItem(at: file)
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        XCTAssertFalse(copied)
    }

    func testPlaceholderWaitsForPartFileToDisappear() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let done = expectation(description: "Placeholder becomes complete")
        var copied = false
        let watcher = Watcher(directory: directory, settle: 0.5, copy: { _ in
            copied = true
            done.fulfill()
        })
        try watcher.start()
        defer { watcher.stop() }
        let file = directory.appendingPathComponent("download.zip")
        let part = directory.appendingPathComponent("download.zip.part")
        try Data().write(to: file)
        try Data("partial".utf8).write(to: part)
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        XCTAssertFalse(copied)
        try Data("complete".utf8).write(to: file)
        try FileManager.default.removeItem(at: part)
        wait(for: [done], timeout: 3)
    }
}
