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

struct Sidebar: View {

    @SceneStorage("expand-library") private var isLibrarySectionExpanded: Bool = true
    @SceneStorage("expand-tags") private var isTagsSectionExpanded: Bool = false

    @ObservedObject var applicationModel: ApplicationModel
    @ObservedObject var sceneModel: SceneModel

    var body: some View {
        List(selection: $sceneModel.selection) {
            Section(isExpanded: $isLibrarySectionExpanded) {
                OutlineGroup(applicationModel.dynamicSidebarItems, children: \.children) { item in
                    Label(item.kind.displayName, systemImage: item.kind.systemImage)
                        .contextMenu {
                            Button("Show in Finder", systemImage: "finder") {
                                sceneModel.reveal(item)
                            }
                            if case .owner = item.kind {
                                Divider()
                                Button("Remove", systemImage: "folder.badge.minus", role: .destructive) {
                                    sceneModel.remove(item)
                                }
                            }
                        }
                }
            } header: {
                SidebarActionHeader {
                    Button("Add Folder...", systemImage: "folder.badge.plus") {
                        sceneModel.add()
                    }
                }
            }
            Section("Tags", isExpanded: $isTagsSectionExpanded) {
                ForEach(applicationModel.tags, id: \.self) { tag in
                    Label(tag.name, systemImage: "tag")
                        .tag(SidebarItem.Kind.tag(tag.name))
                }
            }
        }
    }

}
