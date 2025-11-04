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
import QuickLookThumbnailing

class ShortcutItemView: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier(rawValue: "CollectionViewItem")

    var url: URL? = nil
    private var parentHasFocus: Bool = false
    private var parentIsKey: Bool = false

    private var label: NSTextField? = nil
    private var preview: NSImageView? = nil

    var request: QLThumbnailGenerator.Request? = nil

    override var isSelected: Bool {
        didSet {
            updateState()
        }
    }

    override func viewDidLoad() {
        view.wantsLayer = true
    }

    func updateState() {
        let selectionColor: NSColor? = if isSelected || highlightState != .none {
            parentHasFocus && parentIsKey ? .selectedContentBackgroundColor : .unemphasizedSelectedContentBackgroundColor
        } else {
            nil
        }
        view.layer?.backgroundColor = selectionColor?.cgColor
    }

    override var highlightState: NSCollectionViewItem.HighlightState {
        didSet {
            updateState()
        }
    }

    func configure(url: URL, parentHasFocus: Bool, parentIsKey: Bool) {
        if self.url != url {
            self.url = url
            configure(url: url)
        }
        self.parentHasFocus = parentHasFocus
        self.parentIsKey = parentIsKey
        updateState()
    }

    private func configure(url: URL) {

        if label == nil {
            let label = NSTextField(frame: .zero)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.isSelectable = false
            label.isEditable = false
            label.drawsBackground = false
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
        self.url = nil
        self.parentHasFocus = false
        self.parentIsKey = false
        self.preview?.image = nil
        super.prepareForReuse()
    }

}
