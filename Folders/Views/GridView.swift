//
//  GridView.swift
//  Folders
//
//  Created by Jason Barrie Morley on 07/12/2023.
//

import SwiftUI
import QuickLookThumbnailing

struct GridView: NSViewRepresentable {

    let store: Store
    let directoryURL: URL

    func makeNSView(context: Context) -> InnerGridView {
        return InnerGridView(store: store, directoryURL: directoryURL)
    }

    func updateNSView(_ nsView: NSViewType, context: Context) {

    }

}

protocol DirectoryWatcherDelegate: NSObject {

    func directoryWatcherDidUpdate(_ directoryWatcher: DirectoryWatcher)
    func directoryWatcher(_ directoryWatcher: DirectoryWatcher, didInsertURL url: URL, atIndex: Int)

}

// TODO: Maybe don't make this an NSObject
class DirectoryWatcher: NSObject, StoreObserver {

    let store: Store
    let url: URL
    let workQueue = DispatchQueue(label: "DirectoryWatcher.workQueue")
    var files: [URL] = []

    weak var delegate: DirectoryWatcherDelegate? = nil

    init(store: Store, url: URL) {
        self.store = store
        self.url = url
        super.init()
    }

    func start() {
        Task {
            do {

                // Start observing the database.
                store.add(observer: self)

                // Get them out sorted.
                let queryStart = Date()
                let queryDuration = queryStart.distance(to: Date())
                let sortedFiles = try await store.files(parent: url)
                print("Query took \(queryDuration.formatted()) seconds and returned \(sortedFiles.count) files.")

                DispatchQueue.main.async { [self] in
                    self.files = sortedFiles
                    self.delegate?.directoryWatcherDidUpdate(self)
                }

            } catch {
                // TODO: Provide a delegate model that actually returns errors.
                print("Failed to scan for files with error \(error).")
            }
        }
    }

    func stop() {
        store.remove(observer: self)
    }

    func store(_ store: Store, didInsertURL url: URL) {
        dispatchPrecondition(condition: .notOnQueue(.main))

        // Ignore updates that don't match our filter (currently just the parent URL).
        guard url.path.starts(with: self.url.path) else {
            return
        }

        DispatchQueue.main.async {
            self.files.append(url)
            self.delegate?.directoryWatcher(self, didInsertURL: url, atIndex: self.files.count - 1)
        }
    }

    func store(_ store: Store, didRemoveURL url: URL) {
        dispatchPrecondition(condition: .notOnQueue(.main))
        DispatchQueue.main.async {
            self.files.removeAll { $0 == url }
            self.delegate?.directoryWatcher(self, didInsertURL: url, atIndex: self.files.count - 1)
        }
    }

}

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

class FixedItemSizeCollectionViewLayout: NSCollectionViewCompositionalLayout {

    init(spacing: CGFloat, size: CGSize, contentInsets: NSDirectionalEdgeInsets) {

        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(size.width), heightDimension: .absolute(size.height))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(size.height))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.interItemSpacing = .fixed(spacing)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = contentInsets

        super.init(section: section)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}



class InnerGridView: NSView {

    let directoryWatcher: DirectoryWatcher

    enum Section {
        case none
    }

    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, URL>
    typealias DataSource = NSCollectionViewDiffableDataSource<Section, URL>
    typealias Cell = ShortcutItemView

    private let scrollView: NSScrollView
    private let collectionView: CustomCollectionView
    private var dataSource: DataSource! = nil

