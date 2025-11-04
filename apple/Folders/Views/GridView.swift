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
import QuickLookUI

struct GridView: NSViewRepresentable {

    let sceneModel: SceneModel
    let store: Store
    let filter: Filter

    func makeNSView(context: Context) -> InnerGridView {
        return InnerGridView(sceneModel: sceneModel, store: store, filter: filter)
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {

    }

}

class InnerGridView: NSView {

    let sceneModel: SceneModel
    let storeView: StoreFilesView
    var previewPanel: QLPreviewPanel?

    enum Section {
        case none
    }

    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Details.Identifier>
    typealias DataSource = NSCollectionViewDiffableDataSource<Section, Details.Identifier>
    typealias Cell = ShortcutItemView

    private let scrollView: NSScrollView
    private let collectionView: InteractiveCollectionView
    private var dataSource: DataSource! = nil

    var activeSelectionIndexPath: IndexPath? = nil {
        didSet {
            previewPanel?.reloadData()
        }
    }

    init(sceneModel: SceneModel, store: Store, filter: any Filter) {
        self.sceneModel = sceneModel
        self.storeView = StoreFilesView(store: store, filter: filter, sort: .displayNameDescending)

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
            view.configure(url: item.url)
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

    deinit {
        storeView.stop()  // TODO: This is currently necessary to ensure the observers are removed.
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
        let identifier = dataSource.itemIdentifier(for: activeSelectionIndexPath!)!
        return PreviewItem(url: identifier.url)
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

extension InnerGridView: StoreFilesViewDelegate {

    func storeFilesView(_ storeFilesView: StoreFilesView, didUpdateFiles files: [Details]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.none])
        snapshot.appendItems(files.map({ $0.identifier }), toSection: Section.none)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // TODO: Insert details.
    func storeFilesView(_ storeFilesView: StoreFilesView, didInsertFile file: Details, atIndex index: Int, files: [Details]) {
        // TODO: Insert in the correct place.
        // TODO: We may need to rate-limit these updates.
        var snapshot = dataSource.snapshot()

        if snapshot.numberOfSections < 1 {
            snapshot.appendSections([.none])
        }

        if index < snapshot.itemIdentifiers.count {
            let beforeItem = snapshot.itemIdentifiers[index]
            snapshot.insertItems([file.identifier], beforeItem: beforeItem)
        } else if index == snapshot.itemIdentifiers.count {
            snapshot.appendItems([file.identifier])
        } else {
            fatalError("Attempting to insert an item beyond the end of the list.")
            
        }

        dataSource.apply(snapshot, animatingDifferences: true)
    }

    func storeFilesView(_ storeFilesView: StoreFilesView, didUpdateFile file: Details, atIndex: Int, files: [Details]) {
        guard let indexPath = dataSource.indexPath(for: file.identifier),
              let cell = collectionView.item(at: indexPath) as? ShortcutItemView else {
            return
        }
        cell.configure(url: file.url)
    }

    func storeFilesView(_ storeFilesView: StoreFilesView,
                        didRemoveFileWithIdentifier identifier: Details.Identifier,
                        atIndex: Int, files: [Details]) {
        var snapshot = dataSource.snapshot()
        snapshot.deleteItems([identifier])
        dataSource.apply(snapshot, animatingDifferences: true)
    }

}

extension InnerGridView: CollectionViewInteractionDelegate {

    @objc func reveal(sender: NSMenuItem) {
        guard let identifiers = sender.representedObject as? [Details.Identifier] else {
            return
        }
        // TODO: Scene.
        for identifier in identifiers {
            NSWorkspace.shared.reveal(identifier.url)
        }
    }

    @objc func setWallpaper(sender: NSMenuItem) {
        guard let identifiers = sender.representedObject as? [Details.Identifier] else {
            return
        }
        guard let screen = window?.screen else {
            return
        }
        // TODO: SceneModel or ApplicationModel?
        for identifier in identifiers {
            try? NSWorkspace.shared.setDesktopImageURL(identifier.url, for: screen)
        }
    }

    @objc func preview(sender: NSMenuItem) {
        guard sender.representedObject is [Details.Identifier] else {
            return
        }
        showPreview()
    }

    @objc func moveToTrash(sender: NSMenuItem) {
        guard let identifiers = sender.representedObject as? [Details.Identifier] else {
            return
        }
        for identifier in identifiers {
            do {
                try FileManager.default.trashItem(at: identifier.url, resultingItemURL: nil)
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

    func collectionView(_ customCollectionView: InteractiveCollectionView,
                        contextMenuForSelection selection: Set<IndexPath>) -> NSMenu? {
        let selections = selection.compactMap { indexPath in
            dataSource.itemIdentifier(for: indexPath)
        }
        guard !selections.isEmpty else {
            return nil
        }
        let menu = NSMenu()

        let items = [
            NSMenuItem(title: "Quick Look", systemImage: "eye", action: #selector(preview(sender:)), keyEquivalent: ""),
            .separator(),
            NSMenuItem(title: "Show in Finder", systemImage: "finder", action: #selector(reveal(sender:)), keyEquivalent: ""),
            .separator(),
            NSMenuItem(title: "Move to Trash", systemImage: "trash", action: #selector(moveToTrash(sender:)), keyEquivalent: ""),
            .separator(),
            NSMenuItem(title: "Set Wallpaper", systemImage: "display", action: #selector(setWallpaper(sender:)), keyEquivalent: ""),
        ]

        for item in items {
            item.representedObject = selections
        }

        menu.items = items
        return menu
    }
    
    func collectionView(_ customCollectionView: InteractiveCollectionView,
                        didDoubleClickSelection selection: Set<IndexPath>) {
        let identifiers = dataSource.itemIdentifiers(for: selection)
        for identifier in identifiers {
            NSWorkspace.shared.open(identifier.url)
        }
    }

    func collectionViewShowPreview(_ customCollectionView: InteractiveCollectionView) {
        showPreview()
    }

}

extension InnerGridView: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        activeSelectionIndexPath = indexPaths.first
    }

}



