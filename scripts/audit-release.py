#!/usr/bin/env python3
"""Reject unexpected release files, ZIP metadata, and local build paths."""
import sys
import zipfile


def audit(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if sorted(names) != ["LICENSE", "downloadwatch"]:
            raise ValueError(f"Unexpected archive entries: {names}")
        if archive.comment or any(item.extra or item.comment for item in archive.infolist()):
            raise ValueError("Unexpected ZIP metadata")
        if archive.testzip() is not None:
            raise ValueError("Archive CRC check failed")
        binary = archive.read("downloadwatch")
        for prefix in (b"/Applications/", b"/Users/", b"/home/", b"/private/var/", b"/Volumes/", b"/tmp/"):
            if prefix in binary:
                raise ValueError("Local filesystem path found in executable")
        if b"MIT License" not in archive.read("LICENSE"):
            raise ValueError("Missing MIT license")
        if not (archive.getinfo("downloadwatch").external_attr >> 16) & 0o111:
            raise ValueError("Missing executable permissions")
    print("PASS: ZIP contains only the executable and license, with no local build paths or extra ZIP metadata.")


if __name__ == "__main__":
    audit(sys.argv[1])
