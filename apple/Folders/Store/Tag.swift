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

import SQLite

struct Tag: Hashable {

    enum Source: Int {
        case filename = 0
        case finder = 1
    }

    init(source: Source, name: String, colorIndex: Int = 0) {
        self.source = source
        self.name = name
        self.colorIndex = colorIndex
    }

    let source: Source
    let name: String
    let colorIndex: Int

}

extension Tag.Source: Value {

    typealias Datatype = Int64
    static var declaredDatatype: String = "INTEGER"

    static func fromDatatypeValue(_ datatypeValue: Int64) throws -> Tag.Source {
        guard let value = Self(rawValue: Int(datatypeValue)) else {
            throw FoldersError.unknownTagSource(datatypeValue)
        }
        return value
    }

    var datatypeValue: Int64 {
        return Int64(self.rawValue)
    }

}
