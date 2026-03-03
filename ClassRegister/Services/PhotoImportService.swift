import Foundation
import ImageIO
import Photos
import PhotosUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct PickedAsset: Identifiable {
    let id = UUID()
    let result: PHPickerResult

    init(result: PHPickerResult) {
        self.result = result
    }
}

struct PendingImport: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ImportResult {
    let savedRecords: [PhotoRecord]
    let pendingImports: [PendingImport]
}

@MainActor
final class PhotoImportService {
    private let modelContext: ModelContext
    private let fileStore: PhotoFileStore

    private static let exifFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()

    private static let exifFormatterWithOffset: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ssXXXXX"
        return formatter
    }()

    init(modelContext: ModelContext, fileStore: PhotoFileStore) {
        self.modelContext = modelContext
        self.fileStore = fileStore
    }

    func importCapturedImage(_ image: UIImage, at date: Date) async throws -> PhotoRecord {
        try persist(image: image, createdAt: date)
    }

    func importLibraryItems(_ items: [PickedAsset]) async throws -> ImportResult {
        var savedRecords: [PhotoRecord] = []
        var pendingImports: [PendingImport] = []

        for item in items {
            let loadedItem = try await loadAsset(from: item.result)
            if let createdAt = loadedItem.createdAt {
                let record = try persist(image: loadedItem.image, createdAt: createdAt)
                savedRecords.append(record)
            } else {
                pendingImports.append(PendingImport(image: loadedItem.image))
            }
        }

        return ImportResult(savedRecords: savedRecords, pendingImports: pendingImports)
    }

    func applyManualDate(_ date: Date, to pending: [PendingImport]) async throws -> [PhotoRecord] {
        var records: [PhotoRecord] = []

        for item in pending {
            let record = try persist(image: item.image, createdAt: date)
            records.append(record)
        }

        return records
    }

    private func persist(image: UIImage, createdAt: Date) throws -> PhotoRecord {
        let fileName = try fileStore.saveJPEG(image)
        let record = PhotoRecord(createdAt: createdAt, fileName: fileName)
        modelContext.insert(record)

        do {
            try modelContext.save()
            return record
        } catch {
            try? fileStore.deleteImage(fileName: fileName)
            throw AppError.dataStoreSaveFailed
        }
    }

    private func loadAsset(from result: PHPickerResult) async throws -> (image: UIImage, createdAt: Date?) {
        let provider = result.itemProvider

        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
            throw AppError.invalidSelection
        }

        let payload = try await loadImagePayload(from: provider)

        let assetDate = fetchAssetCreationDate(for: result.assetIdentifier)
        let exifDate = extractDateFromEXIF(data: payload.data)
        return (payload.image, assetDate ?? exifDate)
    }

    private func loadImagePayload(from provider: NSItemProvider) async throws -> (image: UIImage, data: Data) {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let url else {
                        continuation.resume(throwing: AppError.imageLoadFailed)
                        return
                    }

                    do {
                        let data = try Data(contentsOf: url)
                        guard let image = UIImage(data: data) else {
                            throw AppError.imageDecodeFailed
                        }
                        continuation.resume(returning: (image, data))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            return try await loadImagePayloadByObject(from: provider)
        }
    }

    private func loadImagePayloadByObject(from provider: NSItemProvider) async throws -> (image: UIImage, data: Data) {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let image = object as? UIImage else {
                    continuation.resume(throwing: AppError.imageDecodeFailed)
                    return
                }

                guard let data = image.jpegData(compressionQuality: 1) else {
                    continuation.resume(throwing: AppError.imageEncodeFailed)
                    return
                }

                continuation.resume(returning: (image, data))
            }
        }
    }

    private func fetchAssetCreationDate(for localIdentifier: String?) -> Date? {
        guard let localIdentifier else { return nil }
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        return results.firstObject?.creationDate
    }

    private func extractDateFromEXIF(data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }

        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            if let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                if let offset = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String,
                   let date = Self.exifFormatterWithOffset.date(from: "\(dateString)\(offset)") {
                    return date
                }

                if let date = Self.exifFormatter.date(from: dateString) {
                    return date
                }
            }

            if let dateString = exif[kCGImagePropertyExifDateTimeDigitized] as? String,
               let date = Self.exifFormatter.date(from: dateString) {
                return date
            }
        }

        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let dateString = tiff[kCGImagePropertyTIFFDateTime] as? String,
           let date = Self.exifFormatter.date(from: dateString) {
            return date
        }

        return nil
    }
}
