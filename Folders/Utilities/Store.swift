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

protocol StoreObserver: NSObject {

    func store(_ store: Store, didInsert details: Details)
    func store(_ store: Store, didRemoveURL url: URL)

}

class Store {

    struct Schema {
        static let files = Table("files")
        static let id = Expression<Int64>("id")
        static let owner = Expression<String>("owner")
        static let path = Expression<String>("path")  // TODO: Path?
        static let name = Expression<String>("name")
        static let type = Expression<String>("type")
    }

    static let majorVersion = 25

    var observers: [StoreObserver] = []

    let databaseURL: URL
    let syncQueue = DispatchQueue(label: "Store.syncQueue")
    let connection: Connection

    static var migrations: [Int32: (Connection) throws -> Void] = [
        1: { connection in
            print("create the files table...")
            try connection.run(Schema.files.create(ifNotExists: true) { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.owner)
                t.column(Schema.path)
                t.column(Schema.name)
                t.column(Schema.type)
            })
            try connection.run(Schema.files.createIndex(Schema.path))
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

    func insertBlocking(details: Details) throws {
        return try runBlocking { [connection] in
            try connection.transaction {

                // Check to see if the URL exists already.
                let existingURL = try connection.pluck(Schema.files.filter(Schema.path == details.url.path).limit(1))
                guard existingURL == nil else {
                    return
                }

                // If it does not, we insert it.
                try connection.run(Schema.files.insert(or: .fail,
                                                       Schema.owner <- details.owner.path,
                                                       Schema.path <- details.url.path,
                                                       Schema.name <- details.url.displayName,
                                                       Schema.type <- details.contentType.identifier))
                for observer in self.observers {
                    DispatchQueue.global(qos: .default).async {
                        observer.store(self, didInsert: details)
                    }
                }

            }
        }
    }

    func removeBlocking(url: URL) throws {
        return try runBlocking { [connection] in
            let count = try connection.run(Schema.files.filter(Schema.path == url.path).delete())
            print("Deleted \(count) rows.")
            guard count > 0 else {
                return
            }
            for observer in self.observers {
                DispatchQueue.global(qos: .default).async {
                    observer.store(self, didRemoveURL: url)
                }
            }
        }
    }

    func removeBlocking(owner: URL) throws {
        return try runBlocking { [connection] in
            let count = try connection.run(Schema.files.filter(Schema.owner == owner.path).delete())
            print("Deleted \(count) rows.")
            // TODO: Consider notifying our clients (though this is probably unnecessary and noisy).
        }
    }

    // TODO: Convenience constructor?
    func mime(type: String?, subtype: String?) -> String {
        guard let type else {
            return "*"
        }
        guard let subtype else {
            return "\(type)/*"
        }
        return "\(type)/\(subtype)"
    }

    func files(filter: Filter, sort: Sort) async throws -> [Details] {
        return try await run { [connection] in
            return try connection.prepareRowIterator(Schema.files.select(Schema.owner, Schema.path, Schema.type)
                .filter(filter.filter)
                .order(sort.order))
            .map { row in
                // TODO: Support opaque owners?
                let type = UTType(row[Schema.type])!
                let owner = URL(filePath: row[Schema.owner], directoryHint: .isDirectory)
                let url = URL(filePath: row[Schema.path], directoryHint: type == .folder ? .isDirectory : .notDirectory)


                // TODO: Should the mime type be required?
                // TODO: This isn't guarnateed to reconstruct the correct UTType

                return Details(owner: owner, url: url, contentType: type)
            }
        }
    }

}
