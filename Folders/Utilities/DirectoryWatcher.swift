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
import UniformTypeIdentifiers

protocol DirectoryWatcherDelegate: NSObject {

    func directoryWatcherDidUpdate(_ directoryWatcher: DirectoryWatcher)
    func directoryWatcher(_ directoryWatcher: DirectoryWatcher, didInsertURL url: URL, atIndex: Int)

}

// TODO: Maybe don't make this an NSObject
class DirectoryWatcher: NSObject, StoreObserver {

    let store: Store
    let url: URL
    let workQueue = DispatchQueue(label: "DirectoryWatcher.workQueue")
    let filter: Filter
    var files: [URL] = []

    weak var delegate: DirectoryWatcherDelegate? = nil

    init(store: Store, url: URL) {
        self.store = store
        self.url = url

        let pdf = UTType(mimeType: "application/pdf")!
        let image = UTType(mimeType: "image/*")!
        let video = UTType(mimeType: "video/*")!
        filter = ParentFilter(parent: url.path) && (TypeFilter.conformsTo(pdf) ||
                                                    TypeFilter.conformsTo(image) ||
                                                    TypeFilter.conformsTo(video))
        
        super.init()
    }

    func start() {
        Task {
            do {

                // Start observing the database.
                store.add(observer: self)

                // Get them out sorted.
                let queryStart = Date()
                let queryDuration = queryStart.distance(to: Date())
                let sortedFiles = try await store.files(filter: filter)
                print("Query took \(queryDuration.formatted()) seconds and returned \(sortedFiles.count) files.")

                DispatchQueue.main.async { [self] in
                    self.files = sortedFiles
                    self.delegate?.directoryWatcherDidUpdate(self)
                }

            } catch {
                // TODO: Provide a delegate model that actually returns errors.
                print("Failed to scan for files with error \(error).")
            }
        }
    }

    func stop() {
        store.remove(observer: self)
    }

    func store(_ store: Store, didInsert details: Details) {
        dispatchPrecondition(condition: .notOnQueue(.main))

        // Ignore updates that don't match our filter (currently just the parent URL).
        guard url.path.starts(with: self.url.path) else {
            return
        }

        DispatchQueue.main.async {
            guard self.filter.matches(details: details) else {
                return
            }

            // TODO: Work out where to insert this and pass this through to our observer.
            self.files.append(details.url)
            self.delegate?.directoryWatcher(self, didInsertURL: details.url, atIndex: self.files.count - 1)
        }
    }

    func store(_ store: Store, didRemoveURL url: URL) {
        dispatchPrecondition(condition: .notOnQueue(.main))
        DispatchQueue.main.async {
            self.files.removeAll { $0 == url }
            self.delegate?.directoryWatcher(self, didInsertURL: url, atIndex: self.files.count - 1)
        }
    }

}
