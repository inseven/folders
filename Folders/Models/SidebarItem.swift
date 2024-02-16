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

import Combine
import SwiftUI

class SidebarItem: Hashable, Identifiable, Equatable {

    static func == (lhs: SidebarItem, rhs: SidebarItem) -> Bool {
        return lhs.kind == rhs.kind && lhs.folderURL == rhs.folderURL && lhs.children == rhs.children
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
        hasher.combine(folderURL)
        hasher.combine(children)
    }

    enum Kind {
        case owner
        case folder
    }

    // TODO: This will crash if the user adds overlapping folders and needs fixing by adding the concept of a top-level owner.
    var id: URL {
        return folderURL
    }

    var displayName: String {
        return folderURL.displayName
    }

    let kind: Kind
    let folderURL: URL
    var children: [SidebarItem]?

    init(kind: Kind, folderURL: URL, children: [SidebarItem]?) {
        precondition(folderURL.hasDirectoryPath)
        self.kind = kind
        self.folderURL = folderURL
        self.children = children
    }

}

extension SidebarItem {

    var systemImage: String {
        switch kind {
        case .owner:
            return "archivebox"
        case .folder:
            return "folder"
        }
    }

}
