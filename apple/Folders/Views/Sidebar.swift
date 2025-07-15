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

    @ObservedObject var applicationModel: ApplicationModel
    @ObservedObject var sceneModel: SceneModel

    func color(for tag: Tag) -> Color? {
        let colors: [Color?] = [
            nil,
            .gray,
            .green,
            .purple,
            .blue,
            .yellow,
            .red,
            .orange,
        ]
        return colors[tag.colorIndex]
    }

    var body: some View {
        List(selection: $sceneModel.selection) {
            Section("Library") {
                OutlineGroup(applicationModel.dynamicSidebarItems, children: \.children) { item in
                    Label(item.kind.displayName, systemImage: item.kind.systemImage)
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
            if !applicationModel.finderTags.isEmpty {
                Section("Finder Tags") {
                    ForEach(applicationModel.finderTags, id: \.self) { tag in
                        Label {
                            Text(tag.name)
                        } icon: {
                            ColorIndicator(color: color(for: tag))
                        }
                        .tag(SidebarItem.Kind.tag(tag))
                    }
                }
            }
            if !applicationModel.tags.isEmpty {
                Section("Tags") {
                    ForEach(applicationModel.tags, id: \.self) { tag in
                        Label(tag.name, systemImage: "tag")
                            .tag(SidebarItem.Kind.tag(tag))
                    }
                }
            }
        }
    }

}
