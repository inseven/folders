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

import Foundation

extension FileManager {

    func files(directoryURL: URL) throws -> [URL]  {
        let date = Date()
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .contentTypeKey])
        let directoryEnumerator = enumerator(at: directoryURL,
                                             includingPropertiesForKeys: Array(resourceKeys),
                                             options: [.skipsHiddenFiles, .producesRelativePathURLs])!

        var files: [URL] = []
        for case let fileURL as URL in directoryEnumerator {
            // Get the file metadata.
            let isDirectory = try fileURL
                .resourceValues(forKeys: [.isDirectoryKey])
                .isDirectory!

            // Ignore directories.
            if isDirectory {
                continue
            }

            // Only show images; we'll want to make this test dynamic in the future.
            guard let contentType = try fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType,
                  (contentType.conforms(to: .image)
                   || contentType.conforms(to: .video)
                   || contentType.conforms(to: .movie)
                   || fileURL.pathExtension == "cbz"
                   || contentType.conforms(to: .pdf))
            else {
                continue
            }

            files.append(fileURL)
        }

        let duration = date.distance(to: Date())
        print("Listing for '\(directoryURL.displayName)' took \(duration.formatted()) seconds (\(files.count) files).")

        return files
    }

}
