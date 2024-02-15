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

import SQLite

protocol StoreViewDelegate: NSObject {

    // TODO: Rename this.
    func directoryWatcherDidUpdate(_ directoryWatcher: StoreView)
    func directoryWatcher(_ directoryWatcher: StoreView, didInsertURL url: URL, atIndex: Int)
    func directoryWatcher(_ directoryWatcher: StoreView, didRemoveURL url: URL, atIndex: Int)

}

protocol Sort {

    func compare(_ lhs: Details, _ rhs: Details) -> Bool
    var order: [Expressible] { get }
}

struct DisplayNameAscending: Sort {

    func compare(_ lhs: Details, _ rhs: Details) -> Bool {
        return lhs.url.displayName.localizedStandardCompare(rhs.url.displayName) == .orderedAscending
    }
    
    var order: [Expressible] {
        return [Store.Schema.name.asc]
    }

}

extension Sort where Self == DisplayNameAscending {

    static var displayNameAscending: DisplayNameAscending {
        return DisplayNameAscending()
    }

}

struct DisplayNameDescending: Sort {

    func compare(_ lhs: Details, _ rhs: Details) -> Bool {
        return lhs.url.displayName.localizedStandardCompare(rhs.url.displayName) == .orderedDescending
    }

    var order: [Expressible] {
        return [Store.Schema.name.desc]
    }

}

extension Sort where Self == DisplayNameDescending {

    static var displayNameDescending: DisplayNameDescending {
        return DisplayNameDescending()
    }

}

class StoreView: NSObject, StoreObserver {

    let store: Store
    let workQueue = DispatchQueue(label: "StoreView.workQueue")
    let filter: Filter
    let sort: Sort
    var files: [Details] = []

    weak var delegate: StoreViewDelegate? = nil

    init(store: Store, filter: Filter = TrueFilter(), sort: Sort = .displayNameAscending) {
        self.store = store
        self.filter = filter
        self.sort = sort
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
                let sortedFiles = try await store.files(filter: filter, sort: sort)
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
        DispatchQueue.main.async {
            guard self.filter.matches(details: details) else {
                return
            }

            // TODO: Work out where to insert this and pass this through to our observer.
            self.files.append(details)
//            self.files.sorted(using: SortComparator)
            self.delegate?.directoryWatcher(self, didInsertURL: details.url, atIndex: self.files.count - 1)
        }
    }

    // TODO: Delegate remove!!
    // TODO: This call back needs to accept details?
    func store(_ store: Store, didRemoveURL url: URL) {
        dispatchPrecondition(condition: .notOnQueue(.main))
        DispatchQueue.main.async {
            guard let index = self.files.firstIndex(where: { $0.url == url }) else {
                return
            }
            self.files.remove(at: index)
            self.delegate?.directoryWatcher(self, didRemoveURL: url, atIndex: index)
        }
    }

}
