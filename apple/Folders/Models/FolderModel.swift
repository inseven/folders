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

class FolderModel: ObservableObject {

    @Published var settings: FolderSettings?
    @Published var error: Error?

    let store: Store
    let identifiers: [Details.Identifier]
    var cancellables = Set<AnyCancellable>()

    var title: String {
        return identifiers.map { $0.url.displayName }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .joined(separator: ", ")
    }

    // TODO: Rename to selection
    init(store: Store, sidebarItems: Set<SidebarItem.ID>) {
        self.store = store

        // TODO: This is a hack.
        // This is responsible for selecting the identifiers which are then used to look up display information about
        // the currently selected folder. It can only do sensible things when there's a single 'pure' folder selected.
        self.identifiers = sidebarItems.compactMap { sidebarItem in
            switch sidebarItem {
            case .owner(let identifier):
                return identifier
            case .folder(let identifier):
                return identifier
            case .tag:
                return nil
            }
        }

    }

    func start() {

        // Only load folder settings if a single folder is selected.
        guard identifiers.count == 1,
              let settingsURL = identifiers.first?.url.appendingPathComponent("folders-settings.yaml") else {
            return
        }

        // TODO: Convenience contructor for running filters.
        store
            .publisher()  // TODO: Rename to changes? Could/should this take a filter? File publisher vs tag publisher?
            .compactMap { (operation: StoreOperation) -> StoreOperation? in
                switch operation {
                case .add(let files):
                    let files = files.filter { $0.url == settingsURL }
                    guard files.count > 0 else {
                        return nil
                    }
                    return StoreOperation.add(files)
                case .remove(let identifiers):
                    let identifiers = identifiers.filter { $0.url == settingsURL }
                    guard identifiers.count > 0 else {
                        return nil
                    }
                    return StoreOperation.remove(identifiers)
                case .addTags:
                    return nil
                case .removeTags:
                    return nil
                }
            }
            .receive(on: DispatchQueue.main)
            .sink { operation in
                switch operation {
                case .add:
                    do {
                        self.settings = try FolderSettings(contentsOf: settingsURL)
                    } catch {
                        self.error = error
                    }
                case .remove:
                    self.settings = nil
                case .addTags:
                    break
                case .removeTags:
                    break
                }
            }
            .store(in: &cancellables)

        // Load the contents of the settings file.
        // TODO: It would be great if we didn't have to do this initial load.
        // TODO: Perhaps we should show the error for loading files inline rather than modally to make it easier to recover from.
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return
        }
        do {
            self.settings = try FolderSettings(contentsOf: settingsURL)
        } catch {
            self.error = error
        }
    }

    func stop() {
        cancellables.removeAll()
    }

}
