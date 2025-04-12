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

import Foundation
import Testing

@testable import Folders

@Suite("Extractor tests") struct ExtractorTests {

    @Test("Test tag extraction", arguments: [
        ("/Users/jbmorley/File.txt", []),
        ("/Users/jbmorley/File #a.txt", ["a"]),
        ("/Users/jbmorley/File #a #b.txt", ["a", "b"]),
        ("/Users/jbmorley/File #foo.txt", ["foo"]),
        ("/Users/jbmorley/File #foo #bar.txt", ["foo", "bar"]),
        ("/Users/jbmorley/File #software-development.txt", ["software-development"]),
        ("/Users/jbmorley/File #software_development.txt", ["software_development"]),
        ("/Users/jbmorley/File #software-development #user_interface.txt", ["software-development", "user_interface"]),

        ("/Users/jbmorley/File with Spaces.txt", []),
        ("/Users/jbmorley/File with Spaces #a.txt", ["a"]),
        ("/Users/jbmorley/File with Spaces #b.txt", ["b"]),
        ("/Users/jbmorley/File with Spaces #foo.txt", ["foo"]),
        ("/Users/jbmorley/File with Spaces #foo #bar.txt", ["foo", "bar"]),
        ("/Users/jbmorley/File with Spaces #software-development.txt", ["software-development"]),
        ("/Users/jbmorley/File with Spaces #software_development.txt", ["software_development"]),
        ("/Users/jbmorley/File with Spaces #software-development #user_interface.txt", ["software-development", "user_interface"]),

        ("/Users/jbmorley/Pictures #assets/icon.png", ["assets"]),
        ("/Users/jbmorley/Pictures #assets/icon #design.png", ["assets", "design"]),
    ])
    func testTagExtraction(details: (String, [String])) {
        #expect(Extractor.tags(for: URL(filePath: details.0)) == Set(details.1))
    }

}
