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

struct Arse: View {

    @ObservedObject var selectionModel: SelectionModel

    var body: some View {
        if !selectionModel.settings.isEmpty {
            ForEach(selectionModel.settingsURLs) { settingsURL in
                if let folderSettings = selectionModel.settings[settingsURL] {
                    FolderLinks(folderSettings: folderSettings)
                    if selectionModel.settingsURLs.last != settingsURL  {
                        Divider()
                    }
                }
            }
        } else {
            Text("No links")
        }
    }

}

struct SelectionToolbar: CustomizableToolbarContent {

    @FocusedObject var selectionModel: SelectionModel?

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "links") {
            Menu {
                if let selectionModel {
                    Arse(selectionModel: selectionModel)
                }
            } label: {
                Image(systemName: "link")
            }
            .disabled(selectionModel == nil)
        }
    }

}
