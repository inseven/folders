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
    func storeView(_ storeView: StoreView, didInsertURL url: URL, atIndex: Int)
    func storeView(_ storeView: StoreView, didRemoveURL url: URL, atIndex: Int)

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
    }

    func store(_ store: Store, didInsert details: Details) {
        dispatchPrecondition(condition: .notOnQueue(.main))
        DispatchQueue.main.async {
            guard self.filter.matches(details: details) else {
                return
            }
            let index = self.files.partitioningIndex {
                return self.sort.compare(details, $0)
            }
            self.files.insert(details, at: index)
            self.delegate?.storeView(self, didInsertURL: details.url, atIndex: index)
        }
    }

    func store(_ store: Store, didRemoveURLs urls: [URL]) {
        dispatchPrecondition(condition: .notOnQueue(.main))
        // TODO: Maybe this shouldn't live on main queue
        DispatchQueue.main.async {
            if urls.count < 10 {
                for url in urls {
                    guard let index = self.files.firstIndex(where: { $0.url == url }) else {
                        return
                    }
                    self.files.remove(at: index)
                    self.delegate?.storeView(self, didRemoveURL: url, atIndex: index)
                }
            } else {
                for url in urls {
                    _ = self.files.firstIndex(where: { $0.url == url })
                }
                self.delegate?.storeViewDidUpdate(self)
            }
        }
    }

}
