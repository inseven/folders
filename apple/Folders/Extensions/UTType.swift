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
import UniformTypeIdentifiers

extension UTType {

    static var cbr: Self {
        return UTType(filenameExtension: "cbr")!
    }

    static var cbz: Self {
        return UTType(filenameExtension: "cbz")!
    }

    static var m4v: Self {
        return UTType(filenameExtension: "m4v")!
    }

    static var mkv: Self {
        return UTType(filenameExtension: "mkv")!
    }

    static var mov: Self {
        return UTType(filenameExtension: "mov")!
    }

    static var pbm: Self {
        return UTType(filenameExtension: "pbm")!
    }

    static var stl: Self {
        return UTType(filenameExtension: "stl")!
    }

    static var tap: Self {
        return UTType(filenameExtension: "tap")!
    }

}
