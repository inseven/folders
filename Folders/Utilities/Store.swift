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

    func store(_ store: Store, didInsertFiles files: [Details])
    func store(_ store: Store, didUpdateFiles files: [Details])
    func store(_ store: Store, didRemoveFilesWithIdentifiers identifiers: [Details.Identifier])

}

class Store {

    struct Schema {
        static let files = Table("files")
        static let id = Expression<Int64>("id")
        static let uuid = Expression<UUID>("uuid")
        static let owner = Expression<String>("owner")
        static let path = Expression<String>("path")
        static let name = Expression<String>("name")
        static let type = Expression<String>("type")
        static let modificationDate = Expression<Int>("modification_date")
    }

    static let majorVersion = 48

    var observers: [StoreObserver] = []

    let databaseURL: URL
    let syncQueue = DispatchQueue(label: "Store.syncQueue")
    let connection: Connection

    static var migrations: [Int32: (Connection) throws -> Void] = [
        1: { connection in
            print("create the files table...")
            try connection.run(Schema.files.create(ifNotExists: true) { t in
                t.column(Schema.id, primaryKey: true)  // TODO: I could maybe drop this for the uuid?
                t.column(Schema.uuid)
                t.column(Schema.owner)
                t.column(Schema.path)
                t.column(Schema.name)
                t.column(Schema.type)
                t.column(Schema.modificationDate)
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

    func insertBlocking(files: any Collection<Details>) throws {
        return try runBlocking { [connection] in
            try connection.transaction {

                var insertions = [Details]()
                for file in files {

                    // Check to see if the URL exists already.
                    let existingURL = try connection.pluck(Schema.files.filter(Schema.path == file.url.path).limit(1))
                    guard existingURL == nil else {
                        continue
                    }

                    // If it does not, we insert it.
                    try connection.run(Schema.files.insert(or: .fail,
                                                           Schema.uuid <- file.uuid,
                                                           Schema.owner <- file.ownerURL.path,
                                                           Schema.path <- file.url.path,
                                                           Schema.name <- file.url.displayName,
                                                           Schema.type <- file.contentType.identifier,
                                                           Schema.modificationDate <- file.contentModificationDate))

                    // Track the inserted files to notify our observers.
                    insertions.append(file)
                }
                for observer in self.observers {
                    DispatchQueue.global(qos: .default).async {
                        observer.store(self, didInsertFiles: insertions)
                    }
                }

            }
        }
    }

    func updateBlocking(files: any Collection<Details>) throws {
        return try runBlocking { [connection] in
            try connection.transaction {
                var updates = [Details]()
                for file in files {
                    let row = Schema.files.filter(Schema.uuid == file.uuid)
                    let count = try connection.run(row.update(Schema.owner <- file.ownerURL.path,
                                                              Schema.path <- file.url.path,
                                                              Schema.name <- file.url.displayName,
                                                              Schema.type <- file.contentType.identifier,
                                                              Schema.modificationDate <- file.contentModificationDate))
                    if count > 0 {
                        updates.append(file)
                    }
                }
                for observer in self.observers {
                    DispatchQueue.global(qos: .default).async {
                        observer.store(self, didUpdateFiles: updates)
                    }
                }
            }
        }
    }

    func removeBlocking(identifiers: any Collection<Details.Identifier>) throws {
        guard identifiers.count > 0 else {
            return
        }
        return try runBlocking { [connection] in
            try connection.transaction {
                var removals = [Details.Identifier]()
                for identifier in identifiers {
                    let count = try connection.run(Schema.files.filter(Schema.owner == identifier.ownerURL.path && Schema.path == identifier.url.path).delete())
                    if count > 0 {
                        removals.append(identifier)
                    }
                }
                guard removals.count > 0 else {
                    return
                }
                for observer in self.observers {
                    DispatchQueue.global(qos: .default).async {
                        observer.store(self, didRemoveFilesWithIdentifiers: removals)
                    }
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

    func syncQueue_files(filter: Filter, sort: Sort) throws -> [Details] {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        return try connection.prepareRowIterator(Schema.files.select(Schema.files[*])
            .filter(filter.filter)
            .order(sort.order))
        .map { row in
            let type = UTType(row[Schema.type])!
            let ownerURL = URL(filePath: row[Schema.owner], directoryHint: .isDirectory)
            let url = URL(filePath: row[Schema.path],
                          directoryHint: type.conforms(to: .directory) ? .isDirectory : .notDirectory)
            let modificationDate = row[Schema.modificationDate]
            let uuid = row[Schema.uuid]
            return Details(uuid: uuid,
                           ownerURL: ownerURL,
                           url: url,
                           contentType: type,
                           contentModificationDate: modificationDate)
        }
    }

    func filesBlocking(filter: Filter, sort: Sort) throws -> [Details] {
        return try runBlocking {
            return try self.syncQueue_files(filter: filter, sort: sort)
        }
    }

    func files(filter: Filter, sort: Sort) async throws -> [Details] {
        return try await run {
            return try self.syncQueue_files(filter: filter, sort: sort)
        }
    }

}
