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
import QuickLook

struct FolderView: View {

    let folderURL: URL

    @State private var selection: CGRect? = nil
    @StateObject var folderModel: FolderModel
    @Environment(\.openURL) var openURL

    init(folderURL: URL) {
        self.folderURL = folderURL
        _folderModel = StateObject(wrappedValue: FolderModel(directoryURL: folderURL))
    }

    var columns: [GridItem] {
        return [GridItem(.adaptive(minimum: 0.6 * folderModel.size, maximum: folderModel.size), spacing: 16.0)]
    }

    var body: some View {
        VStack {
            ScrollView {
                ZStack(alignment: .topLeading) {
                    SelectionTracker(selection: $selection)
                    LazyVGrid(columns: columns) {
                        ForEach(folderModel.files) { fileURL in
                            FileView(fileURL: fileURL, size: CGSize(width: folderModel.size, height: folderModel.size), folderModel: folderModel, selection: $selection)
                                .background(folderModel.selection.contains(fileURL) ? Selection() : nil)
                                .foregroundStyle(folderModel.selection.contains(fileURL) ? .white : .secondary)
                                .onTapGesture {
                                    guard !folderModel.selection.contains(fileURL) else {
                                        return
                                    }
                                    folderModel.selection = Set([fileURL])
                                }
                                .simultaneousGesture(TapGesture().modifiers(.shift).onEnded {
                                    folderModel.selection.insert(fileURL)
                                })
                                .simultaneousGesture(TapGesture(count: 2).onEnded({ _ in
                                    folderModel.open()
                                }))
                                .simultaneousGesture(LongPressGesture().onEnded({ _ in
                                    print("RIGHT-CLICK \(fileURL.path)")
                                    folderModel.selection = Set([fileURL])
                                }))
                                .simultaneousGesture(TapGesture(count: 1).modifiers(.control).onEnded({ _ in
                                    print("Control Left-Click")
                                }))
                                .contextMenu {
                                    Button("Reveal in Finder") {
                                        folderModel.reveal(url: fileURL)
                                    }
                                    Button("Set Wallpaper") {
                                        guard let screen = NSScreen.main else {
                                            return
                                        }
                                        try? NSWorkspace.shared.setDesktopImageURL(fileURL, for: screen)
                                    }
                                }
                        }
                    }
                    .padding()
                    SelectionLoop(selection: $selection)
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $folderModel.scrollPosition)
            .overlay(folderModel.state == .loading ? ProgressView() : nil)
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(.rightArrow) {
                folderModel.selectNext()
                return .handled
            }
            .onKeyPress(.leftArrow) {
                folderModel.selectPrevious()
                return .handled
            }
            .onKeyPress(.return) {
                folderModel.open()
                return .handled
            }
            .onKeyPress(.space) {
                folderModel.showPreview()
                return .handled
            }
            .quickLookPreview($folderModel.preview, in: folderModel.files)
        }
        .background(Color(NSColor.textBackgroundColor))
        .navigationTitle(folderModel.title)
        .navigationSubtitle(folderModel.state == .loading ? "Loading..." : "\(folderModel.files.count) items")
        .toolbar(id: "main") {
            ToolbarItem(id: "scale") {
                LabeledContent {
                    Slider(value: $folderModel.size, in: 100...600)
                        .frame(minWidth: 100)
                } label: {
                    Text("Preview Size")
                }
            }
        }
        .onAppear {
            folderModel.start()
        }
        .onDisappear {
            folderModel.stop()
        }
    }

}
