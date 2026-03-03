import SwiftData
import SwiftUI
import UIKit

@MainActor
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PhotoRecord.createdAt, order: .reverse)
    private var allPhotos: [PhotoRecord]

    @StateObject private var appState = AppState()
    @State private var manualDate = Date()

    private let fileStore = PhotoFileStore.shared
    private let permissionService = PhotoPermissionService.shared

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                content
                floatingCameraButton

                if appState.isBusy {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    ProgressView("处理中...")
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .navigationTitle("ClassRegister")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.activeSheet = .library
                    } label: {
                        Label("导入", systemImage: "photo.on.rectangle")
                    }
                }
            }
        }
        .sheet(item: $appState.activeSheet) { sheet in
            switch sheet {
            case .camera:
                CameraPickerView(
                    onImagePicked: { image in
                        appState.activeSheet = nil
                        Task { await saveCapturedImage(image) }
                    },
                    onCancel: {
                        appState.activeSheet = nil
                    },
                    onError: { error in
                        appState.activeSheet = nil
                        appState.showError(error)
                    }
                )
                .ignoresSafeArea()
            case .library:
                LibraryPickerView(
                    onComplete: { assets in
                        appState.activeSheet = nil
                        Task { await importLibraryAssets(assets) }
                    },
                    onCancel: {
                        appState.activeSheet = nil
                    }
                )
            }
        }
        .sheet(isPresented: $appState.showManualDatePicker) {
            ManualDateSheet(
                manualDate: $manualDate,
                pendingCount: appState.pendingImports.count,
                onCancel: {
                    appState.pendingImports.removeAll()
                    appState.showManualDatePicker = false
                },
                onConfirm: {
                    Task { await applyManualDateToPendingImports() }
                }
            )
            .interactiveDismissDisabled(appState.isBusy)
        }
        .alert(item: $appState.alertContext) { context in
            if context.allowsOpenSettings {
                return Alert(
                    title: Text(context.title),
                    message: Text(context.message),
                    primaryButton: .default(Text("去设置"), action: {
                        permissionService.openSettings()
                    }),
                    secondaryButton: .cancel(Text("取消"))
                )
            }

            return Alert(
                title: Text(context.title),
                message: Text(context.message),
                dismissButton: .default(Text("知道了"))
            )
        }
    }

    private var groupedDays: [DayPhotoGroup] {
        DateGrouping.groupByLocalDay(allPhotos)
    }

    @ViewBuilder
    private var content: some View {
        if groupedDays.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "camera.badge.ellipsis")
                    .font(.system(size: 38))
                    .foregroundStyle(.secondary)
                Text("还没有照片")
                    .font(.headline)
                Text("点击右下角拍照，或右上角导入")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            List {
                ForEach(groupedDays) { dayGroup in
                    NavigationLink {
                        DayDetailView(dayStart: dayGroup.dayStart, dayTitle: dayGroup.displayDate, fileStore: fileStore)
                    } label: {
                        DayGroupRow(group: dayGroup, fileStore: fileStore)
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                }
            }
            .listStyle(.plain)
        }
    }

    private var floatingCameraButton: some View {
        Button {
            Task { await openCameraFlow() }
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
        .accessibilityLabel("拍照")
    }

    private func openCameraFlow() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            let message = AppError.cameraUnavailable.errorDescription ?? "当前设备不支持相机。"
            appState.showMessage(title: "无法拍照", message: message)
            return
        }

        let granted = await permissionService.requestCameraAccess()
        if granted {
            appState.activeSheet = .camera
        } else {
            appState.showSettingsPrompt(
                title: "相机权限受限",
                message: "请前往系统设置，允许 ClassRegister 使用相机。"
            )
        }
    }

    private func saveCapturedImage(_ image: UIImage) async {
        appState.isBusy = true
        defer { appState.isBusy = false }

        do {
            let service = PhotoImportService(modelContext: modelContext, fileStore: fileStore)
            _ = try await service.importCapturedImage(image, at: Date())
        } catch {
            appState.showError(error)
        }
    }

    private func importLibraryAssets(_ assets: [PickedAsset]) async {
        guard !assets.isEmpty else { return }

        appState.isBusy = true
        defer { appState.isBusy = false }

        do {
            let service = PhotoImportService(modelContext: modelContext, fileStore: fileStore)
            let result = try await service.importLibraryItems(assets)
            appState.pendingImports = result.pendingImports
            if !result.pendingImports.isEmpty {
                manualDate = Date()
                appState.showManualDatePicker = true
            }
        } catch {
            appState.showError(error)
        }
    }

    private func applyManualDateToPendingImports() async {
        guard !appState.pendingImports.isEmpty else {
            appState.showManualDatePicker = false
            return
        }

        appState.isBusy = true
        defer { appState.isBusy = false }

        do {
            let service = PhotoImportService(modelContext: modelContext, fileStore: fileStore)
            _ = try await service.applyManualDate(manualDate, to: appState.pendingImports)
            appState.pendingImports.removeAll()
            appState.showManualDatePicker = false
        } catch {
            appState.showError(error)
        }
    }
}

private struct DayGroupRow: View {
    let group: DayPhotoGroup
    let fileStore: PhotoFileStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.displayDate)
                    .font(.headline)
                Text("\(group.records.count) 张")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                ForEach(group.records.prefix(3)) { photo in
                    DayGroupThumb(fileName: photo.fileName, fileStore: fileStore)
                }
            }
        }
    }
}

private struct DayGroupThumb: View {
    let fileName: String
    let fileStore: PhotoFileStore

    var body: some View {
        ZStack {
            if let image = fileStore.loadThumbnail(fileName: fileName, maxPixelSize: 180) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.15)
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ManualDateSheet: View {
    @Binding var manualDate: Date
    let pendingCount: Int
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "日期",
                        selection: $manualDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                } header: {
                    Text("有 \(pendingCount) 张照片缺少拍摄时间")
                } footer: {
                    Text("将统一使用这个日期进行分组。")
                }
            }
            .navigationTitle("补充日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("确定", action: onConfirm)
                }
            }
        }
    }
}
