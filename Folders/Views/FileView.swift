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

struct FileView: View {

    let fileURL: URL
    let size: CGSize

    @ObservedObject var folderModel: FolderModel
    @Binding var selection: CGRect?
    @State var hover: Bool = false

    @StateObject var fileModel: FileModel

    init(fileURL: URL, size: CGSize, folderModel: FolderModel, selection: Binding<CGRect?>) {
        self.fileURL = fileURL
        self.size = size
        self.folderModel = folderModel
        _selection = selection
        _fileModel = StateObject(wrappedValue: FileModel(fileURL: fileURL, size: size))
    }

    var body: some View {
        VStack {
            GeometryReader { geometry in
                VStack {
                    if let image = fileModel.image {
                        image
                            .resizable()
                            .aspectRatio(1.0, contentMode: .fit)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .onChange(of: $selection.wrappedValue) { oldValue, newValue in
                    guard let selection else {
                        return
                    }
                    if selection.intersects(geometry.frame(in: .scrollView)) {
                        if !folderModel.selection.contains(fileURL) {
                            folderModel.selection.insert(fileURL)
                        }
                    } else {
                        if folderModel.selection.contains(fileURL) {
                            folderModel.selection.remove(fileURL)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .aspectRatio(1.0, contentMode: .fit)
            .onAppear {
                fileModel.start()
            }
            .onDisappear {
                fileModel.stop()
            }
            Text(fileURL.lastPathComponent)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(hover ? Selection().tint(Color.secondary).opacity(0.2) : nil)
        .onHover { hover in
            self.hover = hover
        }
    }

}
