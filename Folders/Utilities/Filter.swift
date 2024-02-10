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

    var filter: Expression<Bool?> { get }

}

extension Filter {

    static func conforms(to type: UTType) -> Filter {
        return TypeFilter.conformsTo(type)
    }

}

struct TrueFilter: Filter {

    var filter: Expression<Bool?> {
        return Expression(value: true)
    }

}

struct AndFilter<A: Filter, B: Filter>: Filter {

    let lhs: A
    let rhs: B

    init(_ lhs: A, _ rhs: B) {
        self.lhs = lhs
        self.rhs = rhs
    }

    var filter: Expression<Bool?> {
        return lhs.filter && rhs.filter
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

    var filter: Expression<Bool?> {
        return lhs.filter || rhs.filter
    }

}

func ||<A: Filter, B: Filter>(lhs: A, rhs: B) -> OrFilter<A, B> {
    return OrFilter(lhs, rhs)
}

enum TypeFilter {

    case conformsTo(UTType)

}

extension TypeFilter: Filter {

    var filter: Expression<Bool?> {
        switch self {
        case .conformsTo(let type):
            var expression = Expression<Bool?>(value: true)
            if let type = type.type {
                expression = expression && Store.Schema.type == type
            }
            if let subtytpe = type.subtytpe, subtytpe != "*" {
                expression = expression && Store.Schema.subtype == subtytpe
            }
            return expression
        }
    }

}
