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

// TODO: It'd be good to show icons for folders to make it easier to debug stuff if they end up in the list.

struct TaggedText: View {

    let text: String
    let title: String
    let tags: String

    init(_ text: String) {
        self.text = text
        let components = text.components(separatedBy: " ")
        title = components.first ?? ""
        tags = components.dropFirst().joined(separator: " ")
    }

    var body: some View {
        HStack {
            Text(title)
            Text(tags)
                .foregroundStyle(.secondary)
        }
    }

}

struct Sidebar: View {

    @ObservedObject var applicationModel: ApplicationModel
    @ObservedObject var sceneModel: SceneModel

    var body: some View {
        List(selection: $sceneModel.selection) {
            Section("Library") {
                OutlineGroup(applicationModel.dynamicSidebarItems, children: \.children) { item in
                    Label {
                        Text(item.displayName)
                    } icon: {
                        Image(systemName: item.systemImage)
                    }
                    .contextMenu {
                        Button {
                            sceneModel.reveal(item)
                        } label: {
                            Text("Reveal in Finder")
                        }
                        if case .owner = item.kind {
                            Divider()
                            Button(role: .destructive) {
                                sceneModel.remove(item)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            Section("Tags") {
                ForEach(applicationModel.tags, id: \.self) { tag in
                    Label(tag, systemImage: "tag")
                        .tag(SidebarItem.Kind.tag(tag))
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    sceneModel.add()
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
    }

}
