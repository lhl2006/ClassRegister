import Photos
import UIKit

@MainActor
final class SystemAlbumService {
    static let shared = SystemAlbumService(permissionService: .shared)

    private let permissionService: PhotoPermissionService

    private init(permissionService: PhotoPermissionService) {
        self.permissionService = permissionService
    }

    func saveToPhotoLibrary(_ image: UIImage) async throws {
        let hasPermission = await permissionService.requestPhotoLibraryAddAccess()
        guard hasPermission else {
            throw AppError.photoLibraryPermissionDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }, completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: AppError.unknown("保存到系统相册失败。"))
                }
            })
        }
    }
}
