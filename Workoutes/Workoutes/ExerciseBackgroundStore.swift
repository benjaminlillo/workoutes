import Foundation
import ImageIO
import Observation
import UIKit

@MainActor
@Observable
final class ExerciseBackgroundStore {
    static let defaultGradientColors = ["B8D8F8", "D8C3F0"]
    private(set) var image: UIImage?
    private(set) var gradientColors: [String] = []
    private(set) var usesAutomaticGradient = false
    private let fileURL: URL
    private let colorsURL: URL
    private let automaticURL: URL

    init(directory: URL = URL.applicationSupportDirectory, identifier: String = "exercise-background") {
        fileURL = directory.appendingPathComponent(identifier + ".jpg")
        colorsURL = directory.appendingPathComponent(identifier + ".json")
        automaticURL = directory.appendingPathComponent(identifier + "-automatic.json")
        if let data = try? Data(contentsOf: automaticURL) {
            usesAutomaticGradient = (try? JSONDecoder().decode(Bool.self, from: data)) ?? false
        }
        image = UIImage(contentsOfFile: fileURL.path)
        if let data = try? Data(contentsOf: colorsURL),
           let colors = try? JSONDecoder().decode([String].self, from: data) {
            gradientColors = Array(colors.prefix(3))
        }
        if image == nil && gradientColors.isEmpty {
            gradientColors = Self.defaultGradientColors
        }
    }

    func save(data: Data) throws {
        // Downsample before decoding a full-resolution photo, and honor EXIF orientation.
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048
              ] as CFDictionary),
              let jpeg = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.85),
              let savedImage = UIImage(data: jpeg) else {
            throw BackgroundError.invalidImage
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try jpeg.write(to: fileURL, options: .atomic)
        try persistColors([])
        try setAutomaticGradient(false)
        image = savedImage
        gradientColors = []
    }

    func saveGradient(colors: [String]) throws {
        guard (1...3).contains(colors.count) else { throw BackgroundError.invalidColors }
        try persistColors(colors)
        try setAutomaticGradient(false)
        gradientColors = colors
    }

    func useWallpaper() throws {
        guard image != nil else { return }
        try persistColors([])
        try setAutomaticGradient(false)
        gradientColors = []
    }

    func setAutomaticGradient(_ enabled: Bool = true) throws {
        try FileManager.default.createDirectory(at: automaticURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(enabled).write(to: automaticURL, options: .atomic)
        usesAutomaticGradient = enabled
    }

    static func automaticColors(from tagColors: [String]) -> [String] {
        tagColors.isEmpty ? defaultGradientColors : tagColors
    }

    private func persistColors(_ colors: [String]) throws {
        try FileManager.default.createDirectory(at: colorsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(colors).write(to: colorsURL, options: .atomic)
    }

    func remove() throws {
        try persistColors(Self.defaultGradientColors)
        try setAutomaticGradient(false)
        gradientColors = Self.defaultGradientColors
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        image = nil
    }

    enum BackgroundError: LocalizedError {
        case invalidImage
        case invalidColors
        var errorDescription: String? {
            switch self {
            case .invalidImage: "This image couldn't be loaded. Please choose another photo."
            case .invalidColors: "Choose between one and three colors."
            }
        }
    }
}
