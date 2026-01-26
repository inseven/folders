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

import SwiftUI

import Interact

struct SelectionToolbar: CustomizableToolbarContent {

    @FocusedObject var folderViewModel: FolderViewModel?

    var body: some CustomizableToolbarContent {

        ToolbarItem(id: "finder") {
            Button("Show in Finder", systemImage: "finder") {
                guard let selection = folderViewModel?.selection else {
                    return
                }
                let urls = selection.map { $0.url }
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            }
            .disabled(folderViewModel?.selection.isEmpty ?? false)
            .help("Show items in Finder")
        }

        ToolbarItem(id: "trash") {
            Button("Delete", systemImage: "trash") {
                guard let selection = folderViewModel?.selection else {
                    return
                }
                let urls = selection.map { $0.url }
                NSWorkspace.shared.recycle(urls)
            }
            .disabled(folderViewModel?.selection.isEmpty ?? false)
            .help("Move the selected items to the Bin")
        }

        ToolbarItem(id: "links") {
            Menu {
                if let folderViewModel {
                    SelectionLinksMenu(folderViewModel: folderViewModel)
                }
            } label: {
                Image(systemName: "link")
            }
            .disabled(folderViewModel == nil)
        }
    }

}
