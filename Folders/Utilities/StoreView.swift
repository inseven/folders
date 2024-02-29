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

import Algorithms

protocol StoreViewDelegate: NSObject {

    func storeViewDidUpdate(_ storeView: StoreView)
    // TODO: Expose the details directly in the update.
    func storeView(_ storeView: StoreView, didInsertFile file: Details, atIndex: Int)
    func storeView(_ storeView: StoreView, didUpdateFile file: Details, atIndex: Int)
    func storeView(_ storeView: StoreView, didRemoveFileWithIdentifier identifier: Details.Identifier, atIndex: Int)

}

class StoreView: NSObject, StoreObserver {

    let store: Store
    let workQueue = DispatchQueue(label: "StoreView.workQueue", qos: .userInteractive)
    let filter: Filter
    let sort: Sort
    let threshold: Int
    var isRunning: Bool = false  // Synchronized on workQueue

    var files: [Details] = []

    weak var delegate: StoreViewDelegate? = nil

    init(store: Store, filter: Filter = TrueFilter(), sort: Sort = .displayNameAscending, threshold: Int = 10) {
        self.store = store
        self.filter = filter
        self.sort = sort
        self.threshold = threshold
        super.init()
    }

    func start() {
        workQueue.async {
            do {
                self.isRunning = true

                // Start observing the database.
                // TODO: Maybe this takes workQueue?
                self.store.add(observer: self)

                // Get them out sorted.
                let queryStart = Date()
                let queryDuration = queryStart.distance(to: Date())
                let sortedFiles = try self.store.filesBlocking(filter: self.filter, sort: self.sort)
                print("Query took \(queryDuration.formatted()) seconds and returned \(sortedFiles.count) files.")

                DispatchQueue.main.async { [self] in
                    self.files = sortedFiles
                    self.delegate?.storeViewDidUpdate(self)
                }
            } catch {
                // TODO: Provide a delegate model that actually returns errors.
                print("Failed to scan for files with error \(error).")
            }
        }
    }

    func stop() {
        store.remove(observer: self)
        // TODO: Clean up?
    }

    func store(_ store: Store, didInsertFiles files: [Details]) {
        dispatchPrecondition(condition: .notOnQueue(.main))
        workQueue.async {
            guard self.isRunning else {
                return
            }

            // Ignore unrelated updates.
            let files = files.filter { self.filter.matches(details: $0) }
            guard files.count > 0 else {
                return
            }

            if files.count < self.threshold {
                for file in files {
                    let index = self.files.partitioningIndex {
                        return self.sort.compare(file, $0)
                    }
                    self.files.insert(file, at: index)
                    DispatchQueue.main.async {
                        self.delegate?.storeView(self, didInsertFile: file, atIndex: index)
                    }
                }
            } else {
                for file in files {
                    let index = self.files.partitioningIndex {
                        return self.sort.compare(file, $0)
                    }
                    self.files.insert(file, at: index)
                }
                // TODO: We might as well cascade these changes down to the table view to allow it decide on performance
                //       characteristics.
                DispatchQueue.main.async {
                    self.delegate?.storeViewDidUpdate(self)
                }
            }
        }
    }

    func store(_ store: Store, didUpdateFiles files: [Details]) {
        dispatchPrecondition(condition: .notOnQueue(.main))
        workQueue.async {
            guard self.isRunning else {
                return
            }

            // Ignore unrelated updates.
            let files = files.filter { self.filter.matches(details: $0) }
            guard files.count > 0 else {
                return
            }

            // TODO: We have a race condition during startup whereby we can sometimes receive updates as we're querying
            //       and before we've received the full dataset.
            var indexes = [(Details, Int)]()
            for file in files {
                let index = self.files.firstIndex { $0.uuid == file.uuid }!
                self.files[index] = file
                indexes.append((file, index))
            }
            // TODO: Actual update API.

            if indexes.count < self.threshold {
                for (file, index) in indexes {
                    DispatchQueue.main.async {
                        self.delegate?.storeView(self, didUpdateFile: file, atIndex: index)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.delegate?.storeViewDidUpdate(self)
                }
            }
        }
    }

    func store(_ store: Store, didRemoveFilesWithIdentifiers identifiers: [Details.Identifier]) {
        dispatchPrecondition(condition: .notOnQueue(.main))
        // TODO: Maybe this shouldn't live on main queue
        // TODO: Pre-filter the updates.
        workQueue.async {
            guard self.isRunning else {
                return
            }

            // TODO: Pre-filter the identifiers here if we can? Or somehow work out which intersect before deciding
            // how to notify our delegate.

            if identifiers.count < self.threshold {
                for identifier in identifiers {
                    guard let index = self.files.firstIndex(where: { $0.identifier == identifier }) else {
                        continue
                    }
                    self.files.remove(at: index)
                    DispatchQueue.main.async {
                        self.delegate?.storeView(self, didRemoveFileWithIdentifier: identifier, atIndex: index)
                    }
                }
            } else {
                for identifier in identifiers {
                    guard let index = self.files.firstIndex(where: { $0.identifier == identifier }) else {
                        continue
                    }
                    self.files.remove(at: index)
                }
                DispatchQueue.main.async {
                    self.delegate?.storeViewDidUpdate(self)
                }
            }
        }
    }

}
