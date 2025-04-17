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

import Combine
import SwiftUI

class SidebarItem: Hashable, Identifiable, Equatable {

    static func == (lhs: SidebarItem, rhs: SidebarItem) -> Bool {
        return lhs.kind == rhs.kind && lhs.children == rhs.children
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
        hasher.combine(children)
    }

    enum Kind: Hashable {
        case owner(Details.Identifier)
        case folder(Details.Identifier)
        case tag(String)
    }

    public var id: Kind {
        return kind
    }

    let kind: Kind
    var children: [SidebarItem]?

    init(kind: Kind, children: [SidebarItem]?) {
        self.kind = kind
        self.children = children
    }

    func setting(children: [SidebarItem]? = nil) -> SidebarItem {
        return SidebarItem(kind: self.kind, children: children)
    }

}

extension SidebarItem.Kind {

    var displayName: String {
        switch self {
        case .owner(let id):
            return id.url.displayName
        case .folder(let id):
            return id.url.displayName
        case .tag(let name):
            return name
        }
    }

    var systemImage: String {
        switch self {
        case .owner:
            return "archivebox"
        case .folder:
            return "folder"
        case .tag:
            return "tag"
        }
    }

}

extension Array where Element == SidebarItem {

    func sorted() -> [SidebarItem] {
        return sorted { lhs, rhs in
            return lhs.kind.displayName.localizedStandardCompare(rhs.kind.displayName) == .orderedAscending
        }
    }

}

extension Array where Element == SidebarItem.Kind {

    func sorted() -> [SidebarItem.Kind] {
        return sorted { lhs, rhs in
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

}
