#!/usr/bin/env swift
// Read only. Pass the expected file path after a real download.
import AppKit
import Foundation
let expected = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL.resolvingSymlinksInPath()
let deadline = Date().addingTimeInterval(15)
while Date() < deadline {
    let files = NSPasteboard.general.readObjects(forClasses: [NSURL.self],
        options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    if files.contains(where: { $0.standardizedFileURL.resolvingSymlinksInPath() == expected }) {
        print("PASS: Clipboard contains the expected native file URL.")
        exit(0)
    }
    Thread.sleep(forTimeInterval: 0.25)
}
fputs("FAIL: Expected file URL not found on clipboard.\n", stderr)
exit(1)
