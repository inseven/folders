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

// TODO: Don't forget that there needs to be a mechanism to inflate tags when load files from the database.

protocol Filter {

    var filter: Expression<Bool> { get }  // TODO: Remove this
    var sql: String { get }
    func matches(details: Details) -> Bool

}

struct AnyFilter: Filter {

    let sql: String
    let filter: SQLite.Expression<Bool>
    let _matches: (Details) -> Bool

    init(_ filter: any Filter) {
        self.sql = filter.sql
        self.filter = filter.filter
        _matches = { details in
            filter.matches(details: details)
        }
    }

    func matches(details: Details) -> Bool {
        return _matches(details)
    }

}

extension AnyFilter {

    init(anding filters: [Filter]) {
        self = filters.reduce(AnyFilter(TrueFilter())) { partialResult, filter in
            return AnyFilter(partialResult && AnyFilter(filter))
        }
    }

    init(oring filters: [Filter]) {
        self = filters.reduce(AnyFilter(FalseFilter())) { partialResult, filter in
            return AnyFilter(partialResult || AnyFilter(filter))
        }
    }

}

extension Filter where Self == TypeFilter {

    static func conforms(to type: UTType) -> TypeFilter {
        return TypeFilter.conformsTo(type)
    }

}

extension Filter where Self == ParentFilter {

    static func parent(_ url: URL) -> ParentFilter {
        return ParentFilter(parent: url.path)
    }

    static func parent(_ parent: String) -> ParentFilter {
        return ParentFilter(parent: parent)
    }

}

struct TrueFilter: Filter {

    var sql: String {
        return "true"
    }

    var filter: Expression<Bool> {
        return Expression(value: true)
    }

    func matches(details: Details) -> Bool {
        return true
    }

}

struct FalseFilter: Filter {

    var sql: String {
        return "false"
    }

    var filter: Expression<Bool> {
        return Expression(value: false)
    }

    func matches(details: Details) -> Bool {
        return false
    }

}


struct AndFilter<A: Filter, B: Filter>: Filter {

    let lhs: A
    let rhs: B

    init(_ lhs: A, _ rhs: B) {
        self.lhs = lhs
        self.rhs = rhs
    }

    var sql: String {
        return "(\(lhs.sql)) and (\(rhs.sql))"
    }

    var filter: Expression<Bool> {
        return lhs.filter && rhs.filter
    }

    func matches(details: Details) -> Bool {
        return lhs.matches(details: details) && rhs.matches(details: details)
    }

}

func &&<A: Filter, B: Filter>(lhs: A, rhs: B) -> AndFilter<A, B> {
    return AndFilter(lhs, rhs)
}

struct OrFilter<A: Filter, B: Filter>: Filter {

    let lhs: A
    let rhs: B

    init(_ lhs: A, _ rhs: B) {
        self.lhs = lhs
        self.rhs = rhs
    }

    var sql: String {
        return "(\(lhs.sql)) or (\(rhs.sql))"
    }

    var filter: Expression<Bool> {
        return lhs.filter || rhs.filter
    }

    func matches(details: Details) -> Bool {
        return lhs.matches(details: details) || rhs.matches(details: details)
    }

}

func ||<A: Filter, B: Filter>(lhs: A, rhs: B) -> OrFilter<A, B> {
    return OrFilter(lhs, rhs)
}

enum TypeFilter {

    case conformsTo(UTType)

}

struct ParentFilter: Filter {

    let parent: String

    init(parent: String) {
        self.parent = parent
    }

    // Binding example:
//    let stmt = try db.prepare("INSERT INTO users (email) VALUES (?)")
//    Once prepared, statements may be executed using run, binding any unbound parameters.
//    try stmt.run("alice@mac.com")
//    db.changes // -> {Some 1}

    // TODO: Perhaps the SQL could be give with wildcard expressions for binding?
    var sql: String {
        // TODO: SAFETY SAFETY SAFETY
        return "path like '\(parent)%'"
    }

    var filter: Expression<Bool> {
        // TODO: Delimit parent!
        return Store.Schema.path.like("\(parent)/%")
    }

