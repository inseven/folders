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

import Yams

struct FolderSettings: Codable {

    struct Link: Codable, Identifiable {

        enum CodingKeys: CodingKey {
            case url
            case title
        }

        let id: UUID
        let url: URL
        let title: String?

        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<FolderSettings.Link.CodingKeys> = try decoder.container(keyedBy: FolderSettings.Link.CodingKeys.self)
            self.id = UUID()
            self.url = try container.decode(URL.self, forKey: FolderSettings.Link.CodingKeys.url)
            self.title = try container.decodeIfPresent(String.self, forKey: FolderSettings.Link.CodingKeys.title)
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: FolderSettings.Link.CodingKeys.self)
            try container.encode(self.url, forKey: FolderSettings.Link.CodingKeys.url)
            try container.encodeIfPresent(self.title, forKey: FolderSettings.Link.CodingKeys.title)
        }

    }

    let links: [Link]

    init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = YAMLDecoder()
        self = try decoder.decode(FolderSettings.self, from: data)
    }

}
