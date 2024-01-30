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

struct Sidebar: View {

    @ObservedObject var applicationModel: ApplicationModel
    @ObservedObject var sceneModel: SceneModel

    var body: some View {
        List(applicationModel.sidebarItems, id: \.self, children: \.children, selection: $sceneModel.selection) { item in
            Label(item.folderURL.displayName, systemImage: "folder")
                .contextMenu {
                    Button {
                        NSWorkspace.shared.reveal(item.folderURL)
                    } label: {
                        Text("Reveal in Finder")
                    }
                    Divider()
                    Button(role: .destructive) {
                        applicationModel.remove(item.folderURL)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    guard let sidebarItem = applicationModel.add() else {
                        return
                    }
                    sceneModel.selection = sidebarItem
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
    }

}
