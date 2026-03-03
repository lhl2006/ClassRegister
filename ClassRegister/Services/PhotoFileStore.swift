import Foundation
import ImageIO
import UIKit

final class PhotoFileStore {
    static let shared = PhotoFileStore()

    private let fileManager: FileManager
    private let baseDirectoryName = "ClassRegisterPhotos"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func saveJPEG(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw AppError.imageEncodeFailed
        }

        let fileName = "\(UUID().uuidString).jpg"
        let url = try fileURL(for: fileName)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw AppError.fileWriteFailed
        }

        return fileName
    }

    func loadImage(fileName: String) -> UIImage? {
        guard let url = try? fileURL(for: fileName) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func loadThumbnail(fileName: String, maxPixelSize: Int = 320) -> UIImage? {
        guard let url = try? fileURL(for: fileName) else { return nil }
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    func deleteImage(fileName: String) throws {
        let url = try fileURL(for: fileName)
        if !fileManager.fileExists(atPath: url.path) {
            throw AppError.fileMissing
        }

        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw AppError.fileDeleteFailed
        }
    }

    func imageURL(fileName: String) throws -> URL {
        try fileURL(for: fileName)
    }

    private func fileURL(for fileName: String) throws -> URL {
        try ensureBaseDirectory()
        return applicationSupportDirectory().appendingPathComponent(baseDirectoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    private func ensureBaseDirectory() throws {
        let directory = applicationSupportDirectory().appendingPathComponent(baseDirectoryName, isDirectory: true)
        if fileManager.fileExists(atPath: directory.path) { return }

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw AppError.fileWriteFailed
        }
    }

    private func applicationSupportDirectory() -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
}
