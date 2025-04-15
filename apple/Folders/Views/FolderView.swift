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

struct FolderView: View {

    @EnvironmentObject var applicationModel: ApplicationModel
    @EnvironmentObject var sceneModel: SceneModel

    @Environment(\.openURL) var openURL

    @StateObject var folderModel: FolderModel

    let filter: Filter

    init(applicationModel: ApplicationModel, filter: Filter = TrueFilter(), selection: Set<SidebarItem.ID>) {
        _folderModel = StateObject(wrappedValue: FolderModel(store: applicationModel.store, selection: selection))
        self.filter = filter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GridView(sceneModel: sceneModel, store: applicationModel.store, filter: filter)
            if let links = folderModel.settings?.links {
                Divider()
                HStack {
                    ForEach(links, id: \.title) { link in
                        Button {
                            openURL(link.url)
                        } label: {
                            Text(link.title ?? link.url.absoluteString)
                        }
                        .buttonStyle(.link)
                        .onHover { hover in
                            if hover {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
                .padding(8)
                .background(.thinMaterial)
            }
        }
        .navigationTitle(folderModel.title)
        .presents($folderModel.error)
        .onAppear {
            folderModel.start()
        }
        .onDisappear {
            folderModel.stop()
        }
        .focusedSceneObject(folderModel)
    }

}
