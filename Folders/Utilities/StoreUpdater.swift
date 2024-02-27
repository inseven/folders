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

import Foundation

class StoreUpdater {

    let store: Store
    let url: URL
    let scanner: DirectoryScanner

    init(store: Store, url: URL) {
        self.store = store
        self.url = url
        self.scanner = DirectoryScanner(url: url)
    }

    func start() {
        // TODO: Make this a delegate method?
        scanner.start { [store] details in

            // TODO: Maybe allow this to rethrow and catch it at the top level to make the code cleaner?
            // TODO: Make this async so we can use async APIs exclusively in the Store.

            do {
                let insertStart = Date()

                let currentFiles = Set(details)

                // Take an in-memory snapshot of everything within this owner and use it to track deletions.
                // We can do this safely (and outside of a transaction) as we can guarantee we're the only observer
                // modifying the files within this owner.
                let storedFiles = try store.filesBlocking(filter: .owner(self.url), sort: .displayNameAscending)
                    .reduce(into: Set<Details>()) { partialResult, details in
                        partialResult.insert(details)
                    }

                // Add just the new files.
                let newFiles = currentFiles.subtracting(storedFiles)
                if newFiles.count > 0 {
                    print("Inserting \(newFiles.count) new files...")
                    try store.insertBlocking(files: newFiles)
                }

                // Remove the remaining files.
                let deletedIdentifiers = storedFiles.subtracting(currentFiles)
                    .map { $0.identifier }
                if deletedIdentifiers.count > 0 {
                    print("Removing \(deletedIdentifiers.count) deleted files...")
                    try store.removeBlocking(identifiers: deletedIdentifiers)
                }

                let insertDuration = insertStart.distance(to: Date())
                print("Update took \(insertDuration.formatted()) seconds.")

            } catch {
                print("Failed to insert updates with error \(error).")
            }
        } onFileCreation: { [store] files in
            do {
                try store.insertBlocking(files: files)
            } catch {
                print("Failed to perform creation update with error \(error).")
            }
        } onFileDeletion: { [store] identifiers in
            do {
                try store.removeBlocking(identifiers: identifiers)
            } catch {
                print("Failed to perform deletion update with error \(error).")
            }
        }
    }

    func stop() {
        scanner.stop()
    }

}
