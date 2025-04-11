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

import Foundation
import SwiftUI

class SceneModel: ObservableObject {

    let applicationModel: ApplicationModel

    @Published var selection: Set<SidebarItem.ID> = []

    init(applicationModel: ApplicationModel) {
        self.applicationModel = applicationModel
        self.selection = if let identifier = applicationModel.sidebarItems.first {
            [.owner(identifier)]
        } else {
            []
        }
    }

    func add() {
        guard let sidebarItem = applicationModel.add() else {
            return
        }
        selection = [sidebarItem]
    }

    func remove(_ sidebarItem: SidebarItem) {
        // TODO: Pick a sensible side bar selection.
        selection = []
        switch sidebarItem.kind {
        case .owner(let id):
            applicationModel.remove(id.url)
        case .folder(let id):
            applicationModel.remove(id.url)
        case .tag:
            // TODO: Consider asserting as this isn't allowed.
            break
        }
    }

    func reveal(_ sidebarItem: SidebarItem) {
        switch sidebarItem.kind {
        case .owner(let id):
            NSWorkspace.shared.reveal(id.url)
        case .folder(let id):
            NSWorkspace.shared.reveal(id.url)
        case .tag:
            // TODO: Consider asserting as this isn't allowed.
            break
        }
    }

}
