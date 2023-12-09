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

import AppKit

protocol InteractiveCollectionViewDelegate: NSObject {

    func customCollectionView(_ customCollectionView: InteractiveCollectionView, contextMenuForSelection selection: IndexSet) -> NSMenu?
    func customCollectionView(_ customCollectionView: InteractiveCollectionView, didDoubleClickSelection selection: Set<IndexPath>)

}

class InteractiveCollectionView: NSCollectionView {

    weak var interactionDelegate: InteractiveCollectionViewDelegate?

    override func menu(for event: NSEvent) -> NSMenu? {

        // Update the selection if necessary.
        let point = convert(event.locationInWindow, from: nil)
        if let indexPath = indexPathForItem(at: point) {
            if !selectionIndexPaths.contains(indexPath) {
                selectionIndexPaths = [indexPath]
            }
        } else {
            selectionIndexPaths = []
        }

        if let menu = interactionDelegate?.customCollectionView(self, contextMenuForSelection: selectionIndexes) {
            return menu
        }

        return super.menu(for: event)
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)

        // Handle double-click.
        if event.clickCount > 1, !selectionIndexPaths.isEmpty {
            interactionDelegate?.customCollectionView(self, didDoubleClickSelection: selectionIndexPaths)
        }
    }

//    override func keyDown(with event: NSEvent) {
//        if event.keyCode == kVK_Space {
//            nextResponder?.keyDown(with: event)
//            return
//        }
//        super.keyDown(with: event)
//    }
//
//    override func keyUp(with event: NSEvent) {
//        if event.keyCode == kVK_Space {
//            nextResponder?.keyUp(with: event)
//            return
//        }
//        super.keyUp(with: event)
//    }

}
