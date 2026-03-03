import Foundation

enum AppError: LocalizedError, Equatable {
    case cameraUnavailable
    case cameraPermissionDenied
    case photoLibraryPermissionDenied
    case imageEncodeFailed
    case imageDecodeFailed
    case imageLoadFailed
    case fileWriteFailed
    case fileMissing
    case fileDeleteFailed
    case dataStoreSaveFailed
    case invalidSelection
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "当前设备不支持相机。"
        case .cameraPermissionDenied:
            return "未获得相机权限，请前往设置开启。"
        case .photoLibraryPermissionDenied:
            return "未获得相册权限，请前往设置开启。"
        case .imageEncodeFailed:
            return "图片编码失败。"
        case .imageDecodeFailed:
            return "图片解析失败。"
        case .imageLoadFailed:
            return "图片加载失败。"
        case .fileWriteFailed:
            return "文件写入失败。"
        case .fileMissing:
            return "图片文件不存在。"
        case .fileDeleteFailed:
            return "文件删除失败。"
        case .dataStoreSaveFailed:
            return "数据保存失败。"
        case .invalidSelection:
            return "未选择有效图片。"
        case .unknown(let message):
            return message
        }
    }
}
