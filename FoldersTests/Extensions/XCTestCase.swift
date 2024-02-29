// MIT License
//
// Copyright (c) 2023-2024 Jason Morley
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import XCTest
@testable import Folders

import UniformTypeIdentifiers

extension URL {

    var debugRepresentation: String {
        return self.pathIncludingTrailingSeparator
    }

}

class DirectoryScannerTestDelegate: NSObject, DirectoryScannerDelegate {

    let semaphore = DispatchSemaphore(value: 0)

    func directoryScannerDidStart(_ directoryScanner: Folders.DirectoryScanner) {
        semaphore.signal()
    }

    func waitForStartup(timeout: DispatchTime) -> DispatchTimeoutResult {
        return semaphore.wait(timeout: timeout)
    }

}

extension XCTestCase {

    func withTemporaryDirectory(perform: (URL) throws -> Void) throws {
        let fileManager = FileManager.default
        let directoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        do {
            try perform(directoryURL)
        } catch {
            try fileManager.removeItem(at: directoryURL)
            throw error
        }
    }

    func scan(directoryURL: URL,
              onFileCreation: @escaping (any Collection<Details>) -> Void,
              onFileUpdate: @escaping (any Collection<Details>) -> Void,
              onFileDeletion: @escaping (any Collection<Details.Identifier>) -> Void) throws -> DirectoryScanner {
        let scanner = DirectoryScanner(url: directoryURL)
        let delegate = DirectoryScannerTestDelegate()
        scanner.delegate = delegate
        let snapshot = try Set(FileManager.default.files(directoryURL: directoryURL))

        print("DirectoryScanner snapshot:\n\(snapshot.map({ "  \($0.url.debugRepresentation)" }).joined(separator: "\n"))")
        scanner.start {
            return snapshot
        } onFileCreation: { files in
            print("DirectoryScanner onFileCreation:\n\(files.map({ "  \($0.url.debugRepresentation)" }).joined(separator: "\n"))")
            onFileCreation(files)
        } onFileUpdate: { files in
            print("DirectoryScanner onFileUpdate:\n\(files.map({ "  \($0.url.debugRepresentation)" }).joined(separator: "\n"))")
            onFileUpdate(files)
        } onFileDeletion: { identifiers in
            print("DirectoryScanner onFileDeletion:\n\(identifiers.map({ "  \($0.url.debugRepresentation)" }).joined(separator: "\n"))")
            onFileDeletion(identifiers)
        }

        if delegate.waitForStartup(timeout: .now() + 1.0) == .timedOut {
            XCTFail("DirectoryScanner failed to startup")
        }

        return scanner
    }

}
