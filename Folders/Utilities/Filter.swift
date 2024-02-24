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


protocol Filter {

    var filter: Expression<Bool> { get }
    func matches(details: Details) -> Bool

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

    var filter: Expression<Bool> {
        return Expression(value: true)
    }

    func matches(details: Details) -> Bool {
        return true
    }

}

struct AndFilter<A: Filter, B: Filter>: Filter {

    let lhs: A
    let rhs: B

    init(_ lhs: A, _ rhs: B) {
        self.lhs = lhs
        self.rhs = rhs
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

    var filter: Expression<Bool> {
        return Store.Schema.path.like("\(parent)%")
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

extension TypeFilter: Filter {

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
