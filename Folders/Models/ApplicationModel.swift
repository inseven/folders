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

import FSEventsWrapper

class DirectoryScanner {

    let url: URL
    let workQueue = DispatchQueue(label: "workQueue")
    var stream: FSEventStream? = nil

    init(url: URL) {
        self.url = url
    }

    func start(callback: @escaping ([URL]) -> Void,
               onFileCreation: @escaping (URL) -> Void,
               onFileDeletion: @escaping (URL) -> Void) {

        // TODO: Consider creating this in the constructor.
        stream = FSEventStream(path: url.path,
                               fsEventStreamFlags: FSEventStreamEventFlags(kFSEventStreamCreateFlagFileEvents),
                               queue: workQueue) { stream, event in

            let fileManager = FileManager.default

            switch event {
            case .itemClonedAtPath:
                return
            case .itemCreated(path: let path, itemType: let itemType, eventId: _, fromUs: _):
                guard itemType != .dir else {
                    return
                }
                let url = URL(filePath: path)
                print("File created '\(url)'")
                onFileCreation(url)
            case .itemRenamed(path: let path, itemType: let itemType, eventId: _, fromUs: _):
                guard itemType != .dir else {
                    return
                }
                let url = URL(filePath: path)
                // Helpfully, file renames can be additions or removals, so we check to see if the file exists at the
                // new location to determine which.
                if fileManager.fileExists(atPath: url.path) {
                    print("File added by rename '\(url)'")
                    onFileCreation(url)
                } else {
                    print("File removed by rename '\(url)'")
                    onFileDeletion(url)
                }
            default:
                print("Unhandled file event \(event).")
            }
        }

        guard let stream else {
            preconditionFailure("Failed to create event stream!")
        }

        workQueue.async { [url] in

            // Start the event stream watching.
            // We do this from here to ensure we don't miss any events, and that all individual change callbacks are
            // enqueued after our initial scan.
            stream.startWatching()

            // TODO: Actually perform the iteration inline so we can pace ourselves.
            // TODO: Handle this error.
            let urls = try! FileManager.default.files(directoryURL: url)
            callback(urls)
        }

        // TODO: Start an observer so we get updates!
    }

    func stop() {
        stream?.stopWatching()
        stream = nil
    }

}




class ApplicationModel: ObservableObject {

    private let settings = Settings()

    let store: Store
    var scanners: [DirectoryScanner] = []

    @Published var sidebarItems: [SidebarItem]

    var cancellables = Set<AnyCancellable>()

    init() {
        do {

            // Load the scanners.
            scanners = settings.rootURLs.map { url in
                DirectoryScanner(url: url)
            }

            // Load the sidebar items.
            sidebarItems = try settings.rootURLs.map { folderURL in
                return try SidebarItem(folderURL: folderURL)
            }

        } catch {
            print("Failed to load sidebar items with error \(error).")
            sidebarItems = []
        }

        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeURL = applicationSupportURL.appendingPathComponent("store.sqlite")
        self.store = try! Store(databaseURL: storeURL)

        // Start the scanners.
        for scanner in scanners {
            start(scanner: scanner)
        }

    }

    func start(scanner: DirectoryScanner) {
        scanner.start { [store] urls in
            // TODO: Maybe allow this to rethrow and catch it at the top level to make the code cleaner?
            do {
                let insertStart = Date()
                for url in urls {
                    try store.insertBlocking(url: url)
                }
                let insertDuration = insertStart.distance(to: Date())
                print("Insert took \(insertDuration.formatted()) seconds.")
            } catch {
                print("FAILED TO INSERT UPDATES WITH ERROR \(error).")
            }
        } onFileCreation: { [store] url in
            do {
                try store.insertBlocking(url: url)
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
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        $sidebarItems
            .map { $0.map { $0.folderURL } }
            .receive(on: DispatchQueue.main)
            .assign(to: \.rootURLs, on: settings)
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
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
        let sidebarItem = try! SidebarItem(folderURL: url)
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

        // TODO: Delete the entries from the database.

        sidebarItems.removeAll { $0.folderURL == url }
    }

}
