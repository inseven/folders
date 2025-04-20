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

//struct ColorKey: Hashable {
//    let red: CGFloat
//    let green: CGFloat
//    let blue: CGFloat
//    let alpha: CGFloat
//
//    init(color: NSColor) {
//        let rgb = color.usingColorSpace(.deviceRGB) ?? NSColor.black
//        red = rgb.redComponent
//        green = rgb.greenComponent
//        blue = rgb.blueComponent
//        alpha = rgb.alphaComponent
//    }
//
//    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
//        self.red = red
//        self.green = green
//        self.blue = blue
//        self.alpha = alpha
//    }
//}

struct ColorKey: Hashable {
    let hex: String

    init(color: NSColor) {
        let rgb = color.usingColorSpace(.deviceRGB) ?? .black
        let r = UInt8(clamping: Int(round(rgb.redComponent * 255)))
        let g = UInt8(clamping: Int(round(rgb.greenComponent * 255)))
        let b = UInt8(clamping: Int(round(rgb.blueComponent * 255)))
        let a = UInt8(clamping: Int(round(rgb.alphaComponent * 255)))
        self.hex = String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }
}

struct Sidebar: View {

    @ObservedObject var applicationModel: ApplicationModel
    @ObservedObject var sceneModel: SceneModel

    // TODO: Cache this and observe notifications in the application model.
    func color(for name: String) -> Color? {

        let mapping: [String: Color] = [
//            ColorKey(red: 0.40544259548187256, green: 0.6989939212799072, blue: 0.9979338049888611, alpha: 1.0): Color.orange,
//            ColorKey(red: 0.7479531168937683, green: 0.8542190194129944, blue: 0.3323848843574524, alpha: 1.0): Color.green,
//            ColorKey(red: 0.7960518002510071, green: 0.6305387020111084, blue: 0.8742266297340393, alpha: 1.0): Color.purple,
                                        "#67B2FEFF": .red,
        ]

        print("Tags = \(NSWorkspace.shared.fileLabels)")

        // Curiously, but perhaps unsurprisingly, this API isn't giving us the color palette Finder is using.
        // To correct for this, we try mapping the colors to the new SwiftUI palette. It's a gross hack.
        let tags = zip(NSWorkspace.shared.fileLabels, NSWorkspace.shared.fileLabelColors)
            .reduce(into: [String: Color]()) { partialResult, details in
                print("\(details.0) -> \(details.1), \(ColorKey(color: details.1))")
                partialResult[details.0] = mapping[ColorKey(color: details.1).hex] ?? Color(nsColor: details.1)
            }
        let color = tags[name]
        return color
    }

    var body: some View {
        List(selection: $sceneModel.selection) {
            Section("Library") {
                OutlineGroup(applicationModel.dynamicSidebarItems, children: \.children) { item in
                    Label(item.kind.displayName, systemImage: item.kind.systemImage)
                        .contextMenu {
                            Button {
                                sceneModel.reveal(item)
                            } label: {
                                Text("Reveal in Finder")
                            }
                            if case .owner = item.kind {
                                Divider()
                                Button(role: .destructive) {
                                    sceneModel.remove(item)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            if !applicationModel.finderTags.isEmpty {
                Section("Finder Tags") {
                    ForEach(applicationModel.finderTags, id: \.self) { tag in
                        Label(tag.name, systemImage: "circle.fill")
                            .tag(SidebarItem.Kind.tag(tag))
                            .accentColor(color(for: tag.name))
                    }
                }
            }
            if !applicationModel.tags.isEmpty {
                Section("Tags") {
                    ForEach(applicationModel.tags, id: \.self) { tag in
                        Label(tag.name, systemImage: "tag")
                            .tag(SidebarItem.Kind.tag(tag))
                    }
                }
            }
        }
    }

}
