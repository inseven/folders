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


struct Selection {

    var anchor: IndexPath
    var cursor: IndexPath

    var min: IndexPath {
        return Swift.min(anchor, cursor)
    }

    var max: IndexPath {
        return Swift.max(anchor, cursor)
    }

    init(indexPath: IndexPath) {
        self.anchor = indexPath
        self.cursor = indexPath
    }

    init(anchor: IndexPath, cursor: IndexPath) {
        self.anchor = anchor
        self.cursor = cursor
    }

    mutating func reset(_ indexPath: IndexPath) {
        anchor = indexPath
        cursor = indexPath
    }

    func contains(_ indexPath: IndexPath) -> Bool {
        if anchor <= cursor {
            return indexPath <= cursor && indexPath >= anchor
        } else {
            return indexPath <= anchor && indexPath >= cursor
        }
    }

}

class InteractiveCollectionView: NSCollectionView {

    struct NavigationResult {
        let nextIndexPath: IndexPath
        let intermediateIndexPaths: [IndexPath]

        // TODO: Construct this on creation?
        var allIndexPaths: Set<IndexPath> {
            return Set([nextIndexPath] + intermediateIndexPaths)
        }

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

    var anchor: IndexPath? {
        didSet {
            print("anchor = \(String(describing: anchor))")
        }
    }

