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

import Sparkle

class ApplicationModel: NSObject, ObservableObject {

    private let settings = Settings()

    let store: Store
    var updaters: [StoreUpdater] = []
    var directoriesView: StoreView
    var tagsView: TagsView

    @Published var locations: [Details.Identifier]
    @Published var lookup: [Details.Identifier: SidebarItem] = [:]
    @Published var dynamicSidebarItems: [SidebarItem] = []
    @Published var tags: [String] = []

    var cancellables = Set<AnyCancellable>()
    let updaterController = SPUStandardUpdaterController(startingUpdater: false,
                                                         updaterDelegate: nil,
                                                         userDriverDelegate: nil)

    override init() {

        // Load the sidebar items.
        locations = settings
            .rootURLs
            .map { folderURL in
                return Details.Identifier(ownerURL: folderURL, url: folderURL)
            }
            .sorted { lhs, rhs in
                lhs.url.displayName.localizedCaseInsensitiveCompare(rhs.url.displayName) == .orderedAscending
            }

        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory,
                                                             in: .userDomainMask).first!

        // TODO: Remove the initialization into a separate state so we can capture errors and recover.

        // Clean up older versions major versions (these contain breaking changes).
        let fileManager = FileManager.default
        for i in 0 ..< Store.majorVersion {
            let storeURL = applicationSupportURL.appendingPathComponent("store_\(i).sqlite")
            if fileManager.fileExists(atPath: storeURL.path) {
                try! fileManager.removeItem(at: storeURL)
            }
        }

        // Open the database, creating a new one if necessary.
        let storeURL = applicationSupportURL.appendingPathComponent("store_\(Store.majorVersion).sqlite")
        print("Opening database at '\(storeURL.path)'...")
        let store = try! Store(databaseURL: storeURL)
        self.store = store

        // Load the updaters.
        updaters = settings.rootURLs.map { url in
            StoreUpdater(store: store, url: url)
        }

        self.directoriesView = StoreView(store: store, filter: .conforms(to: .directory) || .conforms(to: .folder))
        self.tagsView = TagsView(store: store)

        super.init()

        self.directoriesView.delegate = self
        self.tagsView.delegate = self

        // Start the updaters.
        for updater in updaters {
            updater.start()
        }

        updaterController.startUpdater()

    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))

        $locations
            .combineLatest($lookup)
            .receive(on: DispatchQueue.main)
            .map { sidebarItems, lookup in
                return sidebarItems.map { sidebarItem in
                    let children = lookup[sidebarItem]?.children ?? nil
                    return SidebarItem(kind: .owner(sidebarItem), children: children)
                }.sorted()
            }
            .assign(to: \.dynamicSidebarItems, on: self)
            .store(in: &cancellables)

        $locations
            .map { $0.map { $0.url } }
            .receive(on: DispatchQueue.main)
            .assign(to: \.rootURLs, on: settings)
            .store(in: &cancellables)

        directoriesView.start()
        tagsView.start()
    }

    func stop() {
        cancellables.removeAll()
        directoriesView.stop()
        tagsView.stop()
    }

    func add() -> SidebarItem.ID? {
        // TODO: Allow multiple selection.
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        guard openPanel.runModal() ==  NSApplication.ModalResponse.OK,
              let url = openPanel.url else {
            return nil
        }

        // Don't add existing directories.
        if let sidebarItem = locations.first(where: { $0.url == url }) {
            return .owner(sidebarItem)
        }

        // Create the new sidebar item.
        let sidebarItem = Details.Identifier(ownerURL: url, url: url)
        locations.append(sidebarItem)

        // Create a new updater.
        let updater = StoreUpdater(store: store, url: url)
        updater.start()
        updaters.append(updater)

        return .owner(sidebarItem)
    }

    func remove(_ url: URL) {

        // Remove and stop the updater.
        if let index = updaters.firstIndex(where: { $0.url == url }) {
            let updater = updaters.remove(at: index)
            updater.stop()
        }

        // Remove the sidebar entry.
        locations.removeAll { $0.url == url }

        // Remove the entires from the database.
        DispatchQueue.global(qos: .background).async {
            do {
                try self.store.remove(owner: url)
            } catch {
                // TODO: Better error handling.
                print("Failed to remove files with error \(error).")
            }
        }
    }

}

extension ApplicationModel: StoreViewDelegate {

    // TODO: Static?
    func sidebarItems(for files: [Details]) -> [Details.Identifier: SidebarItem] {

        // TODO: This should take the identifier!
        var items = [Details.Identifier: SidebarItem]()

        // TODO: This is copying the structure. It would be better not to do that.
        for details in files {

            let identifier = details.identifier
            let parentIdentiifer = Details.Identifier(ownerURL: details.ownerURL, url: details.parentURL)

            // Get or create the current node and parent node.
            let item = items[identifier] ?? SidebarItem(kind: .folder(details.identifier),
                                                        children: nil)
            let parent = items[parentIdentiifer] ?? SidebarItem(kind: .folder(details.parentIdentifier),
                                                                children: nil)

            // Update the parent's children.
            if parent.children != nil {
                parent.children!.append(item)
            } else {
                parent.children = [item]
            }

            // Set the nodes.
            items[identifier] = item
            items[parentIdentiifer] = parent
        }

        return items
    }

    func storeView(_ storeView: StoreView, didUpdateFiles files: [Details]) {
        assert(Set(files.map({ $0.url })).count == files.count)
        self.lookup = sidebarItems(for: files)
    }

    func storeView(_ storeView: StoreView, didInsertFile file: Details, atIndex: Int, files: [Details]) {
        assert(Set(files.map({ $0.url })).count == files.count)
        self.lookup = sidebarItems(for: files)
    }

    func storeView(_ storeView: StoreView, didUpdateFile file: Details, atIndex: Int, files: [Details]) {
        assert(Set(files.map({ $0.url })).count == files.count)
        self.lookup = sidebarItems(for: files)
    }

    func storeView(_ storeView: StoreView, didRemoveFileWithIdentifier identifier: Details.Identifier, atIndex: Int, files: [Details]) {
        assert(Set(files.map({ $0.url })).count == files.count)
        self.lookup = sidebarItems(for: files)
    }

}

extension ApplicationModel: TagsViewDelegate {

    func tagsView(_ tagsView: TagsView, didUpdateTags tags: [String]) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.tags = tags
    }
    
    func tagsView(_ tagsView: TagsView, didInsertTag tag: String, atIndex index: Int, tags: [String]) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.tags = tags
    }
    
    func tagsView(_ tagsView: TagsView, didRemoveTag tag: String, atIndex index: Int, tags: [String]) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.tags = tags
    }

}
