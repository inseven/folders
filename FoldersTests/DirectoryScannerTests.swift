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

import XCTest
@testable import Folders

final class DirectoryScannerTests: XCTestCase {

    func testCreate() throws {
        try withTemporaryDirectory { directoryURL in
            let url = directoryURL.appendingPathComponent("example.txt")
            let expectation = self.expectation(description: "create file")
            let scanner = try scan(directoryURL: directoryURL) { files in
                XCTAssertEqual(files.count, 1)
                XCTAssertEqual(files.first?.ownerURL, directoryURL)
                XCTAssertEqual(files.first?.url, url)
                XCTAssertEqual(files.first?.contentType, .plainText)
                expectation.fulfill()
            } onFileUpdate: { files in
                XCTFail("Unexpected deletion event")
            } onFileDeletion: { identifiers in
                XCTFail("Unexpected deletion event")
            }
            try FileManager.default.touch(url: url, atomically: true)
            waitForExpectations(timeout: 5.0)
            scanner.stop()
        }
    }

}
