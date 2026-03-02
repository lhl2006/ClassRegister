import Foundation
import Photos
import UIKit

final class PhotoLibraryService {
    static let shared = PhotoLibraryService()

    private init() {}

    func saveImageToLibrary(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            performSave(image, completion: completion)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self.performSave(image, completion: completion)
                    } else {
                        completion(.failure(PhotoLibraryError.permissionDenied))
                    }
                }
            }
        case .denied, .restricted:
            completion(.failure(PhotoLibraryError.permissionDenied))
        @unknown default:
            completion(.failure(PhotoLibraryError.unknown))
        }
    }

    private func performSave(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else {
                    completion(.failure(error ?? PhotoLibraryError.saveFailed))
                }
            }
        })
    }
}

enum PhotoLibraryError: LocalizedError, Equatable {
    case permissionDenied
    case saveFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "没有系统相册写入权限，请在设置中允许添加照片。"
        case .saveFailed:
            return "保存到系统相册失败。"
        case .unknown:
            return "发生未知错误。"
        }
    }
}
