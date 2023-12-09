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
import QuickLookThumbnailing

class ShortcutItemView: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "CollectionViewItem")
    var label: NSTextField? = nil
    var preview: NSImageView? = nil

    // TODO: Move this back into a model?
    var request: QLThumbnailGenerator.Request? = nil

    override var isSelected: Bool {
        didSet {
            updateState()
        }
    }

    func updateState() {
        view.layer?.backgroundColor = isSelected || highlightState == .forSelection ? NSColor.controlAccentColor.cgColor : nil
    }

//    func updateSelectionState() {
//        if isSelected {
//            // Apply selected appearance
//            view.layer?.borderWidth = 2.0
//            view.layer?.borderColor = NSColor.blue.cgColor
//        } else {
//            // Apply non-selected appearance
//            view.layer?.borderWidth = 0.0
//        }
//    }

    override var highlightState: NSCollectionViewItem.HighlightState {
        didSet {
            updateState()
        }
    }

    func configure(url: URL) {

        if label == nil {
            let label = NSTextField(frame: .zero)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.isSelectable = false
            label.isEditable = false
            label.drawsBackground = false

//            view.addSubview(label)
//            NSLayoutConstraint.activate([
//                label.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//                label.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//                label.topAnchor.constraint(equalTo: view.topAnchor),
//                label.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            ])

            self.label = label
        }

        if preview == nil {
            let preview = NSImageView(frame: .zero)
            preview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(preview)
            NSLayoutConstraint.activate([
                preview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                preview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                preview.topAnchor.constraint(equalTo: view.topAnchor),
                preview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            self.preview = preview
        }

        cancel()

        let size = CGSize(width: 300, height: 300)
        // TODO: Detect the scale?

        // Load the image.
        let request = QLThumbnailGenerator.Request(fileAt: url,
                                                   size: size,
                                                   scale: 3.0,
                                                   representationTypes: .thumbnail)
        request.iconMode = true
        QLThumbnailGenerator.shared.generateRepresentations(for: request) { [weak self] (thumbnail, type, error) in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                guard let thumbnail = thumbnail else {
                    return
                }
                self.preview?.image = thumbnail.nsImage
//                self.image = Image(thumbnail.cgImage, scale: 3.0, label: Text(self.fileURL.lastPathComponent))
            }
        }
        self.request = request


        label?.stringValue = url.displayName
    }

    func cancel() {
        guard let request else {
            return
        }
        QLThumbnailGenerator.shared.cancel(request)
        self.request = nil
    }

    override func prepareForReuse() {
        cancel()
        self.preview?.image = nil
        super.prepareForReuse()
    }

}
