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
import UniformTypeIdentifiers

import Algorithms

// TODO: Move into TagsView?
protocol TagsViewDelegate: NSObject {

    func tagsView(_ tagsView: TagsView,
                  didUpdateTags tags: [Tag])
    func tagsView(_ tagsView: TagsView,
                  didInsertTag tag: Tag,
                  atIndex index: Int,
                  tags: [Tag])
    func tagsView(_ tagsView: TagsView,
                  didRemoveTag tag: Tag,
                  atIndex index: Int,
                  tags: [Tag])

}

class TagsView: NSObject, Store.Observer {

    let store: Store
    let workQueue = DispatchQueue(label: "StoreView.workQueue", qos: .userInteractive)
    let threshold: Int
    private var isRunning: Bool = false  // Synchronized on workQueue
    private var tags: [Tag] = []  // Synchronized on workQueue

    weak var delegate: TagsViewDelegate? = nil

    // TODO: Enforce serialization of client callbacks.
    init(store: Store, sort: Sort = .displayNameAscending, threshold: Int = 10) {
        self.store = store
        self.threshold = threshold
        super.init()
    }

    func start() {
        workQueue.async {
            do {
                precondition(self.isRunning == false)
                self.isRunning = true

                // Start observing the database.
                self.store.add(observer: self)

                // Get them out sorted.
                let queryStart = Date()
                let queryDuration = queryStart.distance(to: Date())
                self.tags = try self.store.tags()
                print("Query took \(queryDuration.formatted()) seconds and returned \(self.tags.count) tags.")

                let snapshot = self.tags
                DispatchQueue.main.async { [self] in
                    self.delegate?.tagsView(self, didUpdateTags: snapshot)
                }
            } catch {
                // TODO: Provide a delegate model that actually returns errors.
                print("Failed to scan for files with error \(error).")
            }
        }
    }

    func stop() {
        store.remove(observer: self)
        // TODO: Clean up our existing state to allow for restarts.
    }

    func store(_ store: Store, didInsertFiles files: [Details]) {
        // Do nothing.
    }

    func store(_ store: Store, didUpdateFiles files: [Details]) {
        // Do nothing.
    }

    func store(_ store: Store, didRemoveFilesWithIdentifiers identifiers: [Details.Identifier]) {
        // Do nothing.
    }

    func store(_ store: Store, didInsertTags tags: [Tag]) {
        dispatchPrecondition(condition: .notOnQueue(.main))
        workQueue.async {
            guard self.isRunning else {
                return
            }

            // Ignore unrelated updates and updates that are already in our view.
            // This can occur because there's a period of time during which we are subscribed but have yet to fetch
            // the data in the database. In this scenario it's possible to receive additions that we then get back in
            // our database query.
            // TODO: Using a flat array to store our files isn't very efficient for this kind of lookup.
            // TODO: It's very slightly possible this could be an update?
            let tags = tags.filter { !self.tags.contains($0) }
            guard tags.count > 0 else {
                return
            }

            // These sets should never intersect.
            assert(Set(self.tags).intersection(tags).count == 0)

            if tags.count < self.threshold {
                for tag in tags {
                    let index = self.tags.partitioningIndex {
                        return tag.name.localizedCaseInsensitiveCompare($0.name) == .orderedAscending
                    }
                    self.tags.insert(tag, at: index)
                    let snapshot = self.tags
                    DispatchQueue.main.async {
                        self.delegate?.tagsView(self, didInsertTag: tag, atIndex: index, tags: snapshot)
                    }
                }
            } else {
                if self.tags.isEmpty {
                    // If the list of tags is empty (e.g., in the case of an initial load), we can sort the tags and
                    // simply set the new value.
                    self.tags = tags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                } else {
                    for tag in tags {
                        let index = self.tags.partitioningIndex {
                            return tag.name.localizedCaseInsensitiveCompare($0.name) == .orderedAscending
                        }
                        self.tags.insert(tag, at: index)
                    }
                }
                let snapshot = self.tags
                DispatchQueue.main.async {
                    self.delegate?.tagsView(self, didUpdateTags: snapshot)
                }
            }
        }
    }

    func store(_ store: Store, didRemoveTags tags: [Tag]) {
        dispatchPrecondition(condition: .notOnQueue(.main))
        workQueue.async {
            guard self.isRunning else {
                return
            }
            if tags.count < self.threshold {
                for tag in tags {
                    guard let index = self.tags.firstIndex(of: tag) else {
                        continue
                    }
                    self.tags.remove(at: index)
                    let snapshot = self.tags
                    DispatchQueue.main.async {
                        self.delegate?.tagsView(self, didRemoveTag: tag, atIndex: index, tags: snapshot)
                    }
                }
            } else {
                for tag in tags {
                    guard let index = self.tags.firstIndex(of: tag) else {
                        continue
                    }
                    self.tags.remove(at: index)
                }
                let snapshot = self.tags
                DispatchQueue.main.async {
                    self.delegate?.tagsView(self, didUpdateTags: snapshot)
                }
            }
        }
    }

}
