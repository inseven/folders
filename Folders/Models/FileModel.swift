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

class FileModel: ObservableObject {

    let fileURL: URL
    private let size: CGSize
    var request: QLThumbnailGenerator.Request? = nil

    @Published var image: Image? = nil

    init(fileURL: URL, size: CGSize) {
        self.fileURL = fileURL
        self.size = size
    }

    func start() {
        guard image == nil else {
            return
        }
        // TODO: Check if there's an async version of this and, if not, make one.
        let request = QLThumbnailGenerator.Request(fileAt: fileURL,
                                                   size: size,
                                                   scale: 3.0,
                                                   representationTypes: .thumbnail)
        request.iconMode = true
        QLThumbnailGenerator.shared.generateRepresentations(for: request) { [weak self] (thumbnail, type, error) in
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                guard let thumbnail = thumbnail else {
                    return
                }
                self.image = Image(thumbnail.cgImage, scale: 3.0, label: Text(self.fileURL.lastPathComponent))
            }
        }
        self.request = request
    }

    func stop() {
        if let request {
            QLThumbnailGenerator.shared.cancel(request)
            self.request = nil
        }
    }

}
