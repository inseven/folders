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

import Combine
import Foundation

struct StorePublisher: Publisher {

    class Subscription<Target: Subscriber>: NSObject,
                                            Combine.Subscription,
                                            StoreObserver where Target.Input == StoreOperation {

        var id = UUID()

        fileprivate var store: Store
        fileprivate var target: Target?

        init(store: Store) {
            self.store = store
            super.init()
            self.store.add(observer: self)
        }

        func request(_ demand: Subscribers.Demand) {}

        func cancel() {
            target = nil
            self.store.remove(observer: self)
        }

        func store(_ store: Store, didInsertFiles files: [Details]) {
            _ = target?.receive(.add(files))
        }

        func store(_ store: Store, didRemoveFilesWithIdentifiers identifiers: [Details.Identifier]) {
            _ = target?.receive(.remove(identifiers))
        }

    }

    typealias Output = StoreOperation
    typealias Failure = Never

    fileprivate var store: Store

    init(store: Store) {
        self.store = store
    }

    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        let subscription = Subscription<S>(store: store)
        subscription.target = subscriber
        subscriber.receive(subscription: subscription)
    }

}

extension Store {

    func publisher() -> StorePublisher {
        return StorePublisher(store: self)
    }

}
