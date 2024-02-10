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

extension Filter {

    static func conforms(to type: UTType) -> Filter {
        return TypeFilter.conformsTo(type)
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
        return Store.Schema.url.like("\(parent)%")
    }

    func matches(details: Details) -> Bool {
        return details.url.path.starts(with: parent)
    }

}

extension TypeFilter: Filter {

    var filter: Expression<Bool> {
        switch self {
        case .conformsTo(let contentType):
            var expression = Expression<Bool?>(value: true)
            if let type = contentType.type {
                expression = expression && Store.Schema.type == type
            }
            if let subtype = contentType.subtype, subtype != "*" {
                expression = expression && Store.Schema.subtype == subtype
            }
            return expression ?? false
        }
    }

    func matches(details: Details) -> Bool {
        switch self {
        case .conformsTo(let contentType):
            guard let type = contentType.type else {
                return true
            }
            guard details.contentType.type == type else {
                return false
            }
            guard let subtype = contentType.subtype, subtype != "*" else {
                return true
            }
            guard details.contentType.subtype == subtype else {
                return false
            }
            return true
        }
    }

}
