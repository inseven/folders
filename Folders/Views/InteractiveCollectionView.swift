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

import AppKit
import Carbon

protocol CollectionViewInteractionDelegate: NSObject {

    func collectionView(_ collectionView: InteractiveCollectionView, contextMenuForSelection selection: Set<IndexPath>) -> NSMenu?
    func collectionView(_ collectionView: InteractiveCollectionView, didDoubleClickSelection selection: Set<IndexPath>)
    func collectionViewShowPreview(_ collectionView: InteractiveCollectionView)

}

class InteractiveCollectionView: NSCollectionView {

    weak var interactionDelegate: CollectionViewInteractionDelegate?

    var cursor: IndexPath?

    func fixupSelection(direction: NavigationDirection) {

        // Sometimes the selection can change outside of our control, so we implement the following recovery
        // mechanism. This seems to match the implementation in Photos.app.
        //
        // Specifically, if the current cursor is outside the selection, we place the cursor at the first or last
        // selected item depending on the requested navigation direction--up/left will use the first selected item, and
        // down/right will find the last selected item.

        if cursor == nil {
            switch direction.sequenceDirection {
            case .forwards:
                self.cursor = selectionIndexPaths.max()
            case .backwards:
                self.cursor = selectionIndexPaths.min()
            }
            return
        }
    }

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

        if let menu = interactionDelegate?.collectionView(self, contextMenuForSelection: selectionIndexPaths) {
            return menu
        }

