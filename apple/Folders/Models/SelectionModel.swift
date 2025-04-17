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

class SelectionModel: ObservableObject {

    @Published var settings: [URL: FolderSettings] = [:]
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
        self.settingsURLs = Array(selection)
            .sorted()
            .compactMap { sidebarItem in
                switch sidebarItem {
                case .owner(let identifier), .folder(let identifier):
                    return identifier.url.appendingPathComponent("folders-settings.yaml")
                case .tag:
                    return nil
                }
            }
    }

    func start() {

        // Observe the changes for all relevant settings files.
        Publishers.MergeMany(settingsURLs.map { settingsURL in
            return store
                .publisher(filter: .url(settingsURL))
        })
        .receive(on: DispatchQueue.main)
        .sink { operation in
            switch operation {
            case .add(let files), .update(let files):
                let file = files.first!
                do {
                    self.settings[file.url] = try FolderSettings(contentsOf: file.url)
                } catch {
                    self.error = error
                }
            case .remove(let identifiers):
                let identifier = identifiers.first!
                self.settings.removeValue(forKey: identifier.url)
            case .addTags:
                break
            case .removeTags:
                break
            }
        }
        .store(in: &cancellables)

        // Load the contents of the settings file.
        // TODO: Update the store publisher to include the initial state (just like `StoreFilesView`).
        do {
            // TODO: Don't fail to load all files if just one is malformed.
            for settingsURL in settingsURLs {
                guard FileManager.default.fileExists(atPath: settingsURL.path) else {
                    continue
                }
                self.settings[settingsURL] = try FolderSettings(contentsOf: settingsURL)
            }
        } catch {
            self.error = error
        }
    }

    func stop() {
        cancellables.removeAll()
    }

}