    func matches(details: Details) -> Bool {
        return details.url.path.starts(with: parent)
    }

}

struct OwnerFilter: Filter {

    let owner: String

    init(owner: String) {
        self.owner = owner
    }

    var sql: String {
        // TODO: SAFETY SAFETY SAFETY
        return "owner = '\(owner)'"
    }

    var filter: Expression<Bool> {
        return Store.Schema.owner == owner
    }

    func matches(details: Details) -> Bool {
        return details.ownerURL.path == owner
    }

}

extension Filter where Self == OwnerFilter {

    static func owner(_ owner: URL) -> OwnerFilter {
        return OwnerFilter(owner: owner.path)
    }

}

// TODO: This doesn't work at all right now!
struct TagFilter: Filter {

    let name: String

    init(name: String) {
        self.name = name
    }

    var sql: String {
        let tagSubselect = """
            SELECT
                file_id
            FROM
                files_to_tags
            JOIN
                tags
            ON
                files_to_tags.tag_id = tags.id
            WHERE
                name = '\(name)'
            """
        return "files.id IN (\(tagSubselect))"
    }

    // TODO: Can I even construct the required expression?
    var filter: Expression<Bool> {

//        let subselect = Store.Schema.filesToTags
//            .join(Store.Schema.tags, on: Store.Schema.tagId == Store.Schema.fileId)
//            .select(Store.Schema.fileId)
//            .where(Store.Schema.name == name)  // TODO: Should tags be case sensitive?
//

        return Store.Schema.owner == name
    }

    func matches(details: Details) -> Bool {
        return true
    }

}

extension Filter where Self == TagFilter {

    static func tag(_ name: String) -> TagFilter {
        return TagFilter(name: name)
    }

}

//        let tagsFilter = Database.Schema.name.lowercaseString == name.lowercased()
//        let tagSubselect = """
//            SELECT
//                item_id
//            FROM
//                items_to_tags
//            JOIN
//                tags
//            ON
//                items_to_tags.tag_id = tags.id
//            WHERE
//                \(tagsFilter.asSQL())
//            """
//        return "items.id IN (\(tagSubselect))"


extension TypeFilter: Filter {

    var sql: String {
        switch self {
        case .conformsTo(let contentType):
            return "type = '\(contentType.identifier)'"
        }
    }

    var filter: Expression<Bool> {
        switch self {
        case .conformsTo(let contentType):
            return Store.Schema.type == contentType.identifier
        }
    }

    func matches(details: Details) -> Bool {
        switch self {
        case .conformsTo(let contentType):
            return details.contentType == contentType
        }
    }

}

func defaultTypesFilter() -> AnyFilter {
    return AnyFilter(.conforms(to: .pdf)
                     || .conforms(to: .jpeg)
                     || .conforms(to: .gif)
                     || .conforms(to: .png)
                     || .conforms(to: .video)
                     || .conforms(to: .mpeg4Movie)
                     || .conforms(to: .cbr)
                     || .conforms(to: .cbz)
                     || .conforms(to: .stl)
                     || .conforms(to: .mp3)
                     || .conforms(to: .tap)
                     || .conforms(to: .mkv)
                     || .conforms(to: .bmp)
                     || .conforms(to: .webP)
                     || .conforms(to: .ico)
                     || .conforms(to: .avi)
                     || .conforms(to: .pbm)
                     || .conforms(to: .tiff))
}

func defaultFilter(owner ownerURL: URL, parent parentURL: URL) -> Filter {
    return .owner(ownerURL) && .parent(parentURL) && defaultTypesFilter()
}

func identifierFilter(identifier: Details.Identifier) -> AndFilter<OwnerFilter, ParentFilter> {
    return .owner(identifier.ownerURL) && .parent(identifier.url)
}

func defaultFilter(identifiers: Set<Details.Identifier>) -> Filter {
    return AnyFilter(oring: (identifiers.map { identifier in
        return identifierFilter(identifier: identifier) && defaultTypesFilter()
    }))
}
