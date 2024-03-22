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

protocol InteractiveCollectionViewDelegate: NSObject {

    func customCollectionView(_ customCollectionView: InteractiveCollectionView,
                              contextMenuForSelection selection: IndexSet) -> NSMenu?
    func customCollectionView(_ customCollectionView: InteractiveCollectionView,
                              didDoubleClickSelection selection: Set<IndexPath>)
    func customCollectionViewShowPreview(_ customCollectionView: InteractiveCollectionView)

}

class InteractiveCollectionView: NSCollectionView {

    struct NavigationResult {
        let nextIndexPath: IndexPath
        let intermediateIndexPaths: [IndexPath]

        init?(nextIndexPath: IndexPath?, intermediateIndexPaths: [IndexPath] = []) {
            guard let nextIndexPath else {
                return nil
            }
            self.nextIndexPath = nextIndexPath
            self.intermediateIndexPaths = intermediateIndexPaths
        }
    }

    struct IndexPathSequence: Sequence {

        enum Direction {
            case forwards
            case backwards

            static prefix func !(direction: Direction) -> Direction {
                switch direction {
                case .forwards:
                    return .backwards
                case .backwards:
                    return .forwards
                }

            }
        }

        let collectionView: InteractiveCollectionView
        let indexPath: IndexPath
        let direction: Direction

        init(collectionView: InteractiveCollectionView, indexPath: IndexPath, direction: Direction = .forwards) {
            self.collectionView = collectionView
            self.indexPath = indexPath
            self.direction = direction
        }

        func makeIterator() -> IndexPathIterator {
            return IndexPathIterator(collectionView: collectionView, indexPath: indexPath, direction: direction)
        }

    }

    struct IndexPathIterator: IteratorProtocol {

        let collectionView: InteractiveCollectionView
        var indexPath: IndexPath
        let direction: IndexPathSequence.Direction

        init(collectionView: InteractiveCollectionView, indexPath: IndexPath, direction: IndexPathSequence.Direction) {
            self.collectionView = collectionView
            self.indexPath = indexPath
            self.direction = direction
        }

        mutating func next() -> IndexPath? {
            switch direction {
            case .forwards:
                guard let nextIndexPath = collectionView.indexPath(after: indexPath) else {
                    return nil
                }
                indexPath = nextIndexPath
                return indexPath
            case .backwards:
                guard let nextIndexPath = collectionView.indexPath(before: indexPath) else {
                    return nil
                }
                indexPath = nextIndexPath
                return indexPath
            }
        }

    }

    weak var interactionDelegate: InteractiveCollectionViewDelegate?

