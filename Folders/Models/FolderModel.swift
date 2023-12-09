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
import UniformTypeIdentifiers

import OrderedCollections

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
                  contentType.conforms(to: .image) || contentType.conforms(to: .video) || contentType.conforms(to: .movie) || fileURL.pathExtension == "cbz" || contentType.conforms(to: .pdf)
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

class FolderModel: ObservableObject {

    enum State {
        case loading
        case ready  // TODO: Consider adding the files here
    }

    let directoryURL: URL

    @Published var state: State = .loading
    @Published var files = OrderedSet<URL>()
    @Published var error: Error? = nil
    @Published var size: CGFloat = 400
    @Published var selection = Set<URL>()
    @Published var scrollPosition: URL? = nil
    @Published var preview: URL? = nil

    var cancellables = Set<AnyCancellable>()

    var title: String {
        return FileManager.default.displayName(atPath: directoryURL.path)
    }

    init(directoryURL: URL) {
        precondition(directoryURL.hasDirectoryPath)
        self.directoryURL = directoryURL
    }

    func start() {

        // Update the selection whenever the preview changes.
        $preview
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selection in
                guard let self else { return }
                self.selection = Set([selection])
                self.scrollPosition = selection
            }
            .store(in: &cancellables)

        // Load the files.
        Task {
            do {
                let orderedFiles = try FileManager.default.files(directoryURL: directoryURL)

                await MainActor.run {
                    self.files = OrderedSet(orderedFiles)
                    self.state = .ready
                }

            } catch {
                await MainActor.run {
                    self.error = error
                }
            }
        }
    }

    func stop() {
        files.removeAll()
    }

    func selectNext() {
        Task { @MainActor in
            guard let currentItem = selection.first,
                  let currentIndex = files.firstIndex(of: currentItem)
            else {
                if let first = files.first {
                    selection = Set([first])
                }
                return
            }
            let nextIndex = currentIndex + 1
            guard nextIndex < files.count else {
                return
            }
            let nextItem = files[nextIndex]
            self.selection = Set([nextItem])
            self.scrollPosition = nextItem
        }
    }

    func selectPrevious() {
        Task { @MainActor in
            guard let currentItem = selection.first,
                  let currentIndex = files.firstIndex(of: currentItem)
            else {
                if let last = files.last {
                    selection = Set([last])
                }
                return
            }
            let previousIndex = currentIndex - 1
            guard previousIndex >= 0 else {
                return
            }
            let previousItem = files[previousIndex]
            self.selection = Set([previousItem])
            self.scrollPosition = previousItem
        }
    }

    func showPreview() {
        Task { @MainActor in
            guard let currentItem = selection.first else {
                return
            }
            preview = currentItem
        }
    }

    func open() {
        for fileURL in selection {
            NSWorkspace.shared.open(fileURL)
        }
    }

    func reveal(url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }

}
