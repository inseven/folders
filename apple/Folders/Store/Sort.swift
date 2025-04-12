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

protocol Sort {

    func compare(_ lhs: Details, _ rhs: Details) -> Bool
    var sql: String { get }
}

struct DisplayNameAscending: Sort {

    func compare(_ lhs: Details, _ rhs: Details) -> Bool {
        return lhs.url.displayName.localizedStandardCompare(rhs.url.displayName) == .orderedAscending
    }

    var sql: String {
        return "name ASC"
    }

}

extension Sort where Self == DisplayNameAscending {

    static var displayNameAscending: DisplayNameAscending {
        return DisplayNameAscending()
    }

}

struct DisplayNameDescending: Sort {

    func compare(_ lhs: Details, _ rhs: Details) -> Bool {
        return lhs.url.displayName.localizedStandardCompare(rhs.url.displayName) == .orderedDescending
    }

    var sql: String {
        return "name DESC"
    }

}

extension Sort where Self == DisplayNameDescending {

    static var displayNameDescending: DisplayNameDescending {
        return DisplayNameDescending()
    }

}