    var cursor: IndexPath? {
        didSet {
            print("cursor = \(String(describing: cursor))")
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {

        // TODO: REset with Cmd+A

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

    func fixupSelection(direction: Direction) {

        // Sometimes the selection can change outside of our control, so we implement the following recovery
        // mechanism. This seems to match the implementation in Photos.app.
        //
        // 1) If the current cursor is contained within a selection, reset the selection to the bounds of the
        //    selected run that contains that cursor.
        //
        // 2) If the current cursor is outside the selection, reset the selection to the first range matching
        //    the requested keyboard direction (up / left will find the first selection in the list, and down /
        //    right) will find the last selection in the list.

        // Check to see if the selection range is currently valid; if it is, we've nothing to do.

        // If the current selection is nil, then we double-check to see if we can find an existing selection.
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

    override func mouseDown(with event: NSEvent) {

        // Looking at the implementation of Photos (which we're trying to match), shift click always expands the
        // selection and resets the cursor to the new position if the new position represents a modification.
        let position = self.convert(event.locationInWindow, to: nil)
        if let indexPath = self.indexPathForItem(at: position) {

            if event.modifierFlags.contains(.shift) {

                if let cursor {

                    // Shift clicking on a currently selected item does nothing.
                    guard !selectionIndexPaths.contains(indexPath) else {
                        print("Ignoring no-op...")
                        return
                    }

                    if indexPath > cursor {
                        var indexPaths = Set<IndexPath>()
                        for i in self.indexPaths(following: cursor, direction: .forwards) {
                            guard i <= indexPath else {
                                break
                            }
                            indexPaths.insert(i)
                        }
                        print("Expanding above...")
                        print(indexPaths)
                        selectItems(at: indexPaths, scrollPosition: .nearestHorizontalEdge)  // TODO: Is it enough to just update the selected items?
                        delegate?.collectionView?(self, didSelectItemsAt: indexPaths)

                        // Reset the selection bounds, placing the cursor at the new highlight.
                        self.cursor = indexPath

                    } else {
                        var indexPaths = Set<IndexPath>()
                        for i in self.indexPaths(following: cursor, direction: .backwards) {
                            guard i >= indexPath else {
                                break
                            }
                            indexPaths.insert(i)
                        }
                        print("Expanding below...")
                        print(indexPaths)
                        selectItems(at: indexPaths, scrollPosition: .nearestHorizontalEdge)  // TODO: Is it enough to just update the selected items?
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
                    selectItems(at: [indexPath], scrollPosition: .nearestHorizontalEdge)
                    delegate?.collectionView?(self, didSelectItemsAt: [indexPath])
                    cursor = indexPath
                }

            } else {

                print("indexPath = \(indexPath)")

                let selectionIndexPaths = selectionIndexPaths
                deselectItems(at: selectionIndexPaths)
                delegate?.collectionView?(self, didDeselectItemsAt: selectionIndexPaths)
                selectItems(at: [indexPath], scrollPosition: .centeredHorizontally)  // TODO: Change selection?
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
        super.mouseUp(with: event)

        // Handle double-click.
        if event.clickCount > 1, !selectionIndexPaths.isEmpty {
            interactionDelegate?.customCollectionView(self, didDoubleClickSelection: selectionIndexPaths)
            return
        }
    }

    // TODO: Rename to cursor direction?
    enum Direction {
        case up
        case down
        case left
        case right

        init?(_ keyCode: UInt16) {
            switch Int(keyCode) {
            case kVK_LeftArrow:
                self = .left
            case kVK_RightArrow:
                self = .right
            case kVK_UpArrow:
                self = .up
            case kVK_DownArrow:
                self = .down
            default:
                return nil
            }
        }

        var sequenceDirection: IndexPathSequence.Direction {
            switch self {
            case .up, .left:
                return .backwards
            case .down, .right:
                return .forwards
            }
        }

    }

    func indexPaths(following indexPath: IndexPath, direction: IndexPathSequence.Direction) -> IndexPathSequence {
        return IndexPathSequence(collectionView: self, indexPath: indexPath, direction: direction)
    }

    func firstIndexPath() -> IndexPath? {
        return self.indexPath(after: IndexPath(item: -1, section: 0))
    }

    func lastIndexPath() -> IndexPath? {
        return self.indexPath(before: IndexPath(item: 0, section: numberOfSections))
    }

    func indexPath(before indexPath: IndexPath) -> IndexPath? {

        // Try decrementing the item...
        if indexPath.item - 1 >= 0 {
            return IndexPath(item: indexPath.item - 1, section: indexPath.section)
        }

        // Try decrementing the section...
        var nextSection = indexPath.section
        while true {
            nextSection -= 1
            guard nextSection >= 0 else {
                return nil
            }
            let numberOfItems = numberOfItems(inSection: nextSection)
            if numberOfItems > 0 {
                return IndexPath(item: numberOfItems - 1, section: nextSection)
            }
        }

    }

    func indexPath(after indexPath: IndexPath) -> IndexPath? {

        // Try incrementing the item...
        if indexPath.item + 1 < numberOfItems(inSection: indexPath.section) {
            return IndexPath(item: indexPath.item + 1, section: indexPath.section)
        }

        // Try incrementing the section...
        var nextSection = indexPath.section
        while true {
            nextSection += 1
            guard nextSection < numberOfSections else {
                return nil
            }
            if numberOfItems(inSection: nextSection) > 0 {
                return IndexPath(item: 0, section: nextSection)
            }
        }

    }

    func indexPath(following indexPath: IndexPath, direction: IndexPathSequence.Direction, distance: Int = 1) -> IndexPath? {
        var indexPath: IndexPath? = indexPath
        for _ in 0..<distance {
            guard let testIndexPath = indexPath else {
                return nil
            }
            switch direction {
            case .forwards:
                indexPath = self.indexPath(after: testIndexPath)
            case .backwards:
                indexPath = self.indexPath(before: testIndexPath)
            }
        }
        return indexPath
    }

    func closestIndexPath(toIndexPath indexPath: IndexPath, direction: Direction) -> NavigationResult? {

        guard let layout = collectionViewLayout else {
            return nil
        }

        let threshold = 20.0
        let attributesForCurrentItem = layout.layoutAttributesForItem(at: indexPath)
        let currentItemFrame = attributesForCurrentItem?.frame ?? .zero
        let targetPoint: CGPoint
        let indexPaths: IndexPathSequence
        switch direction {
        case .up:
            targetPoint = CGPoint(x: currentItemFrame.midX, y: currentItemFrame.minY - threshold)
            indexPaths = self.indexPaths(following: indexPath, direction: .backwards)
        case .down:
            targetPoint = CGPoint(x: currentItemFrame.midX, y: currentItemFrame.maxY + threshold)
            indexPaths = self.indexPaths(following: indexPath, direction: .forwards)
        case .left:
            targetPoint = CGPoint(x: currentItemFrame.minX - threshold, y: currentItemFrame.midY)
            indexPaths = self.indexPaths(following: indexPath, direction: .backwards)
        case .right:
            targetPoint = CGPoint(x: currentItemFrame.maxX + threshold, y: currentItemFrame.midY)
            indexPaths = self.indexPaths(following: indexPath, direction: .forwards)
        }

        // This takes a really simple approach that either walks forwards or backwards through the cells to find the
        // next cell. It will fail hard on sparsely packed layouts or layouts which place elements randomly but feels
        // like a reasonable limitation given the current planned use-cases.
        //
        // A more flexible implementation might compute the vector from our current item to the test item and select one
        // with the lowest magnitude closest to the requested direction. It might also be possible to use this approach
        // to do wrapping more 'correctly'.
        //
        // Seeking should probably also be limited to a maximum nubmer of test items to avoid walking thousands of items
        // if no obvious match is found.

        var intermediateIndexPaths: [IndexPath] = []
        for indexPath in indexPaths {
            if let attributes = layout.layoutAttributesForItem(at: indexPath),
               attributes.frame.contains(targetPoint) {
                return NavigationResult(nextIndexPath: indexPath, intermediateIndexPaths: intermediateIndexPaths)
            }
            intermediateIndexPaths.append(indexPath)
        }
        return nil
    }

    func nextIndex(_ direction: Direction, indexPath: IndexPath?) -> NavigationResult? {

        // This implementation makes some assumptions that will work with packed grid-like layouts but are unlikely to
        // work well with sparsely packed layouts or irregular layouts. Specifically:
        //
        // - Left/Right directions are always assumed to selection the previous or next index paths by item and section.
        //
        // - Up/Down will seek through the index paths in order and return the index path of the first item which
        //   contains a point immediately above or below the starting index path.

        guard let indexPath else {
            switch direction.sequenceDirection {
            case .forwards:
                return NavigationResult(nextIndexPath: firstIndexPath())
            case .backwards:
                return NavigationResult(nextIndexPath: lastIndexPath())
            }
        }

        switch direction {
        case .up, .down:
            return closestIndexPath(toIndexPath: indexPath, direction: direction)
        case .left:
            return NavigationResult(nextIndexPath: self.indexPath(before: indexPath))
        case .right:
            return NavigationResult(nextIndexPath: self.indexPath(after: indexPath))
        }
    }

    func isSelected(_ indexPath: IndexPath?) -> Bool {
        guard let indexPath else {
            return false
        }
        return selectionIndexPaths.contains(indexPath)
    }

    override func keyDown(with event: NSEvent) {

        // Show preview.
        if event.keyCode == kVK_Space {
            guard !selectionIndexPaths.isEmpty else {
                return
            }
            // TODO: Consider fixing up the selection here too.
            // TODO: Finder does a cunning thing where if you have a selection of size greater than one, the preview
            // cycles the items in the selection, but if there's only one item, the arrow keys directly manipulate the
            // items in the grid.
            interactionDelegate?.customCollectionViewShowPreview(self)
            return
        }

        // Open the item.
        if event.modifierFlags.contains(.command),
           event.keyCode == kVK_DownArrow {
            if !selectionIndexPaths.isEmpty {
                interactionDelegate?.customCollectionView(self, didDoubleClickSelection: selectionIndexPaths)
            }
            return
        }

        // Handle custom selection wrapping behavior.
        // TODO: The selection model has a secondary behaviour if the selection is non-contiguous.
        if let direction = Direction(event.keyCode) {

            // We perform some fixup to ensure handle non-contiguous cursor-based selection which can lead to our
            // selection getting out of sync.
            fixupSelection(direction: direction)

            let modifierFlags = event.modifierFlags.intersection([.command, .shift])

            // TODO: NavigationResult isn't much use.
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
