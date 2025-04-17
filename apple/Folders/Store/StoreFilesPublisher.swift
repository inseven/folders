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

struct StoreFilesPublisher: Publisher {

    class Subscription<Target: Subscriber>: NSObject,
                                            Combine.Subscription,
                                            StoreFilesViewDelegate where Target.Input == [Details] {

        var id = UUID()

        private let storeFilesView: StoreFilesView

        var target: Target?

        init(store: Store, filter: Filter) {
            self.storeFilesView = StoreFilesView(store: store, filter: filter)
            super.init()
            self.storeFilesView.delegate = self
            self.storeFilesView.start()
        }

        func request(_ demand: Subscribers.Demand) {}

        func cancel() {
            self.storeFilesView.stop()
            target = nil
            self.storeFilesView.delegate = nil
        }

        func storeFilesView(_ storeFilesView: StoreFilesView,
                            didInsertFile file: Details,
                            atIndex index: Int,
                            files: [Details]) {
            _ = target?.receive(files)
        }

        func storeFilesView(_ storeFilesView: StoreFilesView,
                            didUpdateFiles files: [Details]) {
            _ = target?.receive(files)
        }


        func storeFilesView(_ storeFilesView: StoreFilesView,
                            didUpdateFile file: Details,
                            atIndex index: Int,
                            files: [Details]) {
            _ = target?.receive(files)
        }

        func storeFilesView(_ storeFilesView: StoreFilesView,
                            didRemoveFileWithIdentifier identifier: Details.Identifier,
                            atIndex index: Int,
                            files: [Details]) {
            _ = target?.receive(files)
        }

    }

    typealias Output = [Details]
    typealias Failure = Never

    private var store: Store
    private var filter: Filter

    init(store: Store, filter: Filter) {
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

    func publisher(filter: Filter = TrueFilter()) -> StoreFilesPublisher {
        return StoreFilesPublisher(store: self, filter: filter)
    }

}
