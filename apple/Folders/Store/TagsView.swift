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
                  didUpdateTags tags: [String])
    func tagsView(_ tagsView: TagsView,
                  didInsertTag tag: String,
                  atIndex index: Int,
                  tags: [String])
    func tagsView(_ tagsView: TagsView,
                  didRemoveTag tag: String,
                  atIndex index: Int,
                  tags: [String])

}

// TODO: Right now this is just a file view and should probably be updated accordingly.
//       Would this be better with a publisher or not?
class TagsView: NSObject, Store.Observer {

    let store: Store
    let workQueue = DispatchQueue(label: "StoreView.workQueue", qos: .userInteractive)
//    let sort: Sort  // TODO: Do we still need this?? Could it be templated??
    let threshold: Int
    private var isRunning: Bool = false  // Synchronized on workQueue
    private var tags: [String] = []  // Synchronized on workQueue

    // TODO: We _could_ consider using a thread to guard against mutation to `files` instead of the queue.
    // TODO: It might be nice to have a targetQueue for the delegate to make the serialisation explicit.

    weak var delegate: TagsViewDelegate? = nil

    init(store: Store, sort: Sort = .displayNameAscending, threshold: Int = 10) {
        self.store = store
//        self.sort = sort
        self.threshold = threshold
        super.init()
    }

    func start() {
        workQueue.async {
            do {
                precondition(self.isRunning == false)
                self.isRunning = true

                // Start observing the database.
                // TODO: Maybe this takes workQueue?
                self.store.add(observer: self)

                // Get them out sorted.
                let queryStart = Date()
                let queryDuration = queryStart.distance(to: Date())
                self.tags = try self.store.tagsBlocking(sort: .displayNameAscending)  // TODO: Common sort architecture??
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
        // TODO: Clean up?
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

    func store(_ store: Store, didInsertTags tags: [String]) {
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
                        return tag.localizedCaseInsensitiveCompare($0) == .orderedAscending
//                        return self.sort.compare(tag, $0)
                    }
                    self.tags.insert(tag, at: index)
                    let snapshot = self.tags
                    DispatchQueue.main.async {
                        self.delegate?.tagsView(self, didInsertTag: tag, atIndex: index, tags: snapshot)
                    }
                }
            } else {
                // TODO: There's an optimisation here if the list is empty.
                for tag in tags {
                    let index = self.tags.partitioningIndex {
//                        return self.sort.compare(file, $0)
                        return tag.localizedCaseInsensitiveCompare($0) == .orderedAscending
                    }
                    self.tags.insert(tag, at: index)
                }
                // TODO: We might as well cascade these changes down to the table view to allow it decide on performance
                //       characteristics.
                let snapshot = self.tags
                DispatchQueue.main.async {
                    self.delegate?.tagsView(self, didUpdateTags: snapshot)
                }
            }
        }
    }

    func store(_ store: Store, didRemoveTags tags: [String]) {
        dispatchPrecondition(condition: .notOnQueue(.main))
        // TODO: Maybe this shouldn't live on main queue
        // TODO: Pre-filter the updates.
        workQueue.async {
            guard self.isRunning else {
                return
            }

            // TODO: Pre-filter the identifiers here if we can? Or somehow work out which intersect before deciding
            // how to notify our delegate.

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
