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

import FSEventsWrapper

// TODO: Start/stop thread-safety
class DirectoryScanner {

    let url: URL
    let workQueue = DispatchQueue(label: "workQueue")
    var stream: FSEventStream? = nil
    var identifiers: Set<Details.Identifier> = []  // Work Queue

    init(url: URL) {
        self.url = url
    }

    func start(load: @escaping () -> Set<Details>,
               onFileCreation: @escaping (any Collection<Details>) -> Void,
               onFileDeletion: @escaping (any Collection<Details.Identifier>) -> Void) {

        let ownerURL = url

        // TODO: Consider creating this in the constructor.
        stream = FSEventStream(path: url.path,
                               fsEventStreamFlags: FSEventStreamEventFlags(kFSEventStreamCreateFlagFileEvents),
                               queue: workQueue) { stream, event in

            let fileManager = FileManager.default

            switch event {
            case .itemClonedAtPath:
                return
            case .itemCreated(path: let path, itemType: let itemType, eventId: _, fromUs: _):

                print("File created at path '\(path)'")
                do {
                    let url = URL(filePath: path, directoryHint: itemType == .dir ? .isDirectory : .notDirectory)
                    let details = try FileManager.default.details(for: url, owner: ownerURL)
                    onFileCreation([details])
                    self.identifiers.insert(details.identifier)
                } catch {
                    print("Failed to handle file creation with error \(error).")
                }

            case .itemRenamed(path: let path, itemType: let itemType, eventId: _, fromUs: _):

                // Helpfully, file renames can be additions or removals, so we check to see if the file exists at the
                // new location to determine which.
                do {
                    let url = URL(filePath: path, directoryHint: itemType == .dir ? .isDirectory : .notDirectory)
                    if fileManager.fileExists(atPath: url.path) {

                        let details = try FileManager.default.details(for: url, owner: ownerURL)

                        // If a file exists at the new path and also exists in our runtime cache of files then we infer
                        // that this rename actuall represents a content modification operation; our file has been
                        // atomically replaced by a new file containing new content.
                        if self.identifiers.contains(details.identifier) {
                            print("File updated by rename '\(url)'")
                            onFileDeletion([details.identifier])
                            // TODO: We should ensure we delete all our children if we're a directory.
                        } else {
                            print("File added by rename '\(url)'")
                        }

                        onFileCreation([details])
                        self.identifiers.insert(details.identifier)

                        // We don't get notified about files contained within a directory, so we walk those explicitly.
                        if itemType == .dir {
                            let files = try fileManager.files(directoryURL: url)
                                .map { details in
                                    return details.setting(ownerURL: ownerURL)
                                }
                            onFileCreation(files)
                            self.identifiers.formUnion(files.map({ $0.identifier }))
                        }

                    } else {
                        print("File removed by rename '\(url)'")

                        // If it's a directory, then we need to work out what files are being removed.
                        let identifier = Details.Identifier(ownerURL: ownerURL, url: url)
                        if itemType == .dir {
                            let identifiers = self.identifiers.filter { $0.url.path.hasPrefix(url.path + "/") } + [identifier]
                            onFileDeletion(Array(identifiers))
                            self.identifiers.subtract(identifiers)
                        } else {
                            onFileDeletion([identifier])
                            self.identifiers.remove(identifier)
                        }
                    }
                } catch {
                    print("Failed to handle file deletion with error \(error).")
                }

            case .itemRemoved(path: let path, itemType: let itemType, eventId: _, fromUs: _):

                let url = URL(filePath: path, directoryHint: itemType == .dir ? .isDirectory : .notDirectory)
                print("File removed '\(url)'")
                let identifier = Details.Identifier(ownerURL: ownerURL, url: url)
                onFileDeletion([identifier])
                self.identifiers.remove(identifier)

            case .itemInodeMetadataModified(path: let path, itemType: let itemType, eventId: _, fromUs: _):
                /* .itemXattrModified(path: let path, itemType: let itemType, eventId: _, fromUs: _) */

                // TODO: Common error handling for all callbacks.
                // TODO: We need to handle directories carefully here.

                do {

                    // TODO: Consider generalising this code.
                    let url = URL(filePath: path, directoryHint: itemType == .dir ? .isDirectory : .notDirectory)
                    let identifier = Details.Identifier(ownerURL: ownerURL, url: url)

                    // Remove the file if it exists in our set.
                    if self.identifiers.contains(identifier) {
                        onFileDeletion([identifier])
                    }

                    // Create a new identifier corresponding to the udpated file.
                    let details = try FileManager.default.details(for: url, owner: ownerURL)  // TODO: details(for identifier: Details.Identifier)?
                    onFileCreation([details])

                    // Ensure there's an entry for the (potentially) new file.
                    self.identifiers.insert(identifier)

                    print("Item modified!")

                } catch {
                    print("Failed to handle file modification with error \(error).")
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

            // TODO: Handle errors.
            let fileManager = FileManager.default
            let files = Set(try! fileManager.files(directoryURL: url) + [fileManager.details(for: url, owner: url)])

            let currentState = load()

            // Add just the new files.
            let newFiles = files.subtracting(currentState)
            if newFiles.count > 0 {
                print("Inserting \(newFiles.count) new files...")
                onFileCreation(newFiles)
            }

            // Remove the remaining files.
            let deletedIdentifiers = currentState.subtracting(files)
                .map { $0.identifier }
            if deletedIdentifiers.count > 0 {
                print("Removing \(deletedIdentifiers.count) deleted files...")
                onFileDeletion(deletedIdentifiers)
            }

            self.identifiers = files.map({ $0.identifier }).reduce(into: Set<Details.Identifier>(), { partialResult, identifier in
                partialResult.insert(identifier)
            })
        }

    }

    func stop() {
        stream?.stopWatching()
        stream = nil
    }

}

