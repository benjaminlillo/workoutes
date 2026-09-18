import Foundation
import ImageIO
import Observation
import UIKit

@MainActor
@Observable
final class ExerciseBackgroundStore {
    private(set) var image: UIImage?
    private(set) var gradientColors: [String] = []
    private let fileURL: URL
    private let colorsURL: URL

    init(directory: URL = URL.applicationSupportDirectory, identifier: String = "exercise-background") {
        fileURL = directory.appendingPathComponent(identifier + ".jpg")
        colorsURL = directory.appendingPathComponent(identifier + ".json")
        image = UIImage(contentsOfFile: fileURL.path)
        if let data = try? Data(contentsOf: colorsURL),
           let colors = try? JSONDecoder().decode([String].self, from: data) {
            gradientColors = Array(colors.prefix(3))
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
        image = savedImage
        gradientColors = []
    }

    func saveGradient(colors: [String]) throws {
        guard (1...3).contains(colors.count) else { throw BackgroundError.invalidColors }
        try persistColors(colors)
        gradientColors = colors
    }

    private func persistColors(_ colors: [String]) throws {
        try FileManager.default.createDirectory(at: colorsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(colors).write(to: colorsURL, options: .atomic)
    }

    func remove() throws {
        try persistColors([])
        gradientColors = []
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
