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

import SwiftUI
import QuickLookThumbnailing
import QuickLookUI

struct GridView: NSViewRepresentable {

    let store: Store
    let directoryURL: URL

    func makeNSView(context: Context) -> InnerGridView {
        return InnerGridView(store: store, directoryURL: directoryURL)
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {

    }

}

class InnerGridView: NSView {

    let storeView: StoreView
    var previewPanel: QLPreviewPanel?

    enum Section {
        case none
    }

    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, URL>
    typealias DataSource = NSCollectionViewDiffableDataSource<Section, URL>
    typealias Cell = ShortcutItemView

    private let scrollView: NSScrollView
    private let collectionView: InteractiveCollectionView
    private var dataSource: DataSource! = nil

    var activeSelectionIndexPath: IndexPath? = nil {
        didSet {
            previewPanel?.reloadData()
        }
    }

    init(store: Store, directoryURL: URL) {
        let filter: Filter = .parent(directoryURL) && (.conforms(to: .pdf) || .conforms(to: .jpeg) || .conforms(to: .gif) || .conforms(to: .png) || .conforms(to: .video) || .conforms(to: .mpeg4Movie) || .conforms(to: .cbz) || .conforms(to: .stl) || .conforms(to: .mp3) || .conforms(to: .tap))
        self.storeView = StoreView(store: store, filter: filter, sort: .displayNameDescending)

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false

        collectionView = InteractiveCollectionView()
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.collectionViewLayout = FixedItemSizeCollectionViewLayout(spacing: 16.0,
                                                                                size: CGSize(width: 300, height: 300),
                                                                                contentInsets: NSDirectionalEdgeInsets(top: 0,
                                                                                                                       leading: 0,
                                                                                                                       bottom: 0,
                                                                                                                       trailing: 0))

        super.init(frame: .zero)

        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.green.cgColor

        collectionView.layer?.backgroundColor = NSColor.magenta.cgColor

        dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, item in
            guard let view = collectionView.makeItem(withIdentifier: ShortcutItemView.identifier,
                                                     for: indexPath) as? ShortcutItemView else {
                return ShortcutItemView()
            }
            view.configure(url: item)
            return view
        }

        self.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        scrollView.documentView = collectionView
        collectionView.dataSource = dataSource
        collectionView.delegate = self
        collectionView.interactionDelegate = self

        collectionView.register(ShortcutItemView.self, forItemWithIdentifier: ShortcutItemView.identifier)

        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true

        self.storeView.delegate = self
        self.storeView.start()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        self.previewPanel = panel
        panel.dataSource = self
        panel.delegate = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        self.previewPanel = nil
        panel.dataSource = nil
        panel.delegate = nil
    }

}

extension InnerGridView: QLPreviewPanelDataSource, QLPreviewPanelDelegate {

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        // We return 1 to stop QuickLook trying to manage the selection on our behalf. This ensures we recieve key
        // events for all cursor keys and allows our NSCollectionView manage navigation.
        return 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        let url = dataSource.itemIdentifier(for: activeSelectionIndexPath!)!
        return PreviewItem(url: url)
    }

    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        if event.type == .keyDown {
            self.collectionView.keyDown(with: event)
            return true
        } else if event.type == .keyUp {
            self.collectionView.keyUp(with: event)
            return true
        }
        return false
    }

}

extension InnerGridView: StoreViewDelegate {

    func storeViewDidUpdate(_ storeView: StoreView) {
        print("Scanned \(storeView.files.count) files.")

        // Update the items.
        var snapshot = Snapshot()
        snapshot.appendSections([.none])
        snapshot.appendItems(storeView.files.map({ $0.url }), toSection: Section.none)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // TODO: Insert details.
    func storeView(_ storeView: StoreView, didInsertURL url: URL, atIndex index: Int) {
        // TODO: Insert in the correct place.
        // TODO: We may need to rate-limit these updates.
        var snapshot = dataSource.snapshot()

        if snapshot.numberOfSections < 1 {
            snapshot.appendSections([.none])
        }

        if index >= snapshot.itemIdentifiers.count {
            snapshot.appendItems([url])
        } else {
            let beforeItem = snapshot.itemIdentifiers[index]
            snapshot.insertItems([url], beforeItem: beforeItem)
        }

        dataSource.apply(snapshot, animatingDifferences: true)
    }

    func storeView(_ storeView: StoreView, didRemoveURL url: URL, atIndex: Int) {
        var snapshot = dataSource.snapshot()
        snapshot.deleteItems([url])
        dataSource.apply(snapshot, animatingDifferences: true)
    }

}

extension InnerGridView: InteractiveCollectionViewDelegate {

    @objc func reveal(sender: NSMenuItem) {
        guard let urls = sender.representedObject as? [URL] else {
            return
        }
        for url in urls {
            NSWorkspace.shared.reveal(url)
        }
    }

    @objc func setWallpaper(sender: NSMenuItem) {
        guard let urls = sender.representedObject as? [URL] else {
            return
        }
        guard let screen = window?.screen else {
            return
        }
        for url in urls {
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen)
        }
    }

    @objc func preview(sender: NSMenuItem) {
        guard let urls = sender.representedObject as? [URL] else {
            return
        }
        showPreview()
    }

    @objc func moveToTrash(sender: NSMenuItem) {
        guard let urls = sender.representedObject as? [URL] else {
            return
        }
        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                print("Failed to trash item with error \(error).")
            }
        }
    }

    func showPreview() {
        if QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible {
            QLPreviewPanel.shared().orderOut(nil)
        } else {
            let previewPanel = QLPreviewPanel.shared()!
            previewPanel.center()
            previewPanel.makeKeyAndOrderFront(nil)
        }
    }

    func customCollectionView(_ customCollectionView: InteractiveCollectionView, contextMenuForSelection selection: IndexSet) -> NSMenu? {
        // TODO: Make this a utility.
        let selections = selection.compactMap { index in
            dataSource.itemIdentifier(for: IndexPath(item: index, section: 0))
        }
        guard !selections.isEmpty else {
            return nil
        }
        let menu = NSMenu()

        let items = [
            NSMenuItem(title: "Preview", action: #selector(preview(sender:)), keyEquivalent: ""),
            .separator(),
            NSMenuItem(title: "Reveal in Finder", action: #selector(reveal(sender:)), keyEquivalent: ""),
            .separator(),
            NSMenuItem(title: "Move to Trash", action: #selector(moveToTrash(sender:)), keyEquivalent: ""),
            .separator(),
            NSMenuItem(title: "Set Wallpaper", action: #selector(setWallpaper(sender:)), keyEquivalent: ""),
        ]

        for item in items {
            item.representedObject = selections
        }

        menu.items = items
        return menu
    }
    
    func customCollectionView(_ customCollectionView: InteractiveCollectionView, didDoubleClickSelection selection: Set<IndexPath>) {
        let urls = dataSource.itemIdentifiers(for: selection)
        for url in urls {
            NSWorkspace.shared.open(url)
        }
    }

    func customCollectionViewShowPreview(_ customCollectionView: InteractiveCollectionView) {
        showPreview()
    }

}

extension InnerGridView: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        activeSelectionIndexPath = indexPaths.first
    }

}

