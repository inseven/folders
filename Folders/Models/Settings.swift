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

import SwiftUI

class Settings: ObservableObject {

    let userDefaults = UserDefaults.standard

    @Published var rootURLs: [URL] {
        didSet {
            do {
                let bookmarks = try rootURLs.map { url in
                    return try url.bookmarkData(options: .withSecurityScope,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil)
                }
                userDefaults.setValue(bookmarks, forKey: "SiteBookmarks")
            } catch {
                print("Failed to save bookmark data with error \(error).")
            }
        }
    }

    init() {
        rootURLs = []
        if let bookmarks = userDefaults.array(forKey: "SiteBookmarks") as? [Data] {
            do {
                let urls = try bookmarks.map { bookmarkData in
                    var isStale = true
                    let url = try URL(resolvingBookmarkData: bookmarkData,
                                   options: .withSecurityScope,
                                   bookmarkDataIsStale: &isStale)
                    guard url.startAccessingSecurityScopedResource() else {
                        throw FoldersError.general("Failed to load security scoped resource '\(url)'.")
                    }
                    return url
                }
                rootURLs = urls
            } catch {
                print("Failed to load sites with error \(error).")
                print(error)
            }
        }
    }

}
