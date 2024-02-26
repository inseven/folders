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

import Diligence
import Interact

@main
struct FoldersApp: App {

    let applicationModel: ApplicationModel

    init() {
        self.applicationModel = ApplicationModel()
        self.applicationModel.start()
    }

    var body: some Scene {

        WindowGroup {
            LibraryView(applicationModel: applicationModel)
                .environmentObject(applicationModel)
        }

        let subject = "Folders Support (\(Bundle.main.version ?? "Unknown Version"))"

        About(repository: "inseven/folders", copyright: "Copyright © 2023-2024 Jason Morley") {
            Action("GitHub", url: URL(string: "https://github.com/inseven/folders")!)
            Action("Support", url: URL(address: "support@jbmorley.co.uk", subject: subject)!)
        } acknowledgements: {
            Acknowledgements("Developers") {
                Credit("Jason Morley", url: URL(string: "https://jbmorley.co.uk"))
            }
            Acknowledgements("Thanks") {
                Credit("Lukas Fittl")
                Credit("Pavlos Vinieratos")
                Credit("Sarah Barbour")
            }
        } licenses: {
            .interact
            License("Folders",
                    author: "Jason Morley",
                    filename: "folders-license")
            License("FSEventsWrapper",
                    author: "François Lamboley",
                    filename: "fs-events-wrapper-license")
            License("SQLite.swift",
                    author: "Stephen Celis",
                    filename: "sqlite-swift-license")
            License("Swift Algorithms",
                    author: "Apple Inc. and the Swift Project Authors",
                    filename: "swift-algorithms-license")
            License("Swift Collections",
                    author: "Apple Inc. and the Swift Project Authors",
                    filename: "swift-collections-license")
            License("Swift Numerics",
                    author: "Apple Inc. and the Swift Numerics Project Authors",
                    filename: "swift-numerics-license")
            License("Yams",
                    author: "JP Simard",
                    filename: "yams-license")
        }

    }
}
