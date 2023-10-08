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

class ApplicationModel: ObservableObject {

    private let settings = Settings()

    @Published var sidebarItems: [SidebarItem]

    var cancellables = Set<AnyCancellable>()

    init() {
        do {
            sidebarItems = try settings.rootURLs.map { folderURL in
                return try SidebarItem(folderURL: folderURL)
            }
        } catch {
            print("Failed to load sidebar items with error \(error).")
            sidebarItems = []
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
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true
        guard openPanel.runModal() ==  NSApplication.ModalResponse.OK,
              let url = openPanel.url else {
            return nil
        }
        if let sidebarItem = sidebarItems.first(where: { $0.folderURL == url }) {
            return sidebarItem
        }
        let sidebarItem = try! SidebarItem(folderURL: url)
        sidebarItems.append(sidebarItem)
        return sidebarItem
    }

    func remove(_ url: URL) {
        sidebarItems.removeAll { $0.folderURL == url }
    }

}
