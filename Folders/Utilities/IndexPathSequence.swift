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

import Foundation

struct IndexPathSequence: Sequence {

    struct Iterator: IteratorProtocol {

        let collectionView: InteractiveCollectionView
        var indexPath: IndexPath
        let direction: SequenceDirection

        init(collectionView: InteractiveCollectionView, indexPath: IndexPath, direction: SequenceDirection) {
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

    let collectionView: InteractiveCollectionView
    let indexPath: IndexPath
    let direction: SequenceDirection

    init(collectionView: InteractiveCollectionView, indexPath: IndexPath, direction: SequenceDirection = .forwards) {
        self.collectionView = collectionView
        self.indexPath = indexPath
        self.direction = direction
    }

    func makeIterator() -> Iterator {
        return Iterator(collectionView: collectionView, indexPath: indexPath, direction: direction)
    }

}
