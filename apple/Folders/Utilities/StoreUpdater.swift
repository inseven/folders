// MIT License
//
// Copyright (c) 2023-2025 Jason Morley
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

    // TODO: Would it be better to reduce this down to a stream processing?
    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        self.scanner.start {
            // Take an in-memory snapshot of everything within this owner and use it to track deletions.
            // We can do this safely (and outside of a transaction) as we can guarantee we're the only observer
            // modifying the files within this owner.
            return try! self.store.files(filter: .owner(self.url), sort: .displayNameAscending)
                .reduce(into: Set<Details>()) { partialResult, details in
                    partialResult.insert(details)
                }
        } onFileCreation: { files in
            do {
                try self.store.insert(files: files)
            } catch {
                print("Failed to perform creation update with error \(error).")
            }
        } onFileUpdate: { files in
            do {
                try self.store.update(files: files)
            } catch {
                print("Failed to perform update update with error \(error).")
            }
        } onFileDeletion: { identifiers in
            do {
                try self.store.remove(identifiers: identifiers)
            } catch {
                print("Failed to perform deletion update with error \(error).")
            }
        }
    }

    func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        scanner.stop()
    }

}
