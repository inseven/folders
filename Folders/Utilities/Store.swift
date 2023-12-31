// MIT License
//
// Copyright (c) 2023 Jason Barrie Morley
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

import SQLite

// TODO: Does this need to be an NSObject?
protocol StoreObserver: NSObject {

    func store(_ store: Store, didInsertURL url: URL)
    func store(_ store: Store, didRemoveURL url: URL)

}

class Store {

    struct Schema {
        static let files = Table("files")
        static let url = Expression<String>("url")
        static let name = Expression<String>("name")
    }

    var observers: [StoreObserver] = []

    let databaseURL: URL
    let syncQueue = DispatchQueue(label: "Store.syncQueue")
    let connection: Connection

    static var migrations: [Int32: (Connection) throws -> Void] = [
        1: { connection in
            print("create the files table...")
            try connection.run(Schema.files.create(ifNotExists: true) { t in
                t.column(Schema.url, primaryKey: true)
                t.column(Schema.name)
            })
        },
    ]

    static var schemaVersion: Int32 = Array(migrations.keys).max() ?? 0

    init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        self.connection = try Connection(databaseURL.path)
        try syncQueue.sync(flags: .barrier) {
            try self.syncQueue_migrate()
        }
    }

    func add(observer: StoreObserver) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            observers.append(observer)
        }
    }

    // TODO: This feels janky. It might be a cleaner API to return an 'observer' instead.
    func remove(observer: StoreObserver) {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        syncQueue.sync {
            // TODO: This might be insufficient unless we use some kind of thread-safe cancel operation.
            observers.removeAll { $0.isEqual(observer) }
        }
    }

    private func run<T>(perform: @escaping () throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            syncQueue.async {
                let result = Swift.Result<T, Error> {
                    try Task.checkCancellation()
                    return try perform()
                }
                continuation.resume(with: result)
            }
        }
    }

    // TODO: This can't be cancelled?
    private func runBlocking<T>(perform: @escaping () throws -> T) throws -> T {
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        // TODO: IS THIS QUEUE REALLY NEEDED?
        var result: Swift.Result<T, Error>? = nil
        syncQueue.sync {
            result = Swift.Result<T, Error> {
                return try perform()
            }
        }
        switch result! {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    private func syncQueue_migrate() throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        try connection.transaction {
            let currentVersion = connection.userVersion ?? 0
            print("version \(currentVersion)")
            guard currentVersion < Self.schemaVersion else {
                print("schema up to date")
                return
            }
            for version in currentVersion + 1 ... Self.schemaVersion {
                print("migrating to \(version)...")
                guard let migration = Self.migrations[version] else {
                    throw FoldersError.unknownSchemaVersion(version)
                }
                try migration(self.connection)
                connection.userVersion = version
            }
        }
    }

    func insertBlocking(url: URL) throws {
        return try runBlocking { [connection] in
            try connection.transaction {

                // Check to see if the URL exists already.
                let existingURL = try connection.pluck(Schema.files.filter(Schema.url == url.path).limit(1))
                guard existingURL == nil else {
                    return
                }

                // If it does not, we insert it.
                try connection.run(Schema.files.insert(or: .fail,
                                                       Schema.url <- url.path,
                                                       Schema.name <- url.displayName))
                for observer in self.observers {
                    DispatchQueue.global(qos: .default).async {
                        observer.store(self, didInsertURL: url)
                    }
                }

            }
        }
    }

    func removeBlocking(url: URL) throws {
        return try runBlocking { [connection] in
            let count = try connection.run(Schema.files.filter(Schema.url == url.path).delete())
            print("Deleted \(count) rows.")
            if count > 0 {
                for observer in self.observers {
                    DispatchQueue.global(qos: .default).async {
                        observer.store(self, didRemoveURL: url)
                    }
                }
            }
        }
    }

    func files(parent: URL) async throws -> [URL] {
        return try await run { [connection] in
            print("FILTER: \(parent.path)")
            return try connection.prepareRowIterator(Schema.files.select(Schema.url)
                .filter(Schema.url.like("\(parent.path)%"))
                .order(Schema.name.desc))
                .map { URL(filePath: $0[Schema.url]) }
        }
    }

}
