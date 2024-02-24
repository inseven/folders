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
    @Published var lookup: [Details.Identifier: SidebarItem] = [:]
    @Published var dynamicSidebarItems: [SidebarItem] = []

    var cancellables = Set<AnyCancellable>()

    override init() {

        // Load the scanners.
        scanners = settings.rootURLs.map { url in
            DirectoryScanner(url: url)
        }

        // Load the sidebar items.
        sidebarItems = settings
            .rootURLs
            .map { folderURL in
                return SidebarItem(kind: .owner, ownerURL: folderURL, url: folderURL, children: nil)
            }
            .sorted()

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
            // TODO: Make this async so we can use async APIs exclusively in the Store.

            do {
                let insertStart = Date()

                // Take an in-memory snapshot of everything within this owner and use it to track deletions.
                // We can do this safely (and outside of a transaction) as we can guarantee we're the only observer
                // modifying the files within this owner.
                var existingFiles = try store.filesBlocking(filter: .owner(scanner.url), sort: .displayNameAscending)
                    .reduce(into: Set<URL>()) { partialResult, details in
                        partialResult.insert(details.url)
                    }

                // Add just the new files.
                for file in details {
                    print(file.url)
                    if existingFiles.contains(file.url) {
                        existingFiles.remove(file.url)
                    } else {
                        try store.insertBlocking(details: file)
                    }
                }

                // Remove remaining files.
                print("Cleaning up \(existingFiles.count) files...")
                try store.removeBlocking(owner: scanner.url, urls: existingFiles)

                let insertDuration = insertStart.distance(to: Date())
                print("Update took \(insertDuration.formatted()) seconds.")

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
                try store.removeBlocking(owner: scanner.url, urls: [url])
            } catch {
                print("Failed to perform deletion update with error \(error).")
            }
        }

        $sidebarItems
            .combineLatest($lookup)
            .receive(on: DispatchQueue.main)
            .map { sidebarItems, lookup in
                return sidebarItems.map { sidebarItem in
                    let children = lookup[sidebarItem.id]?.children ?? nil
                    return sidebarItem.setting(children: children)
                }.sorted()
            }
            .assign(to: \.dynamicSidebarItems, on: self)
            .store(in: &cancellables)

    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        $sidebarItems
            .map { $0.map { $0.url } }
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
        if let sidebarItem = sidebarItems.first(where: { $0.url == url }) {
            return sidebarItem
        }

        // Create the new sidebar item.
        let sidebarItem = SidebarItem(kind: .owner, ownerURL: url, url: url, children: nil)
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

        sidebarItems.removeAll { $0.url == url }
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
            let item = items[identifier] ?? SidebarItem(kind: .folder, ownerURL: details.ownerURL, url: details.url, children: nil)
            let parent = items[parentIdentiifer] ?? SidebarItem(kind: .folder, ownerURL: details.ownerURL, url: details.parentURL, children: nil)

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

    func storeViewDidUpdate(_ storeView: StoreView) {
        self.lookup = sidebarItems(for: storeView.files)
    }

    func debugPrint(sidebarItem: SidebarItem, indent: Int = 0) {
        let padding = String(repeating: " ", count: indent)
        print("> \(padding)\(sidebarItem.url.absoluteString) (\(sidebarItem.children?.count ?? 0))")
        for child in sidebarItem.children ?? [] {
            debugPrint(sidebarItem: child, indent: indent + 2)
        }
    }

    func storeView(_ storeView: StoreView, didInsertURL url: URL, atIndex: Int) {
        self.lookup = sidebarItems(for: storeView.files)
    }

    func storeView(_ storeView: StoreView, didRemoveURL url: URL, atIndex: Int) {
        self.lookup = sidebarItems(for: storeView.files)
    }

}
