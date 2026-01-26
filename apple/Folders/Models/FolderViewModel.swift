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

class FolderViewModel: ObservableObject {

    @Published var settings: [URL: FolderSettings] = [:]
    @Published var selection: Set<Details.Identifier> = []
    @Published var error: Error?  // TODO: List of errors?

    let store: Store
    let identifiers: [SidebarItem.Kind]
    let settingsURLs: [URL]
    var cancellables = Set<AnyCancellable>()

    var title: String {
        return identifiers.map { $0.displayName }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .joined(separator: ", ")
    }

    init(store: Store, selection: Set<SidebarItem.ID>) {
        self.store = store
        self.identifiers = Array(selection)

        // Get the relevant settings URLs for the current selection.
        self.settingsURLs = self.identifiers
            .sorted()
            .compactMap { sidebarItem in
                switch sidebarItem {
                case .owner(let identifier), .folder(let identifier):
                    return identifier.url.appendingPathComponent("folders-settings.yaml")
                case .tag, .images, .videos, .documents:
                    return nil
                }
            }
    }

    func start() {
        let filter = AnyFilter(oring: settingsURLs.map { URLFilter.url($0) })
        store.publisher(filter: filter)
            .receive(on: DispatchQueue.global(qos: .utility))
            .map { files -> Result<[URL: FolderSettings], Error> in
                do {
                    let settings = try files.map { file in
                        return (file.url, try FolderSettings(contentsOf: file.url))
                    }.reduce(into: [URL:FolderSettings]()) { partialResult, folderSettings in
                        partialResult[folderSettings.0] = folderSettings.1
                    }
                    return .success(settings)
                } catch {
                    return .failure(error)
                }
            }
            .receive(on: DispatchQueue.main)
            .sink { result in
                switch result {
                case .success(let settings):
                    self.settings = settings
                case .failure(let error):
                    self.error = error
                }
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
    }

}
