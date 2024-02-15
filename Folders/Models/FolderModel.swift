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

struct FolderSettings: Codable {

    let url: URL

}

class FolderModel: ObservableObject {

    let url: URL

    @Published var settings: FolderSettings?

    init(url: URL) {
        self.url = url
    }

    func start() {
        let settingsURL = url.appendingPathComponent("folders-settings.json")  // TODO: Could I get macOS to hide these for me?
        guard FileManager.default.fileExists(atPath: settingsURL.path) else {
            return
        }
        do {
            let data = try Data(contentsOf: settingsURL)
            let decoder = JSONDecoder()
            let settings = try decoder.decode(FolderSettings.self, from: data)
            self.settings = settings
        } catch {
            print("Failed to load folder settings with error \(error).")
        }
    }

    func stop() {

    }

}
