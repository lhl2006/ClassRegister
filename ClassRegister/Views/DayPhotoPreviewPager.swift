import SwiftData
import SwiftUI
import UIKit

struct DayPhotoPreviewPager: View {
    let dayStart: Date
    let initialPhotoID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhotoRecord.createdAt, order: .forward) private var allRecords: [PhotoRecord]

    @State private var selectedID: UUID
    @State private var alertItem: PreviewAlertItem?
    @State private var showDeleteDialog = false

    init(dayStart: Date, initialPhotoID: UUID) {
        self.dayStart = dayStart
        self.initialPhotoID = initialPhotoID
        _selectedID = State(initialValue: initialPhotoID)
    }

    private var dayRecords: [PhotoRecord] {
        let interval = DayGrouper.dayInterval(for: dayStart)
        return allRecords.filter { interval.contains($0.createdAt) }
    }

    private var dayRecordIDs: [UUID] {
        dayRecords.map(\.id)
    }

    private var currentRecord: PhotoRecord? {
        dayRecords.first(where: { $0.id == selectedID })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if dayRecords.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.72))
                        Text("当天没有照片")
                            .foregroundStyle(.white.opacity(0.86))
                    }
                } else {
                    TabView(selection: $selectedID) {
                        ForEach(dayRecords, id: \.id) { record in
                            Group {
                                if let image = PhotoFileStore.shared.loadImage(fileName: record.fileName) {
                                    ZoomableImageView(image: image)
                                } else {
                                    VStack(spacing: 12) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.system(size: 32))
                                        Text("图片加载失败")
                                    }
                                    .foregroundStyle(.white.opacity(0.85))
                                }
                            }
                            .tag(record.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .tint(.white)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        saveCurrentPhotoToLibrary()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .tint(.white)
                    .disabled(currentRecord == nil)

                    Button(role: .destructive) {
                        showDeleteDialog = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(.red)
                    .disabled(currentRecord == nil)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.black.opacity(0.25), for: .navigationBar)
        .confirmationDialog("确认删除这张照片？", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                deleteCurrentPhoto()
            }
            Button("取消", role: .cancel) {}
        }
        .alert(item: $alertItem) { item in
            if item.offerSettings {
                Alert(
                    title: Text(item.title),
                    message: Text(item.message),
                    primaryButton: .default(Text("去设置"), action: openSettings),
                    secondaryButton: .cancel(Text("取消"))
                )
            } else {
                Alert(
                    title: Text(item.title),
                    message: Text(item.message),
                    dismissButton: .default(Text("知道了"))
                )
            }
        }
        .onAppear {
            reconcileSelection()
        }
        .onChange(of: dayRecordIDs) { _, _ in
            reconcileSelection()
        }
    }

    private func reconcileSelection() {
        guard !dayRecords.isEmpty else {
            dismiss()
            return
        }
        if !dayRecordIDs.contains(selectedID), let first = dayRecordIDs.first {
            selectedID = first
        }
    }

    private func saveCurrentPhotoToLibrary() {
        guard let record = currentRecord,
              let image = PhotoFileStore.shared.loadImage(fileName: record.fileName) else {
            alertItem = PreviewAlertItem(title: "保存失败", message: "无法读取当前图片。")
            return
        }

        PhotoLibraryService.shared.saveImageToLibrary(image) { result in
            switch result {
            case .success:
                alertItem = PreviewAlertItem(title: "已保存", message: "图片已保存到系统相册。")
            case .failure(let error):
                if let libraryError = error as? PhotoLibraryError, libraryError == .permissionDenied {
                    alertItem = PreviewAlertItem(
                        title: "没有相册权限",
                        message: libraryError.localizedDescription,
                        offerSettings: true
                    )
                } else {
                    alertItem = PreviewAlertItem(title: "保存失败", message: error.localizedDescription)
                }
            }
        }
    }

    private func deleteCurrentPhoto() {
        guard let currentRecord,
              let currentIndex = dayRecordIDs.firstIndex(of: currentRecord.id) else {
            return
        }

        let remainingIDs = dayRecordIDs.filter { $0 != currentRecord.id }

        modelContext.delete(currentRecord)

        do {
            try modelContext.save()
        } catch {
            alertItem = PreviewAlertItem(title: "删除失败", message: error.localizedDescription)
            return
        }

        do {
            try PhotoFileStore.shared.deleteImage(fileName: currentRecord.fileName)
        } catch {
            alertItem = PreviewAlertItem(title: "文件删除失败", message: error.localizedDescription)
        }

        if remainingIDs.isEmpty {
            dismiss()
        } else {
            let fallbackIndex = min(currentIndex, remainingIDs.count - 1)
            selectedID = remainingIDs[fallbackIndex]
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct PreviewAlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var offerSettings: Bool = false
}
