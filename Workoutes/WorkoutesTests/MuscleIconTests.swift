import SwiftData
import SwiftUI
import XCTest
@testable import Workoutes

@MainActor
final class MuscleIconTests: XCTestCase {
    func testBodySilhouettesAndSoftShadingMatchTheApprovedReference() throws {
        let size = CGSize(width: 310, height: 620)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        func pixels(_ image: UIImage) throws -> [UInt8] {
            let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            var bytes = [UInt8](repeating: 0, count: 310 * 620 * 4)
            try bytes.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 310, height: 620,
                    bitsPerComponent: 8, bytesPerRow: 310 * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(try XCTUnwrap(rendered.cgImage), in: CGRect(origin: .zero, size: size))
            }
            return bytes
        }
        for side in MuscleBodySide.allCases {
            let referenceURL = try XCTUnwrap(Bundle(for: Self.self)
                .url(forResource: "approved-body-\(side.rawValue)", withExtension: "png"))
            let reference = try pixels(XCTUnwrap(UIImage(contentsOfFile: referenceURL.path)))
            let actual = try pixels(XCTUnwrap(UIImage(named: side.asset("base")))
                .withTintColor(.black, renderingMode: .alwaysOriginal))
            var expectedMask = [Bool](repeating: false, count: 310 * 620)
            var actualMask = expectedMask
            var shadeSamples = 0
            var shadeError = 0.0
            for pixel in 0..<(310 * 620) {
                let i = pixel * 4
                let r = Int(reference[i]), g = Int(reference[i+1]), b = Int(reference[i+2])
                expectedMask[pixel] = min(r, g, b) < 239
                actualMask[pixel] = actual[i+3] > 24
                if max(r, g, b) - min(r, g, b) < 8, min(r, g, b) < 235 {
                    let neutral = 255 - Double(actual[i+3]) / 255 * (255 - 0.78 * 255)
                    shadeError += abs(neutral - Double(r + g + b) / 3)
                    shadeSamples += 1
                }
            }
            // One source pixel accounts for antialiasing and the selected 1x/2x/3x raster scale.
            // Both directions are checked: extra anatomy and missing anatomy must fail equally.
            func agreement(_ source: [Bool], _ target: [Bool]) -> Double {
                var count = 0, matched = 0
                for index in source.indices where source[index] {
                    count += 1
                    let x = index % 310, y = index / 310
                    if ((max(0, y-1))...min(619, y+1)).contains(where: { row in
                        ((max(0, x-1))...min(309, x+1)).contains { target[row * 310 + $0] }
                    }) { matched += 1 }
                }
                return Double(matched) / Double(count)
            }
            XCTAssertGreaterThan(agreement(expectedMask, actualMask), 0.99,
                                 "The \(side.rawValue) body must not lose reference details")
            XCTAssertGreaterThan(agreement(actualMask, expectedMask), 0.99,
                                 "The \(side.rawValue) body must not introduce different shapes")
            XCTAssertLessThan(shadeError / Double(shadeSamples), 8,
                              "The original soft shading must survive tinting")
        }
    }

    private func container() throws -> ModelContainer {
        try ModelContainer(for: Workout.self, Tag.self, WorkoutExercise.self, ExerciseSession.self, ExerciseCompletion.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testIconAndColorPersistAndRoundTripIncludingUnknownFutureIcons() throws {
        let source = try container()
        let context = source.mainContext
        let originals = [Tag(name: "Chest", colorHex: "326884", iconName: "chest"),
                         Tag(name: "Legs", colorHex: "B15D78", iconName: "lowerBody"),
                         Tag(name: "Strength", colorHex: "8064B5"),
                         Tag(name: "Future", colorHex: "228844", iconName: "future-muscle")]
            + MuscleIcon.allCases.map { Tag(name: "Existing-\($0.rawValue)", colorHex: "4488CC", iconName: $0.rawValue) }
        for tag in originals { context.insert(tag) }
        try context.save()
        let reloaded = ModelContext(source)
        let saved = try reloaded.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(saved.first { $0.name == "Chest" }?.muscleIcon, .chest)
        XCTAssertEqual(saved.first { $0.name == "Legs" }?.iconName, "lowerBody")
        XCTAssertNil(saved.first { $0.name == "Strength" }?.muscleIcon)
        XCTAssertNil(saved.first { $0.name == "Future" }?.muscleIcon)

        let backup = try DataBackup.export(from: context, includeHistory: true)
        let destination = try container()
        try DataBackup.importData(backup, into: destination.mainContext)
        try DataBackup.importData(backup, into: destination.mainContext)
        let imported = try destination.mainContext.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(imported.count, originals.count)
        for original in originals {
            let tag = try XCTUnwrap(imported.first { $0.stableID == original.stableID })
            XCTAssertEqual(tag.colorHex, original.colorHex)
            XCTAssertEqual(tag.iconName, original.iconName)
            XCTAssertEqual(tag.muscleIcon, original.muscleIcon)
        }
    }

    func testOldBackupWithoutIconsStillImportsAndAllowsRemovingAnIcon() throws {
        let store = try container()
        let tag = Tag(name: "Chest", colorHex: "FF0000", iconName: "chest")
        tag.stableID = "tag"
        store.mainContext.insert(tag)
        try store.mainContext.save()
        let backup = Data("""
        {"workouts":[],"exercises":[],"tags":[{"id":"tag","name":"Chest","colorHex":"5599FF"}]}
        """.utf8)
        try DataBackup.importData(backup, into: store.mainContext)
        XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<Tag>()), 1)
        XCTAssertNil(tag.iconName)
        XCTAssertNil(tag.muscleIcon)
        XCTAssertEqual(tag.colorHex, "5599FF")
    }

    func testAllIconsHaveBothAssetsAndTheirHighlightsFollowTheTagColor() throws {
        for icon in MuscleIcon.allCases {
            XCTAssertNotNil(UIImage(named: icon.baseAsset), icon.rawValue)
            XCTAssertNotNil(UIImage(named: icon.highlightAsset), icon.rawValue)
            func render(_ color: Color) throws -> Data {
                let renderer = ImageRenderer(content: MuscleIconView(icon: icon, color: color)
                    .frame(width: 32, height: 32).background(.white))
                return try XCTUnwrap(renderer.uiImage?.pngData())
            }
            XCTAssertNotEqual(try render(.red), try render(.blue), "The highlight must be visible and tintable: \(icon.rawValue)")
        }
    }

    func testTagChipsAndPickerRenderInLightAndDarkMode() async throws {
        let store = try container()
        let tags = [Tag(name: "Chest", colorHex: "326884", iconName: "chest"),
                    Tag(name: "Shoulders", colorHex: "8064B5", iconName: "shoulders"),
                    Tag(name: "Legs", colorHex: "B15D78", iconName: "lowerBody")]
        for tag in tags { store.mainContext.insert(tag) }
        try store.mainContext.save()
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: VStack(alignment: .leading, spacing: 12) {
                ForEach(tags) { tag in
                    HStack {
                        TagSelectionLabel(tag: tag, isSelected: false)
                        TagSelectionLabel(tag: tag, isSelected: true)
                    }
                }
            }.padding(16).frame(width: 398).background(DefaultScreenBackground()).environment(\.colorScheme, scheme))
            renderer.scale = 3
            let data = try XCTUnwrap(renderer.uiImage?.pngData())
            try data.write(to: URL(fileURLWithPath: "/tmp/workoutes-muscle-tags-\(scheme == .dark ? "dark" : "light").png"))
        }

        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let views: [(String, AnyView)] = [
            ("editor", AnyView(ManageTagSheet(editingTag: tags[0]).modelContainer(store))),
            ("picker", AnyView(NavigationStack { MuscleIconPicker(selection: .constant(.chest), color: Color(hex: tags[0].colorHex)) }))
        ]
        for (name, view) in views {
            window.rootViewController = UIHostingController(rootView: view)
            window.overrideUserInterfaceStyle = .light
            try await Task.sleep(for: .milliseconds(350))
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-muscle-\(name).png"))
        }

        // Review the expanded native control, including its compact fallback and custom picker.
        for (name, scheme, width) in [("light", ColorScheme.light, CGFloat(430)),
                                      ("dark", .dark, 430), ("compact", .light, 320)] {
            window.rootViewController = UIHostingController(rootView: NavigationStack {
                Form {
                    Section("Tag Details") {
                        TextField("Name", text: .constant("Pecho"))
                        TagColorPicker(selection: .constant(.suggested(.blue)), isExpanded: .constant(true))
                    }
                }
                .transparentNavigationChrome()
                .navigationTitle("New Tag")
                .navigationBarTitleDisplayMode(.inline)
            }
            .frame(width: width)
            .environment(\.dynamicTypeSize, .large))
            window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
            try await Task.sleep(for: .milliseconds(200))
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: "/tmp/workoutes-tag-colors-\(name).png"))
        }
    }
}
