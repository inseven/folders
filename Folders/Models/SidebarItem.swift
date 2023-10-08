// MIT License
//
// Copyright (c) 2023 Jason Barrie Morley
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

struct SidebarItem: Hashable, Identifiable {

    let id = UUID()

    let folderURL: URL
    let children: [SidebarItem]?

    init(folderURL: URL, children: [SidebarItem]?) {
        self.folderURL = folderURL
        self.children = children
    }

    init(folderURL: URL) throws {
        let fileManager = FileManager.default
        let children = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.nameKey, .isDirectoryKey], options: .skipsHiddenFiles)
            .compactMap { fileURL -> URL? in
                let isDirectory = try fileURL
                    .resourceValues(forKeys: [.isDirectoryKey])
                    .isDirectory!
                guard isDirectory else {
                    return nil
                }
                return fileURL
            }
            .map { folderURL in
                return try SidebarItem(folderURL: folderURL)
            }
            .sorted { $0.folderURL.displayName.localizedStandardCompare($1.folderURL.displayName) == .orderedAscending }
        self.folderURL = folderURL
        self.children = children.isEmpty ? nil : children
    }

}
