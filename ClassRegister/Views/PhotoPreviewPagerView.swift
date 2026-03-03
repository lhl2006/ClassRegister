import SwiftUI

@MainActor
struct PhotoPreviewPagerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var items: [PhotoSnapshot]
    @State private var selectedIndex: Int
    @State private var isWorking = false
    @State private var showDeleteConfirmation = false
    @State private var alertContext: AppState.AlertContext?

    private let fileStore: PhotoFileStore
    private let albumService: SystemAlbumService
    private let permissionService: PhotoPermissionService
    private let onDelete: (UUID) -> Void

    init(
        photos: [PhotoSnapshot],
        initialIndex: Int,
        fileStore: PhotoFileStore,
        albumService: SystemAlbumService,
        permissionService: PhotoPermissionService,
        onDelete: @escaping (UUID) -> Void
    ) {
        _items = State(initialValue: photos)
        let safeInitial: Int
        if photos.isEmpty {
            safeInitial = 0
        } else {
            safeInitial = min(max(0, initialIndex), photos.count - 1)
        }
        _selectedIndex = State(initialValue: safeInitial)
        self.fileStore = fileStore
        self.albumService = albumService
        self.permissionService = permissionService
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if !items.isEmpty {
                    TabView(selection: $selectedIndex) {
                        ForEach(items.indices, id: \.self) { index in
                            PreviewPage(fileName: items[index].fileName, fileStore: fileStore)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .background(Color.black)
                }

                if isWorking {
                    ProgressView("处理中...")
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .tint(.white)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task { await saveCurrentPhotoToLibrary() }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .tint(.white)
                    .disabled(currentPhoto == nil)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(.white)
                    .disabled(currentPhoto == nil)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .confirmationDialog("确认删除当前照片？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    deleteCurrentPhoto()
                }
                Button("取消", role: .cancel) {}
            }
            .alert(item: $alertContext) { context in
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
            .onAppear {
                if items.isEmpty {
                    dismiss()
                }
            }
        }
        .statusBarHidden(false)
    }

    private var currentPhoto: PhotoSnapshot? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }

    private func saveCurrentPhotoToLibrary() async {
        guard let currentPhoto,
              let image = fileStore.loadImage(fileName: currentPhoto.fileName) else {
            alertContext = AppState.AlertContext(
                title: "保存失败",
                message: "当前图片不存在或读取失败。",
                allowsOpenSettings: false
            )
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            try await albumService.saveToPhotoLibrary(image)
            alertContext = AppState.AlertContext(
                title: "已保存",
                message: "图片已保存到系统相册。",
                allowsOpenSettings: false
            )
        } catch AppError.photoLibraryPermissionDenied {
            alertContext = AppState.AlertContext(
                title: "相册权限受限",
                message: "请前往系统设置允许写入相册。",
                allowsOpenSettings: true
            )
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            alertContext = AppState.AlertContext(
                title: "保存失败",
                message: message,
                allowsOpenSettings: false
            )
        }
    }

    private func deleteCurrentPhoto() {
        guard let currentPhoto else { return }

        let deletedID = currentPhoto.id
        onDelete(deletedID)
        items.removeAll { $0.id == deletedID }

        if items.isEmpty {
            dismiss()
            return
        }

        if selectedIndex >= items.count {
            selectedIndex = items.count - 1
        }
    }
}

private struct PreviewPage: View {
    let fileName: String
    let fileStore: PhotoFileStore

    var body: some View {
        Group {
            if let image = fileStore.loadImage(fileName: fileName) {
                ZoomableImageView(image: image)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                    Text("图片加载失败")
                }
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
