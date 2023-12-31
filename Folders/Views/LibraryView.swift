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

import SwiftUI

struct LibraryView: View {

    @ObservedObject var applicationModel: ApplicationModel
    @StateObject var sceneModel: SceneModel
    @State var size: CGFloat = 400

    init(applicationModel: ApplicationModel) {
        self.applicationModel = applicationModel
        _sceneModel = StateObject(wrappedValue: SceneModel(applicationModel: applicationModel))
    }

    var body: some View {
        NavigationSplitView {
            Sidebar(applicationModel: applicationModel, sceneModel: sceneModel)
        } detail: {
            if let folderURL = sceneModel.selection?.folderURL {
                GridView(store: applicationModel.store, directoryURL: folderURL)
                    .navigationTitle(folderURL.displayName)
                    .id(folderURL)
            }
        }
        .toolbar(id: "main") {
            ToolbarItem(id: "scale") {
                LabeledContent {
                    Slider(value: $size, in: 100...600)
                        .frame(minWidth: 100)
                } label: {
                    Text("Preview Size")
                }
            }
        }

    }

}
