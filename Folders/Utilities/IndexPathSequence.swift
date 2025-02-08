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

struct IndexPathSequence: Sequence {

    struct Iterator: IteratorProtocol {

        let collectionView: NSCollectionView
        var indexPath: IndexPath
        let direction: SequenceDirection

        init(collectionView: NSCollectionView, indexPath: IndexPath, direction: SequenceDirection) {
            self.collectionView = collectionView
            self.indexPath = indexPath
            self.direction = direction
        }

        mutating func next() -> IndexPath? {
            switch direction {
            case .forwards:
                guard let nextIndexPath = collectionView.indexPath(following: indexPath, direction: direction) else {
                    return nil
                }
                indexPath = nextIndexPath
                return indexPath
            case .backwards:
                guard let nextIndexPath = collectionView.indexPath(following: indexPath, direction: direction) else {
                    return nil
                }
                indexPath = nextIndexPath
                return indexPath
            }
        }

    }

    let collectionView: NSCollectionView
    let indexPath: IndexPath
    let direction: SequenceDirection

    init(collectionView: NSCollectionView, indexPath: IndexPath, direction: SequenceDirection = .forwards) {
        self.collectionView = collectionView
        self.indexPath = indexPath
        self.direction = direction
    }

    func makeIterator() -> Iterator {
        return Iterator(collectionView: collectionView, indexPath: indexPath, direction: direction)
    }

}
