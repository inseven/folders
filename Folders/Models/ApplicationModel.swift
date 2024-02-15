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

class ApplicationModel: NSObject, ObservableObject {

    private let settings = Settings()

    let store: Store
    var scanners: [DirectoryScanner] = []
    var directoriesView: StoreView

    @Published var sidebarItems: [SidebarItem]
    @Published var lookup: [URL: SidebarItem] = [:]
    @Published var dynamicSidebarItems: [SidebarItem] = []

    var cancellables = Set<AnyCancellable>()

    override init() {

        // Load the scanners.
        scanners = settings.rootURLs.map { url in
            DirectoryScanner(url: url)
        }

        // Load the sidebar items.
        sidebarItems = settings.rootURLs.map { folderURL in
            return SidebarItem(kind: .owner, folderURL: folderURL, children: nil)
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
        self.store = try! Store(databaseURL: storeURL)

        self.directoriesView = StoreView(store: store, filter: .conforms(to: .directory) || .conforms(to: .folder))

        super.init()

        self.directoriesView.delegate = self

        // Start the scanners.
        for scanner in scanners {
            start(scanner: scanner)
        }

    }

    func start(scanner: DirectoryScanner) {

        // TODO: This should be extracted out from here.
        scanner.start { [store] details in
            // TODO: Maybe allow this to rethrow and catch it at the top level to make the code cleaner?
            do {
                let insertStart = Date()
                for file in details {
                    try store.insertBlocking(details: file)
                }
                let insertDuration = insertStart.distance(to: Date())
                print("Insert took \(insertDuration.formatted()) seconds.")
            } catch {
                print("Failed to insert updates with error \(error).")
            }
        } onFileCreation: { [store] details in
            do {
                try store.insertBlocking(details: details)
            } catch {
                print("Failed to perform creation update with error \(error).")
            }
        } onFileDeletion: { [store] url in
            do {
                try store.removeBlocking(url: url)
            } catch {
                print("Failed to perform deletion update with error \(error).")
            }
        }

        $sidebarItems
            .combineLatest($lookup)
            .receive(on: DispatchQueue.main)
            .map { sidebarItems, lookup in
                return sidebarItems.map { sidebarItem in
                    let children = lookup[sidebarItem.folderURL]?.children ?? nil
                    return SidebarItem(kind: sidebarItem.kind, folderURL: sidebarItem.folderURL, children: children)
                }.sorted { lhs, rhs in
                    return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }
                // TODO: Consider sorting here.
            }
            .assign(to: \.dynamicSidebarItems, on: self)
            .store(in: &cancellables)

    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        $sidebarItems
            .map { $0.map { $0.folderURL } }
            .receive(on: DispatchQueue.main)
            .assign(to: \.rootURLs, on: settings)
            .store(in: &cancellables)
        directoriesView.start()
    }

    func stop() {
        cancellables.removeAll()
        directoriesView.stop()
    }

    func add() -> SidebarItem? {
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
        if let sidebarItem = sidebarItems.first(where: { $0.folderURL == url }) {
            return sidebarItem
        }

        // Create the new sidebar item.
        let sidebarItem = SidebarItem(kind: .owner, folderURL: url, children: nil)
        sidebarItems.append(sidebarItem)

        // Create a new scanner.
        let scanner = DirectoryScanner(url: url)
        start(scanner: scanner)

        return sidebarItem
    }

    func remove(_ url: URL) {

        // Remove and stop the directory scanner.
        if let scannerIndex = scanners.firstIndex(where: { $0.url == url }) {
            let scanner = scanners.remove(at: scannerIndex)
            scanner.stop()
        }

        // Remove the entires from the database.
        do {
            try store.removeBlocking(owner: url)
        } catch {
            // TODO: Better error handling.
            print("Failed to remove files with error \(error).")
        }

        sidebarItems.removeAll { $0.folderURL == url }
    }

}

extension ApplicationModel: StoreViewDelegate {

    // TODO: Static?
    func sidebarItems(for files: [Details]) -> [URL: SidebarItem] {
        var owners = Set<URL>()

        var items = [URL: SidebarItem]()

        // TODO: This is copying the structure. It would be better not to do that.
        for details in files {

            owners.insert(details.owner)

            // Get or create the current node and parent node.
            let item = items[details.url] ?? SidebarItem(kind: .folder, folderURL: details.url, children: nil)
            var parent = items[details.parentURL] ?? SidebarItem(kind: .folder, folderURL: details.parentURL, children: nil)

            // Update the parent node.
            parent = SidebarItem(kind: parent.kind, folderURL: parent.folderURL, children: (parent.children ?? []) + [item])

            // Set the nodes.
            items[item.folderURL] = item
            items[parent.folderURL] = parent
        }

        return items
    }

    func directoryWatcherDidUpdate(_ directoryWatcher: StoreView) {
        self.lookup = sidebarItems(for: directoryWatcher.files)
    }

    func debugPrint(sidebarItem: SidebarItem, indent: Int = 0) {
        let padding = String(repeating: " ", count: indent)
        print("\(padding)\(sidebarItem.folderURL.path) (\(sidebarItem.children?.count ?? 0))")
        for child in sidebarItem.children ?? [] {
            debugPrint(sidebarItem: child, indent: indent + 2)
        }
    }

    func directoryWatcher(_ directoryWatcher: StoreView, didInsertURL url: URL, atIndex: Int) {
        self.lookup = sidebarItems(for: directoryWatcher.files)
    }

    func directoryWatcher(_ directoryWatcher: StoreView, didRemoveURL url: URL, atIndex: Int) {
        self.lookup = sidebarItems(for: directoryWatcher.files)
    }

}