    init(store: Store, directoryURL: URL) {
        self.directoryWatcher = DirectoryWatcher(store: store, url: directoryURL)

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false

        collectionView = CustomCollectionView()
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.collectionViewLayout = FixedItemSizeCollectionViewLayout(spacing: 16.0, size: CGSize(width: 300, height: 300), contentInsets: NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

        super.init(frame: .zero)

        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.green.cgColor

        collectionView.layer?.backgroundColor = NSColor.magenta.cgColor

        dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, item in
            guard let view = collectionView.makeItem(withIdentifier: ShortcutItemView.identifier, for: indexPath) as? ShortcutItemView else {
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
        collectionView.menuDelegate = self

//        let itemNib = NSNib(nibNamed: "ShortcutItemView", bundle: .module)
//        collectionView.register(itemNib, forItemWithIdentifier: ShortcutItemView.identifier)
        collectionView.register(ShortcutItemView.self, forItemWithIdentifier: ShortcutItemView.identifier)

        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true

        self.directoryWatcher.delegate = self
        self.directoryWatcher.start()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension InnerGridView: DirectoryWatcherDelegate {

    func directoryWatcherDidUpdate(_ directoryWatcher: DirectoryWatcher) {
        print("Scanned \(directoryWatcher.files.count) files.")

        // Update the items.
        var snapshot = Snapshot()
        snapshot.appendSections([.none])
        snapshot.appendItems(directoryWatcher.files, toSection: Section.none)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    func directoryWatcher(_ directoryWatcher: DirectoryWatcher, didInsertURL url: URL, atIndex: Int) {
        var snapshot = Snapshot()
        snapshot.appendSections([.none])
        snapshot.appendItems(directoryWatcher.files, toSection: Section.none)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

}

extension NSCollectionViewDiffableDataSource {

    func itemIdentifiers(for identifiers: Set<IndexPath>) -> Set<ItemIdentifierType> {
        return Set(identifiers.compactMap { indexPath in
            itemIdentifier(for: indexPath)
        })
    }


}

extension NSWorkspace {

    func reveal(_ url: URL) {
        selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }

}

extension InnerGridView: CustomCollectionViewMenuDelegate {

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

    func customCollectionView(_ customCollectionView: CustomCollectionView, contextMenuForSelection selection: IndexSet) -> NSMenu? {
        // TODO: Make this a utility.
        let selections = selection.compactMap { index in
            dataSource.itemIdentifier(for: IndexPath(item: index, section: 0))
        }
        guard !selections.isEmpty else {
            return nil
        }
        let menu = NSMenu()

        let revealMenuItem = NSMenuItem(title: "Reveal in Finder",
                                        action: #selector(reveal(sender:)),
                                        keyEquivalent: "")
        revealMenuItem.representedObject = selections

        let setWallpaperMenuItem = NSMenuItem(title: "Set Wallpaper",
                                              action: #selector(setWallpaper(sender:)),
                                              keyEquivalent: "")
        setWallpaperMenuItem.representedObject = selections

        menu.items = [
            revealMenuItem,
            setWallpaperMenuItem,
        ]
        return menu
    }
    
    func customCollectionView(_ customCollectionView: CustomCollectionView, didDoubleClickSelection selection: Set<IndexPath>) {
        let urls = dataSource.itemIdentifiers(for: selection)
        for url in urls {
            NSWorkspace.shared.open(url)
        }
    }

}

extension InnerGridView: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
    }

}

protocol CustomCollectionViewMenuDelegate: NSObject {

    func customCollectionView(_ customCollectionView: CustomCollectionView, contextMenuForSelection selection: IndexSet) -> NSMenu?
    func customCollectionView(_ customCollectionView: CustomCollectionView, didDoubleClickSelection selection: Set<IndexPath>)

}


class CustomCollectionView: NSCollectionView {

    weak var menuDelegate: CustomCollectionViewMenuDelegate?

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

        if let menu = menuDelegate?.customCollectionView(self, contextMenuForSelection: selectionIndexes) {
            return menu
        }

        return super.menu(for: event)
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)

        // Handle double-click.
        if event.clickCount > 1, !selectionIndexPaths.isEmpty {
            menuDelegate?.customCollectionView(self, didDoubleClickSelection: selectionIndexPaths)
        }
    }

//    override func keyDown(with event: NSEvent) {
//        if event.keyCode == kVK_Space {
//            nextResponder?.keyDown(with: event)
//            return
//        }
//        super.keyDown(with: event)
//    }
//
//    override func keyUp(with event: NSEvent) {
//        if event.keyCode == kVK_Space {
//            nextResponder?.keyUp(with: event)
//            return
//        }
//        super.keyUp(with: event)
//    }

}
