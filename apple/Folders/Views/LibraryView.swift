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

struct LibraryView: View {

    @ObservedObject var applicationModel: ApplicationModel
    @StateObject var sceneModel: SceneModel
    @State var size: CGFloat = 400

    init(applicationModel: ApplicationModel) {
        self.applicationModel = applicationModel
        _sceneModel = StateObject(wrappedValue: SceneModel(applicationModel: applicationModel))
    }

    func filter(for sidebarItems: Set<SidebarItem.ID>) -> Filter {
        AnyFilter(oring: sidebarItems.map { kind in
            switch kind {
            case .owner(let identifier):
                return identifierFilter(identifier: identifier) && defaultTypesFilter()
            case .folder(let identifier):
                return identifierFilter(identifier: identifier) && defaultTypesFilter()
            case .tag(let name):
                return AnyFilter(.tag(name) && defaultTypesFilter())
            }
        })
    }

    var body: some View {
        NavigationSplitView {
            Sidebar(applicationModel: applicationModel, sceneModel: sceneModel)
        } detail: {
            if !sceneModel.selection.isEmpty {
                FolderView(applicationModel: applicationModel,
                           filter: filter(for: sceneModel.selection),
                           selection: sceneModel.selection)
                .id(sceneModel.selection)
            } else {
                ContentUnavailableView {
                    Label("No Folder Selected", systemImage: "folder")
                } description: {
                    Text("Select a folder in the sidebar to view its contents or add a new folder.")
                } actions: {
                    Button("Add Folder") {
                        sceneModel.add()
                    }
                }
            }
        }
        .environmentObject(sceneModel)
    }

}
