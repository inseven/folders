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

// TODO: Explore whether prepared queries improve performance.
class Store {

    protocol Observer: NSObject {

        func store(_ store: Store, didInsertFiles files: [Details])
        func store(_ store: Store, didUpdateFiles files: [Details])
        func store(_ store: Store, didRemoveFilesWithIdentifiers identifiers: [Details.Identifier])

        func store(_ store: Store, didInsertTags tags: [Tag])
        func store(_ store: Store, didRemoveTags tags: [Tag])

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
        static let source = Expression<Tag.Source>("source")
    }

    // TODO: This represents an external management of the database an should probably be moved out.
    static let majorVersion = 53

    private var observers: [Observer] = []

    private let databaseURL: URL
    private let syncQueue = DispatchQueue(label: "Store.syncQueue")  // TODO: Check if this is necessary
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
                t.column(Schema.source)
                t.column(Schema.name, unique: true)
                t.unique(Schema.source, Schema.name)
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

    private func run<T>(perform: @escaping () throws -> T) throws -> T {
        dispatchPrecondition(condition: .notOnQueue(.main))
        dispatchPrecondition(condition: .notOnQueue(syncQueue))
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

    // N.B. This function does not make any effort to notify observers to allow batching of insertion notifications.
    //      One possible way to improve on this and make it a little less likely that callers forget to notify our
    //      observers of new tags would be to make it take an array of items to insert. Or perhaps we could
    //      use the transaction archtiecture to track and batch notifications and then automatically dispatch them at
    //      the close of a transaction.
    // TODO: Cache tag identifiers to avoid unnecessary database queries when inserting tags.
    private func syncQueue_fetchOrInsertTag(tag: Tag, isNew: inout Bool) throws -> Int64 {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        if let id = try? syncQueue_tag(tag: tag) {
            isNew = false
            return id
        }
        let id = try connection.run(Schema.tags.insert(
            Schema.source <- tag.source,
            Schema.name <- tag.name
        ))
        isNew = true
        return id
    }

    private func syncQueue_tag(tag: Tag) throws -> Int64 {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        let results = try connection.prepare(
            Schema.tags
                .filter(Schema.source == tag.source)
                .filter(Schema.name == tag.name)
                .limit(1)
        ).map { row in
            try row.get(Schema.id)
        }
        guard let result = results.first else {
            throw FoldersError.unknownTag(tag)
        }
        return result
    }

    private func syncQueue_pruneTags() throws -> [Tag] {
        dispatchPrecondition(condition: .onQueue(syncQueue))

        // Look up the set of tags we're about to delete so we can return them to the caller.
        let deletions = try self.connection.prepare("""
            SELECT
                source,
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
        """).map { row -> Tag in
            return Tag(source: Tag.Source(rawValue: Int(row[0] as! Int64))!,
                       name: row[1] as! String)
        }

        guard !deletions.isEmpty else {
            return []
        }

        // Actually perform the deletions.
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

    // N.B. Metadata is stored normalized. Tags are treated as a special case as there's a n-to-n relationship between
    //      files and tags whereas, for most other metadata, I anticipate a 1-to-n relationship.
    //      Metadata (properties and tags) are available on the file model objects but they're all nullable to indicate
    //      they've not been loaded. If these properties are null, they'll be ignored in mutations, otherwise they'll
    //      be treated as updates.
    fileprivate func syncQueue_insert(files: any Collection<Details>) throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        try connection.transaction {

            var insertions: [Details] = []
            var tagInsertions: [Tag] = []
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
                if let tags = file.tags?.map({ Tag(source: .filename, name: $0) }) {
                    for tag in tags {
                        var isNew: Bool = false
                        let tagId = try syncQueue_fetchOrInsertTag(tag: tag, isNew: &isNew)
                        try connection.run(Schema.filesToTags.insert(or: .replace,
                                                                     Schema.fileId <- fileId,
                                                                     Schema.tagId <- tagId))
                        if isNew {
                            tagInsertions.append(tag)
                        }
                    }
                }

                // Track the inserted files to notify our observers.
                insertions.append(file)
            }

            observerLock.withLock {
                for observer in observers {
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
    // TODO: Check where this is actually used.
    func syncQueue_update(files: any Collection<Details>) throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
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
            observerLock.withLock {
                for observer in observers {
                    DispatchQueue.global(qos: .default).async {
                        observer.store(self, didUpdateFiles: updates)
                    }
                }
            }
        }
    }

    fileprivate func syncQueue_remove(identifiers: any Collection<Details.Identifier>) throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
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
            observerLock.withLock {
                for observer in observers {
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

    fileprivate func syncQueue_remove(owner: URL) throws {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        try connection.transaction {
            let files = try self.syncQueue_files(filter: .owner(owner), sort: .displayNameAscending)
            try connection.run(Schema.files.filter(Schema.owner == owner.path).delete())
            let tagRemovals = try self.syncQueue_pruneTags()
            observerLock.withLock {
                for observer in observers {
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

        let selectQuery = """
            SELECT
                *
            FROM
                files
            WHERE
                \(filter.sql.0)
            ORDER BY
                \(sort.sql)
            """

        return try connection.prepareRowIterator(selectQuery, bindings: filter.sql.1)
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

    fileprivate func syncQueue_tags() throws -> [Tag] {
        dispatchPrecondition(condition: .onQueue(syncQueue))
        return try connection.prepareRowIterator(
            Schema.tags
                .select(Schema.source, Schema.name)
                .order(Store.Schema.name.asc))
        .map { row in
            Tag(source: row[Schema.source], name: row[Schema.name])
        }
    }

}

extension Store {

    func insert(files: any Collection<Details>) throws {
        return try run {
            try self.syncQueue_insert(files: files)
        }
    }

    func remove(owner: URL) throws {
        try run {
            try self.syncQueue_remove(owner: owner)
        }
    }

    func files(filter: Filter, sort: Sort) throws -> [Details] {
        return try run {
            return try self.syncQueue_files(filter: filter, sort: sort)
        }
    }

    func tags() throws -> [Tag] {
        return try run {
            return try self.syncQueue_tags()
        }
    }

    func remove(identifiers: any Collection<Details.Identifier>) throws {
        try run {
            try self.syncQueue_remove(identifiers: identifiers)
        }
    }

    func update(files: any Collection<Details>) throws {
        try run {
            try self.syncQueue_update(files: files)
        }
    }

}
