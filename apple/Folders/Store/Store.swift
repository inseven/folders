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

import SQLite

// TODO: Am I conflating the store with its threading architecture here? Should the queue management happen externally?
// TODO: Are all the operations actually blocking??? I think they might be. Which definitley makes things easier.
// TODO: Prepared queries for performance?
class Store {

    // TODO: File Observer and tag observer?
    protocol Observer: NSObject {

        func store(_ store: Store, didInsertFiles files: [Details])
        func store(_ store: Store, didUpdateFiles files: [Details])
        func store(_ store: Store, didRemoveFilesWithIdentifiers identifiers: [Details.Identifier])

        func store(_ store: Store, didInsertTags tags: [String])
        func store(_ store: Store, didRemoveTags tags: [String])

    }

    struct Schema {

        static let files = Table("files")
        static let tags = Table("tags")
        static let filesToTags = Table("files_to_tags")

        static let id = Expression<Int64>("id")
        static let fileId = Expression<Int64>("file_id")
        static let tagId = Expression<Int64>("tag_id")

        static let uuid = Expression<UUID>("uuid")
        static let owner = Expression<String>("owner")
        static let path = Expression<String>("path")
        static let name = Expression<String>("name")
        static let type = Expression<String>("type")
        static let modificationDate = Expression<Int>("modification_date")
    }

    static let majorVersion = 49

    private var observers: [Observer] = []

    private let databaseURL: URL
    private let syncQueue = DispatchQueue(label: "Store.syncQueue")
    private let connection: Connection
    private let observerLock = NSRecursiveLock()