        return super.menu(for: event)
    }

    override func mouseDown(with event: NSEvent) {

        // Ignore events if we're not the key window.
        guard (self.window?.isKeyWindow ?? false) else {
            return
        }

        window?.makeFirstResponder(self)

        let position = self.convert(event.locationInWindow, from: nil)
        if let indexPath = self.indexPathForItem(at: position) {

            if event.modifierFlags.contains(.shift) {

                // Looking at the implementation of Photos (which we're trying to match), shift click always expands the
                // selection and resets the cursor to the new position if the new position represents a modification.

                if let cursor {

                    // Shift clicking on a currently selected item does nothing.
                    guard !selectionIndexPaths.contains(indexPath) else {
                        return
                    }

                    if indexPath > cursor {
                        var indexPaths = Set<IndexPath>()
                        for i in self.indexPathSequence(following: cursor, direction: .forwards) {
                            guard i <= indexPath else {
                                break
                            }
                            indexPaths.insert(i)
                        }
                        selectItems(at: indexPaths, scrollPosition: [])
                        delegate?.collectionView?(self, didSelectItemsAt: indexPaths)

                        // Reset the selection bounds, placing the cursor at the new highlight.
                        self.cursor = indexPath

                    } else {
                        var indexPaths = Set<IndexPath>()
                        for i in self.indexPathSequence(following: cursor, direction: .backwards) {
                            guard i >= indexPath else {
                                break
                            }
                            indexPaths.insert(i)
                        }
                        selectItems(at: indexPaths, scrollPosition: [])
                        delegate?.collectionView?(self, didSelectItemsAt: indexPaths)

                        // Reset the selection bounds, placing the cursor at the new highlight.
                        self.cursor = indexPath
                    }

                }

            } else if event.modifierFlags.contains(.command) {

                // This behaves like shift click if the new item is contiguous with the current selection. If not, it
                // breaks the current selection and resets it to largest bounds that contain the new selection.

                let selectionIndexPaths = selectionIndexPaths
                if selectionIndexPaths.contains(indexPath) {
                    deselectItems(at: [indexPath])
                    delegate?.collectionView?(self, didDeselectItemsAt: [indexPath])

                    // Here again, we copy Photos which treats deselecting the cursor as a complete selection reset.
                    if cursor == indexPath {
                        cursor = nil
                        return
                    }

                } else {
                    selectItems(at: [indexPath], scrollPosition: [])
                    delegate?.collectionView?(self, didSelectItemsAt: [indexPath])
                    cursor = indexPath
                }

            } else {

                let selectionIndexPaths = selectionIndexPaths
                deselectItems(at: selectionIndexPaths)
                delegate?.collectionView?(self, didDeselectItemsAt: selectionIndexPaths)
                selectItems(at: [indexPath], scrollPosition: [])
                delegate?.collectionView?(self, didSelectItemsAt: [indexPath])
                cursor = indexPath

            }

            return
        }

        // The user is beginning a mouse-driven selection so we clear the current tracked selection; it will get fixed
        // up on subsequent keyboard events.
        self.cursor = nil

        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {

        // Ignore events if we're not the key window.
        guard (self.window?.isKeyWindow ?? false) else {
            return
        }

        super.mouseUp(with: event)

        // Handle double-click.
        if event.clickCount > 1, !selectionIndexPaths.isEmpty {
            interactionDelegate?.collectionView(self, didDoubleClickSelection: selectionIndexPaths)
            return
        }
    }

    override func keyDown(with event: NSEvent) {

        // Show preview.
        if event.keyCode == kVK_Space {
            guard !selectionIndexPaths.isEmpty else {
                return
            }
            // TODO: Consider fixing up the selection here too. (Finder does a cunning thing where if you have a
            //       selection of size greater than one, the preview cycles the items in the selection, but if there's
            //       only one item, the arrow keys directly manipulate the items in the grid.)
            interactionDelegate?.collectionViewShowPreview(self)
            return
        }

        // Open the item.
        if event.modifierFlags.contains(.command),
           event.keyCode == kVK_DownArrow {
            if !selectionIndexPaths.isEmpty {
                interactionDelegate?.collectionView(self, didDoubleClickSelection: selectionIndexPaths)
            }
            return
        }

        // Handle custom selection wrapping behavior.
        if let direction = NavigationDirection(event.keyCode) {

            // We perform some fixup to ensure handle non-contiguous cursor-based selection which can lead to our
            // selection getting out of sync.
            fixupSelection(direction: direction)

            let modifierFlags = event.modifierFlags.intersection([.command, .shift])

            if let navigationResult = nextIndex(direction, indexPath: cursor) {
                if modifierFlags == .shift {

                    var selections: Set<IndexPath> = []
                    var deselections: Set<IndexPath> = []

                    // Walk towards the next item.
                    for indexPath in navigationResult.intermediateIndexPaths + [navigationResult.nextIndexPath] {
                        let previousIndexPath = self.indexPath(following: indexPath,
                                                               direction: !direction.sequenceDirection,
                                                               distance: 2)
                        if !isSelected(previousIndexPath) && isSelected(indexPath) {
                            // Contraction.
                            if let operationIndex = self.indexPath(following: indexPath,
                                                                   direction: !direction.sequenceDirection,
                                                                   distance: 1) {
                                deselections.insert(operationIndex)
                                selectionIndexPaths.remove(operationIndex)
                            }
                        } else {
                            // Expansion.
                            selections.insert(indexPath)
                            selectionIndexPaths.insert(indexPath)
                        }
                    }

                    deselectItems(at: deselections)
                    delegate?.collectionView?(self, didDeselectItemsAt: deselections)
                    selectItems(at: selections, scrollPosition: .nearestHorizontalEdge)
                    delegate?.collectionView?(self, didSelectItemsAt: selections)
                    scrollToItems(at: [navigationResult.nextIndexPath], scrollPosition: .nearestHorizontalEdge)
                    self.cursor = navigationResult.nextIndexPath

                } else if modifierFlags.isEmpty {

                    // Without shift held down the selection is always reset.
                    deselectItems(at: selectionIndexPaths)
                    delegate?.collectionView?(self, didDeselectItemsAt: selectionIndexPaths)
                    selectItems(at: [navigationResult.nextIndexPath], scrollPosition: .nearestHorizontalEdge)
                    delegate?.collectionView?(self, didSelectItemsAt: [navigationResult.nextIndexPath])
                    scrollToItems(at: [navigationResult.nextIndexPath], scrollPosition: .nearestHorizontalEdge)
                    cursor = navigationResult.nextIndexPath

                }

            }
            return
        }

        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == kVK_Space {
            return
        }
        super.keyUp(with: event)
    }

}
