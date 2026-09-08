import AppKit
import CoreServices
import Foundation

public final class Watcher {
    private struct Stamp: Equatable {
        let size: UInt64
        let modified: Date
        let inode: UInt64
    }
    private struct Pending {
        let stamp: Stamp
        let since: Date
    }
    public let directory: URL
    private let settle: TimeInterval
    private let copy: (URL) throws -> Void
    private let report: (String) -> Void
    private let invalidated: () -> Void
    private var known: [URL: Stamp] = [:]
    private var pending: [URL: Pending] = [:]
    private var source: DispatchSourceFileSystemObject?
    private var timer: DispatchSourceTimer?
    private var changes: FSEventStreamRef?

    public init(directory: URL, settle: TimeInterval = 2,
                copy: @escaping (URL) throws -> Void,
                report: @escaping (String) -> Void = { _ in },
                invalidated: @escaping () -> Void = {}) {
        self.directory = directory.standardizedFileURL
        self.settle = settle
        self.copy = copy
        self.report = report
        self.invalidated = invalidated
    }

    private func stamp(for url: URL) -> Stamp? {
        guard !url.lastPathComponent.hasPrefix("."),
              !["crdownload", "part", "download", "tmp", "temp"].contains(url.pathExtension.lowercased()),
              !["crdownload", "part", "download"].contains(where: {
                  FileManager.default.fileExists(atPath: url.path + "." + $0)
              }),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              let modified = attributes[.modificationDate] as? Date,
              let inode = attributes[.systemFileNumber] as? NSNumber else { return nil }
        return Stamp(size: size.uint64Value, modified: modified, inode: inode.uint64Value)
    }

    private func snapshot() throws -> [URL: Stamp] {
        var result: [URL: Stamp] = [:]
        for url in try FileManager.default.contentsOfDirectory(at: directory,
                         includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            result[url] = stamp(for: url)
        }
        return result
    }

    // All methods run on the main queue. Arm before the initial snapshot to avoid a startup gap.
    public func start() throws {
        guard source == nil else { return }
        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let events = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .revoke], queue: .main)
        events.setCancelHandler { close(fd) }
        events.setEventHandler { [weak self] in
            guard let self else { return }
            if let flags = self.source?.data, !flags.intersection([.rename, .delete, .revoke]).isEmpty {
                self.stop()
                self.report("Watched directory disappeared; restart required.")
                self.invalidated()
                return
            }
            self.scan()
        }
        source = events
        events.resume()
        // Directory dispatch sources do not report every in-place file write.
        // FSEvents batches these changes without opening one descriptor per file.
        var context = FSEventStreamContext(version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil)
        guard let stream = FSEventStreamCreate(nil, { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<Watcher>.fromOpaque(info).takeUnretainedValue().scan()
        }, &context, [directory.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.25,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)) else {
            stop()
            throw CocoaError(.fileReadUnknown)
        }
        changes = stream
        FSEventStreamSetDispatchQueue(stream, .main)
        guard FSEventStreamStart(stream) else {
            stop()
            throw CocoaError(.fileReadUnknown)
        }
        do { known = try snapshot() } catch { stop(); throw error }
    }

    deinit { stop() }

    public func stop() {
        if let changes {
            FSEventStreamStop(changes)
            FSEventStreamInvalidate(changes)
            FSEventStreamRelease(changes)
            self.changes = nil
        }
        source?.cancel()
        source = nil
        timer?.cancel()
        timer = nil
        pending.removeAll()
    }

    private func scan(pendingOnly: Bool = false) {
        do {
            // Directory events discover candidates. Timer ticks only inspect candidates.
            var current = known
            if pendingOnly {
                for url in pending.keys { current[url] = stamp(for: url) }
            } else {
                current = try snapshot()
            }
            let now = Date()
            pending = pending.filter { current[$0.key] != nil }
            for (url, stamp) in current where known[url] != stamp {
                pending[url] = Pending(stamp: stamp, since: now)
            }
            known = current
            let ready = pending.filter { now.timeIntervalSince($0.value.since) >= settle }
                .sorted {
                    if $0.value.since == $1.value.since {
                        if $0.value.stamp.modified == $1.value.stamp.modified {
                            return $0.key.path < $1.key.path
                        }
                        return $0.value.stamp.modified < $1.value.stamp.modified
                    }
                    return $0.value.since < $1.value.since
                }
            for (url, _) in ready {
                pending.removeValue(forKey: url)
                do { try copy(url); report("Copied: \(url.lastPathComponent)") }
                catch { report("Cannot copy \(url.lastPathComponent): \(error.localizedDescription)") }
            }
            if pending.isEmpty {
                timer?.cancel()
                timer = nil
            } else if timer == nil {
                let poll = DispatchSource.makeTimerSource(queue: .main)
                poll.schedule(deadline: .now() + 0.25, repeating: 0.25, leeway: .milliseconds(50))
                poll.setEventHandler { [weak self] in self?.scan(pendingOnly: true) }
                timer = poll
                poll.resume()
            }
        } catch {
            report("Cannot read directory: \(error.localizedDescription)")
            stop()
            invalidated()
        }
    }

    public static func copyFile(_ url: URL, to pasteboard: NSPasteboard = .general) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        pasteboard.clearContents()
        guard pasteboard.writeObjects([url as NSURL]) else { throw CocoaError(.fileWriteUnknown) }
    }
}