    private static var migrations: [Int32: (Connection) throws -> Void] = [
        1: { connection in
            print("create the files table...")
            try connection.run(Schema.files.create(ifNotExists: true) { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.uuid)
                t.column(Schema.owner)
                t.column(Schema.path)
                t.column(Schema.name)
                t.column(Schema.type)
                t.column(Schema.modificationDate)
            })
            try connection.run(Schema.files.createIndex(Schema.path))
        },
        2: { connection in
            print("create the tags table...")
            try connection.run(Schema.tags.create(ifNotExists: true) { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.name, unique: true)
            })
            print("create the files_to_tags table...")
            try connection.run(Schema.filesToTags.create(ifNotExists: true) { t in
                t.column(Schema.id, primaryKey: true)
                t.column(Schema.fileId)
                t.column(Schema.tagId)
                t.unique(Schema.fileId, Schema.tagId)
                t.foreignKey(Schema.fileId, references: Schema.files, Schema.id, delete: .cascade)
                t.foreignKey(Schema.tagId, references: Schema.tags, Schema.id, delete: .cascade)
            })
        }
    ]

    private static var schemaVersion: Int32 = Array(migrations.keys).max() ?? 0

    init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        self.connection = try Connection(databaseURL.path)
        try syncQueue.sync(flags: .barrier) {
            try self.syncQueue_migrate()
            connection.foreignKeys = true
        }
    }

    func add(observer: Observer) {
        observerLock.withLock {
            self.observers.append(observer)
        }
    }

    func remove(observer: Observer) {
        // Since we guarantee that we only ever notify our delegates while holding the observer lock, we can guarantee
        // that when we exit from this function, `observer` will never receive another callback.
        observerLock.withLock {
            observers.removeAll { $0.isEqual(observer) }
        }
    }

    // TODO: Rename this?
    private func runBlocking<T>(perform: @escaping () throws -> T) throws -> T {
        dispatchPrecondition(condition: .notOnQueue(.main))
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
        var result: Swift.Result<T, Error>? = nil
        syncQueue.sync {  // TODO: Is the syncQueue necessary?
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

//    private func syncQueue_insertOrReplace(bookmark: Bookmark) throws {
//        let tags = try bookmark.tags.map { try syncQueue_fetchOrInsertTag(name: $0) }
//        let itemId = try self.db.run(Schema.items.insert(or: .replace,
//                                                         Schema.identifier <- bookmark.identifier,
//                                                         Schema.title <- bookmark.title,
//                                                         Schema.url <- bookmark.url.absoluteString,
//                                                         Schema.date <- bookmark.date,
//                                                         Schema.toRead <- bookmark.toRead,
//                                                         Schema.shared <- bookmark.shared,
//                                                         Schema.notes <- bookmark.notes))
//        for tagId in tags {
//            _ = try self.db.run(Schema.items_to_tags.insert(or: .replace,
//                                                            Schema.itemId <- itemId,
//                                                            Schema.tagId <- tagId))
//        }
//        try syncQueue_pruneTags()
//    }

    // TODO: Cleaner return type.
    // N.B. This function does not make any effort to notify observers to allow batching of insertion notifications.
    //      One possible way to improve on this and make it a little less likely that callers forget to notify our
    //      observers of new tags would be to make it take an array of items to insert. Or perhaps we could
    //      use the transaction archtiecture to track and batch notifications and then automatically dispatch them at
    //      the close of a transaction.
    private func syncQueue_fetchOrInsertTag(name: String) throws -> (Int64, Bool) {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        if let id = try? syncQueue_tag(name: name) {
            return (id, false)
        }
        let id = try connection.run(Schema.tags.insert(
            Schema.name <- name
        ))
        return (id, true)
    }

    // TODO: Pluck?
    // TODO: Cache tags since the performance of this would suuuuuuck if we're dealing with a lot of files.
    // TODO: Double check the query API and if it could be cleaner?
    private func syncQueue_tag(name: String) throws -> Int64 {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        let results = try connection.prepare(Schema.tags.filter(Schema.name == name).limit(1)).map { row in
            try row.get(Schema.id)
        }
        guard let result = results.first else {
            throw FoldersError.unknownTag(name)
        }
        return result
    }

    // TODO: Use the query builder for this.
    private func syncQueue_pruneTags() throws -> [String] {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        // First we want to look up the set of tags we're about to delete.
        // TODO: Can I actually do this using the typesafe stuff?
        let deletions = try self.connection.prepare("""
            SELECT
                name
            FROM
                tags
            WHERE
                id NOT IN (
                    SELECT
                        tag_id
                    FROM
                        files_to_tags
                )            
        """).map { row in
            return row[0] as! String
        }

        guard !deletions.isEmpty else {
            return []
        }

        try self.connection.run("""
            DELETE
            FROM
                tags
            WHERE
                id NOT IN (
                    SELECT
                        tag_id
                    FROM
                        files_to_tags
                )
            """)

        return deletions
    }

    // N.B. Metadata is stored normalized. Tags are treated as a special case as there's a 1-to-n relationship between
    //      files and tags whereas, for most other metadata, I anticipate a 1-to-1 relationship.
    //      Metadata (properties and tags) are available on the file model objects but they're all nullable to indicate
    //      they've not been loaded. If these properties are null, they'll be ignored in mutations, otherwise they'll
    //      be treated as updates.
    fileprivate func syncQueue_insert(files: any Collection<Details>) throws {
        try connection.transaction {

            var insertions: [Details] = []
            var tagInsertions: [String] = []
            for file in files {  // TODO: Consistent naming.

                // Check to see if the URL exists already.
                // TODO: This should be a bug as it means the database is potentially out of date.
                let existingURL = try connection.pluck(Schema.files.filter(Schema.path == file.url.path).limit(1))
                guard existingURL == nil else {
                    continue
                }

                // If it does not, we insert it.
                let fileId = try connection.run(Schema.files.insert(or: .fail,
                                                                    Schema.uuid <- file.uuid,
                                                                    Schema.owner <- file.ownerURL.path,
                                                                    Schema.path <- file.url.path,
                                                                    Schema.name <- file.url.displayName,
                                                                    Schema.type <- file.contentType.identifier,
                                                                    Schema.modificationDate <- file.contentModificationDate))

                // Create and link the tags if they're non-nil.
                if let tags = file.tags {
                    for tag in tags {
                        let (tagId, isNew) = try syncQueue_fetchOrInsertTag(name: tag)
                        try connection.run(Schema.filesToTags.insert(or: .replace,
                                                                     Schema.fileId <- fileId,
                                                                     Schema.tagId <- tagId))
                        if isNew {
                            tagInsertions.append(tag)
                        }
                    }
                }

                // Track the inserted files to notify our observers.
                // TODO: Our store needs to be able to 'inflate' queries to include metadata as it's not guaranteed.
                insertions.append(file)
            }

            // TODO: This shouldn't actually be necessary as we should only ever be inserting new files.
//            try syncQueue_pruneTags()

            self.observerLock.withLock {
                for observer in self.observers {
                    DispatchQueue.global(qos: .default).async {  // TODO: I think each observer should have a serial queue for updates.
                        if !insertions.isEmpty {  // TODO: Is this check necessary
                            observer.store(self, didInsertFiles: insertions)
                        }
                        if !tagInsertions.isEmpty {
                            observer.store(self, didInsertTags: tagInsertions)
                        }
                    }
                }
            }
        }
    }

    // TODO: Support updating tags.
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
                self.observerLock.withLock {
                    for observer in self.observers {
                        DispatchQueue.global(qos: .default).async {
                            observer.store(self, didUpdateFiles: updates)
                        }
                    }
                }
            }
        }
    }

    func removeBlocking(identifiers: any Collection<Details.Identifier>) throws {
        return try runBlocking { [connection] in
            guard identifiers.count > 0 else {
                return
            }
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
                let tagRemovals = try self.syncQueue_pruneTags()
                self.observerLock.withLock {
                    for observer in self.observers {
                        DispatchQueue.global(qos: .default).async {
                            // TODO: It'd be really great to be able to move this to a per-transaction tracker.
                            if !removals.isEmpty {
                                observer.store(self, didRemoveFilesWithIdentifiers: removals)
                            }
                            if !tagRemovals.isEmpty {
                                observer.store(self, didRemoveTags: tagRemovals)
                            }
                        }
                    }
                }
            }
        }
    }

    fileprivate func syncQueue_remove(owner: URL) throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        try connection.transaction {
            let files = try self.syncQueue_files(filter: .owner(owner), sort: .displayNameAscending)
            try connection.run(Schema.files.filter(Schema.owner == owner.path).delete())
            let tagRemovals = try self.syncQueue_pruneTags()
            self.observerLock.withLock {
                for observer in self.observers {
                    DispatchQueue.global(qos: .default).async {
                        if !files.isEmpty {
                            observer.store(self, didRemoveFilesWithIdentifiers: files.map({ $0.identifier }))
                        }
                        if !tagRemovals.isEmpty {
                            observer.store(self, didRemoveTags: tagRemovals)
                        }
                    }
                }
            }
        }
    }

    fileprivate func syncQueue_files(filter: Filter, sort: Sort) throws -> [Details] {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        // TODO: Support ordering.
        let selectQuery = """
            SELECT
                *
            FROM
                files
            WHERE
                \(filter.sql.0)
            """

        print(selectQuery)

        return try connection.prepareRowIterator(selectQuery, bindings: filter.sql.1)
//            .filter(filter.filter)
//            .order(sort.order)
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
                           contentModificationDate: modificationDate,
                           tags: nil)
        }
    }

    fileprivate func syncQueue_tags(sort: Sort) throws -> [String] {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        return try connection.prepareRowIterator(Schema.tags.select(Schema.name)
            .order(sort.order))
        .map { row in
            row[Schema.name]
        }
    }

}

// TODO: These are all blocking by design. Rename them.
extension Store {

    func insertBlocking(files: any Collection<Details>) throws {
        return try runBlocking {
            try self.syncQueue_insert(files: files)
        }
    }

    func removeBlocking(owner: URL) throws {
        try runBlocking {
            try self.syncQueue_remove(owner: owner)
        }
    }

    func filesBlocking(filter: Filter, sort: Sort) throws -> [Details] {
        return try runBlocking {
            return try self.syncQueue_files(filter: filter, sort: sort)
        }
    }

    func tagsBlocking(sort: Sort) throws -> [String] {
        return try runBlocking {
            return try self.syncQueue_tags(sort: sort)
        }
    }

}
