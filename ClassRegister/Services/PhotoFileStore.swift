import Foundation
import UIKit

final class PhotoFileStore {
    static let shared = PhotoFileStore()

    private let fileManager = FileManager.default
    private let imageCache = NSCache<NSString, UIImage>()
    private let folderName = "ClassRegisterPhotos"

    private init() {}

    private var baseURL: URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory not found.")
        }

        let folderURL = appSupport.appendingPathComponent(folderName, isDirectory: true)
        if !fileManager.fileExists(atPath: folderURL.path) {
            try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        return folderURL
    }

    func fileURL(for fileName: String) -> URL {
        baseURL.appendingPathComponent(fileName)
    }

    func saveImage(_ image: UIImage) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw PhotoFileError.encodingFailed
        }

        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = fileURL(for: fileName)
        try data.write(to: fileURL, options: [.atomic])
        imageCache.setObject(image, forKey: fileName as NSString)
        return fileName
    }

    func loadImage(fileName: String) -> UIImage? {
        if let cached = imageCache.object(forKey: fileName as NSString) {
            return cached
        }

        let fileURL = fileURL(for: fileName)
        guard fileManager.fileExists(atPath: fileURL.path),
              let image = UIImage(contentsOfFile: fileURL.path) else {
            return nil
        }
        imageCache.setObject(image, forKey: fileName as NSString)
        return image
    }

    func deleteImage(fileName: String) throws {
        let fileURL = fileURL(for: fileName)
        imageCache.removeObject(forKey: fileName as NSString)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }
}

enum PhotoFileError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "图片编码失败，无法写入本地存储。"
        }
    }
}