    var cursor: IndexPath? {
        didSet {
            print("cursor = \(String(describing: cursor))")
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

        if let menu = interactionDelegate?.customCollectionView(self, contextMenuForSelection: selectionIndexes) {
            return menu
        }

        return super.menu(for: event)
    }

    func contiguousSelection(cursor: IndexPath, direction: IndexPathSequence.Direction) -> Selection {
        precondition(selectionIndexPaths.contains(cursor))
        var anchor = cursor
        for indexPath in indexPaths(following: cursor, direction: direction) {
            guard selectionIndexPaths.contains(indexPath) else {
                break
            }
            anchor = indexPath
        }
        return Selection(anchor: anchor, cursor: cursor)
    }

    func findContiguousSelection(direction: Direction) -> Selection? {
        switch direction {
        case .down, .right:
            guard let cursor = selectionIndexPaths.max() else {
                return nil
            }
            var start = cursor
            for indexPath in indexPaths(following: cursor, direction: .backwards) {
                guard selectionIndexPaths.contains(indexPath) else {
                    break
                }
                start = indexPath
            }
            return Selection(anchor: start, cursor: cursor)
        case .up, .left:
            guard let cursor = selectionIndexPaths.min() else {
                return nil
            }
            var start = cursor
            for indexPath in indexPaths(following: cursor, direction: .forwards) {
                guard selectionIndexPaths.contains(indexPath) else {
                    break
                }
                start = indexPath
            }
            return Selection(anchor: start, cursor: cursor)
        }
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
        if anchor == nil, cursor == nil {
            guard let selection = findContiguousSelection(direction: direction) else {
                return
            }
            print(selection)
            self.anchor = selection.anchor
            self.cursor = selection.cursor
        }
    }

    override func mouseDown(with event: NSEvent) {
//        super.mouseDown(with: event)

        // Looking at the implementation of Photos (which we're trying to match), shift click always expands the
        // selection and resets the cursor to the new position if the new position represents a modification.
        let position = self.convert(event.locationInWindow, to: nil)
        if let indexPath = self.indexPathForItem(at: position) {

            if event.modifierFlags.contains(.shift) {

                if let anchor, let cursor {

                    let selection = Selection(anchor: anchor, cursor: cursor)

                    // Shift clicking on a currently selected item does nothing.
                    guard !selection.contains(indexPath) else {
                        print("Ignoring no-op...")
                        return
                    }

                    print("EXPANDING SELECTION TO \(indexPath)")

                    if indexPath > selection.max {
                        var indexPaths = Set<IndexPath>()
                        for i in self.indexPaths(following: selection.max, direction: .forwards) {
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
                        self.anchor = selection.min

                    } else {
                        var indexPaths = Set<IndexPath>()
                        for i in self.indexPaths(following: selection.min, direction: .backwards) {
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
                        self.anchor = selection.max
                    }

                }

            } else if event.modifierFlags.contains(.command) {

                // This behaves like shift click if the new item is contiguous with the current selection. If not, it
                // breaks the current selection and resets it to largest bounds that contain the new selection.

                // Keyboard selection can slurp up existing blocks; if a new block is encountered then it merges with
                // the current block and the anchor resets to the beginning (or end, depending on direction) of the block.

                // Actually, I think the implementation might be dumber than this. It seems that _if_ there's a non-contiguous
                // selection then the anchor always pushes instead of flips.

                // This implementation only performs partial fixup of the selection and relies on `fixupSelection` which
                // is called when the user navigates using the cursor and relies on the cursor direction as a hint.

                let selectionIndexPaths = selectionIndexPaths
                if selectionIndexPaths.contains(indexPath) {
                    deselectItems(at: [indexPath])
                    delegate?.collectionView?(self, didDeselectItemsAt: [indexPath])

                    // Double check to see if this breaks a contiugous selection and fix it up if it does.

                    // 1) Photos treats deselecting the cursor as a complete selection reset.
                    // TODO: We should guard against this scenario in the fixup.
                    if cursor == indexPath {
                        cursor = nil
                        anchor = nil
                        return
                    }

                    // Otherwise, we try to fix up the selection.
                    // TODO: We should also do this in fixup.
                    if let anchor, let cursor {
                        let selection = Selection(anchor: anchor, cursor: cursor)
                        if selection.contains(indexPath) {
                            if anchor < cursor {
                                let newSelection = contiguousSelection(cursor: cursor, direction: .backwards)
                                self.anchor = newSelection.anchor
                            } else {
                                let newSelection = contiguousSelection(cursor: cursor, direction: .forwards)
                                self.anchor = newSelection.anchor
                            }
                        }
                    }

                } else {
                    selectItems(at: [indexPath], scrollPosition: .nearestHorizontalEdge)
                    delegate?.collectionView?(self, didSelectItemsAt: [indexPath])
                    // Reset the selection cursor and anchor to the last selection.
                    cursor = indexPath
                    anchor = indexPath
                }


                // The logic here: we prefer the cursor, so we set the bounds to the selection bounds that contains the cursor, placing
                // the anchor at the oposite end of that range. That works for both addition and removal. Addition sets the new cursor
                // and removal leaves the cursor the same. Afterwards, we search from the cursor _towards_ the old anchor and set the
                // new anchor to last index path in the first contiguous block.

                // The anchor is allowed to _slide_ if there's a non-contiguous block.


            } else {

                print("indexPath = \(indexPath)")

                let selectionIndexPaths = selectionIndexPaths
                deselectItems(at: selectionIndexPaths)
                delegate?.collectionView?(self, didDeselectItemsAt: selectionIndexPaths)
                selectItems(at: [indexPath], scrollPosition: .centeredHorizontally)  // TODO: Change selection?
                delegate?.collectionView?(self, didSelectItemsAt: [indexPath])
                anchor = indexPath
                cursor = indexPath

            }

            return
        }

        // The user is beginning a mouse-driven selection so we clear the current tracked selection; it will get fixed
        // up on subsequent keyboard events.
        self.cursor = nil
        self.anchor = nil

        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)

//        // Update the active selection details.
//        let position = self.convert(event.locationInWindow, to: nil)
//        let indexPath = self.indexPathForItem(at: position) ?? selectionIndexPaths.first
//        anchor = indexPath
//        cursor = indexPath

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

    }

//    func indexPaths(after indexPath: IndexPath) -> IndexPathSequence {
//        return IndexPathSequence(collectionView: self, indexPath: indexPath, direction: .forwards)
//    }
//
//    func indexPaths(before indexPath: IndexPath) -> IndexPathSequence {
//        return IndexPathSequence(collectionView: self, indexPath: indexPath, direction: .backwards)
//    }

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
            switch direction {
            case .down, .right:
                return NavigationResult(nextIndexPath: firstIndexPath())
            case .up, .left:
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

    // TODO: Views don't end up selected on creation?

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

            if let navigationResult = nextIndex(direction, indexPath: cursor) {
                if let cursor, let anchor, modifierFlags == .shift {

                    // Calculate the changes required to transition from the current selection to the new selection.
                    let newSelection = Selection(anchor: anchor, cursor: navigationResult.nextIndexPath)
                    let indexPaths = Set([cursor] + navigationResult.intermediateIndexPaths + [navigationResult.nextIndexPath])
                    let selections = indexPaths.filter { newSelection.contains($0) }
                    let deselections = indexPaths.subtracting(selections)

                    // Update the selection state and our delegate.
                    deselectItems(at: deselections)
                    delegate?.collectionView?(self, didDeselectItemsAt: deselections)
                    selectItems(at: selections, scrollPosition: .nearestHorizontalEdge)
                    delegate?.collectionView?(self, didSelectItemsAt: selections)
                    scrollToItems(at: [navigationResult.nextIndexPath], scrollPosition: .nearestHorizontalEdge)
                    self.cursor = navigationResult.nextIndexPath

                } else if modifierFlags.isEmpty {

                    // Without shift held down the selection is always reset.
                    // TODO: Photos and Finder seem to use the edges of the selection to determine where the cursor
                    // move operation is starting; this ensures thst the arrow keys always move the cursor outside the
                    // current selection. I don't think this is _necessary_, but it would be good to match the platform.
                    deselectItems(at: selectionIndexPaths)
                    delegate?.collectionView?(self, didDeselectItemsAt: selectionIndexPaths)
                    selectItems(at: [navigationResult.nextIndexPath], scrollPosition: .nearestHorizontalEdge)
                    delegate?.collectionView?(self, didSelectItemsAt: [navigationResult.nextIndexPath])
                    scrollToItems(at: [navigationResult.nextIndexPath], scrollPosition: .nearestHorizontalEdge)
                    anchor = navigationResult.nextIndexPath
                    cursor = navigationResult.nextIndexPath

                }

            }
            return
        }

        super.keyDown(with: event)

        // TODO: Is this necessary?
//        if let indexPath = selectionIndexPaths.first {
//            selection = Selection(indexPath)
//        }
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == kVK_Space {
            return
        }
        super.keyUp(with: event)
    }

}
