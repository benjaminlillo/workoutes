import Foundation
import ImageIO
import Observation
import UIKit

@MainActor
@Observable
final class ExerciseBackgroundStore {
    private(set) var image: UIImage?
    private let fileURL: URL

    init(directory: URL = URL.applicationSupportDirectory) {
        fileURL = directory.appendingPathComponent("exercise-background.jpg")
        image = UIImage(contentsOfFile: fileURL.path)
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
        image = savedImage
    }

    func remove() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        image = nil
    }

    enum BackgroundError: LocalizedError {
        case invalidImage
        var errorDescription: String? { "This image couldn't be loaded. Please choose another photo." }
    }
}
