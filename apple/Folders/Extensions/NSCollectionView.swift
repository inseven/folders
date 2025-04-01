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

import AppKit

extension NSCollectionView {

    func isSelected(_ indexPath: IndexPath?) -> Bool {
        guard let indexPath else {
            return false
        }
        return selectionIndexPaths.contains(indexPath)
    }

    func firstIndexPath() -> IndexPath? {
        return self.indexPath(after: IndexPath(item: -1, section: 0))
    }

    func lastIndexPath() -> IndexPath? {
        return self.indexPath(before: IndexPath(item: 0, section: numberOfSections))
    }

    fileprivate func indexPath(before indexPath: IndexPath) -> IndexPath? {

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

    fileprivate func indexPath(after indexPath: IndexPath) -> IndexPath? {

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

    func indexPathSequence(following indexPath: IndexPath, direction: SequenceDirection) -> IndexPathSequence {
        return IndexPathSequence(collectionView: self, indexPath: indexPath, direction: direction)
    }

    func indexPath(following indexPath: IndexPath, direction: SequenceDirection, distance: Int = 1) -> IndexPath? {
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

    func closestIndexPath(toIndexPath indexPath: IndexPath, direction: NavigationDirection) -> CollectionViewNavigationResult? {

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
            indexPaths = self.indexPathSequence(following: indexPath, direction: .backwards)
        case .down:
            targetPoint = CGPoint(x: currentItemFrame.midX, y: currentItemFrame.maxY + threshold)
            indexPaths = self.indexPathSequence(following: indexPath, direction: .forwards)
        case .left:
            targetPoint = CGPoint(x: currentItemFrame.minX - threshold, y: currentItemFrame.midY)
            indexPaths = self.indexPathSequence(following: indexPath, direction: .backwards)
        case .right:
            targetPoint = CGPoint(x: currentItemFrame.maxX + threshold, y: currentItemFrame.midY)
            indexPaths = self.indexPathSequence(following: indexPath, direction: .forwards)
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
                return CollectionViewNavigationResult(nextIndexPath: indexPath, intermediateIndexPaths: intermediateIndexPaths)
            }
            intermediateIndexPaths.append(indexPath)
        }
        return nil
    }

    func nextIndex(_ direction: NavigationDirection, indexPath: IndexPath?) -> CollectionViewNavigationResult? {

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
                return CollectionViewNavigationResult(nextIndexPath: firstIndexPath())
            case .backwards:
                return CollectionViewNavigationResult(nextIndexPath: lastIndexPath())
            }
        }

        switch direction {
        case .up, .down:
            return closestIndexPath(toIndexPath: indexPath, direction: direction)
        case .left:
            return CollectionViewNavigationResult(nextIndexPath: self.indexPath(following: indexPath, direction: .backwards))
        case .right:
            return CollectionViewNavigationResult(nextIndexPath: self.indexPath(following: indexPath, direction: .forwards))
        }
    }

}
