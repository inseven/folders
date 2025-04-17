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

import Combine
import Foundation

// TODO: I think this should use `StoreFilesView` to get an initial value
struct StorePublisher: Publisher {

    class Subscription<Target: Subscriber>: NSObject,
                                            Combine.Subscription,
                                            Store.Observer where Target.Input == StoreOperation {

        var id = UUID()

        private let store: Store
        private let filter: IdentifierFilter

        var target: Target?

        init(store: Store, filter: IdentifierFilter) {
            self.store = store
            self.filter = filter
            super.init()
            self.store.add(observer: self)
        }

        func request(_ demand: Subscribers.Demand) {}

        func cancel() {
            target = nil
            self.store.remove(observer: self)
        }

        func store(_ store: Store, didInsertFiles files: [Details]) {
            let files = files.filter { filter.matches(identifier: $0.identifier) }
            guard !files.isEmpty else {
                return
            }
            _ = target?.receive(.add(files))
        }

        func store(_ store: Store, didUpdateFiles files: [Details]) {
            let files = files.filter { filter.matches(identifier: $0.identifier) }
            guard !files.isEmpty else {
                return
            }
            _ = target?.receive(.update(files))
        }

        func store(_ store: Store, didRemoveFilesWithIdentifiers identifiers: [Details.Identifier]) {
            _ = target?.receive(.remove(identifiers))
        }

        func store(_ store: Store, didInsertTags tags: [String]) {
            _ = target?.receive(.addTags(tags))
        }

        func store(_ store: Store, didRemoveTags tags: [String]) {
            _ = target?.receive(.removeTags(tags))
        }

    }

    typealias Output = StoreOperation
    typealias Failure = Never

    private var store: Store
    private var filter: IdentifierFilter

    init(store: Store, filter: IdentifierFilter) {
        self.store = store
        self.filter = filter
    }

    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        let subscription = Subscription<S>(store: store, filter: filter)
        subscription.target = subscriber
        subscriber.receive(subscription: subscription)
    }

}

extension Store {

    func publisher(filter: IdentifierFilter = TrueFilter()) -> StorePublisher {
        return StorePublisher(store: self, filter: filter)
    }

}
