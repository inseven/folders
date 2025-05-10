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

protocol Filter {

    var statement: BoundStatement { get }
    func matches(details: Details) -> Bool

}

struct AnyFilter: Filter {

    var statement: BoundStatement
    let _matches: (Details) -> Bool

    init(_ filter: any Filter) {
        self.statement = filter.statement
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

extension Filter where Self == ParentFilter {

    static func parent(_ url: URL) -> ParentFilter {
        return ParentFilter(parent: url.path)
    }

    static func parent(_ parent: String) -> ParentFilter {
        return ParentFilter(parent: parent)
    }

}

struct TrueFilter: Filter {

    var statement: BoundStatement {
        return BoundStatement(sql: "true", bindings: [])
    }

    func matches(details: Details) -> Bool {
        return true
    }

}

struct FalseFilter: Filter {

    var statement: BoundStatement {
        return BoundStatement(sql: "false", bindings: [])
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

    var statement: BoundStatement {
        return BoundStatement(sql: "(\(lhs.statement.sql)) and (\(rhs.statement.sql))",
                          bindings: lhs.statement.bindings + rhs.statement.bindings)
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

    var statement: BoundStatement {
        return BoundStatement(sql: "(\(lhs.statement.sql)) or (\(rhs.statement.sql))",
                          bindings: lhs.statement.bindings + rhs.statement.bindings)
    }

    func matches(details: Details) -> Bool {
        return lhs.matches(details: details) || rhs.matches(details: details)
    }

}

func ||<A: Filter, B: Filter>(lhs: A, rhs: B) -> OrFilter<A, B> {
    return OrFilter(lhs, rhs)
}

struct TypeFilter: Filter {

    let types: Set<UTType>

    init(types: Set<UTType>) {
        self.types = types
    }

    var statement: BoundStatement {
        let matches = types
            .map { _ in "type = ?" }
            .joined(separator: " or ")
        return BoundStatement(sql: matches, bindings: types.map({ $0.identifier }))
    }

    func matches(details: Details) -> Bool {
        return types.contains(details.contentType)
    }

}

extension Filter where Self == TypeFilter {

    static func conforms(to types: Set<UTType>) -> TypeFilter {
        return TypeFilter(types: types)
    }

}

struct ParentFilter: Filter {

    let parent: String

    init(parent: String) {
        self.parent = parent
    }

    var statement: BoundStatement {
        return BoundStatement(sql: "path like ?", bindings: [parent + "/%"])
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

    var statement: BoundStatement {
        return BoundStatement(sql: "owner = ?", bindings: [owner])
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

struct URLFilter: Filter {

    let path: String

    init(path: String) {
        self.path = path
    }

    var statement: BoundStatement {
        return BoundStatement(sql: "path = ?", bindings: [path])
    }

    func matches(details: Details) -> Bool {
        return details.url.path == path
    }

}

extension Filter where Self == URLFilter {

    static func url(_ url: URL) -> URLFilter {
        return URLFilter(path: url.path)
    }

}

struct TagFilter: Filter {

    let name: String

    init(name: String) {
        self.name = name
    }

    var statement: BoundStatement {
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
                name = ?
            """
        return BoundStatement(sql: "files.id IN (\(tagSubselect))", bindings: [name])
    }

    func matches(details: Details) -> Bool {
        return details.tags?.contains(name) ?? false
    }

}

extension Filter where Self == TagFilter {

    static func tag(_ name: String) -> TagFilter {
        return TagFilter(name: name)
    }

}

func defaultTypesFilter() -> TypeFilter {
    return TypeFilter(types: [
        .avi,
        .bmp,
        .cbr,
        .cbz,
        .gif,
        .html,
        .ico,
        .jpeg,
        .m4v,
        .mkv,
        .mov,
        .mp3,
        .mpeg4Movie,
        .pbm,
        .pdf,
        .png,
        .stl,
        .svg,
        .tap,
        .tiff,
        .video,
        .webArchive,
        .webP,
    ])
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
