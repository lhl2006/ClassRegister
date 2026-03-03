import Foundation
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum ActiveSheet: Identifiable {
        case camera
        case library

        var id: String {
            switch self {
            case .camera: return "camera"
            case .library: return "library"
            }
        }
    }

    struct AlertContext: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let allowsOpenSettings: Bool
    }

    @Published var activeSheet: ActiveSheet?
    @Published var alertContext: AlertContext?
    @Published var isBusy = false
    @Published var pendingImports: [PendingImport] = []
    @Published var showManualDatePicker = false

    func showError(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        alertContext = AlertContext(title: "操作失败", message: message, allowsOpenSettings: false)
    }

    func showMessage(title: String, message: String) {
        alertContext = AlertContext(title: title, message: message, allowsOpenSettings: false)
    }

    func showSettingsPrompt(title: String, message: String) {
        alertContext = AlertContext(title: title, message: message, allowsOpenSettings: true)
    }
}
