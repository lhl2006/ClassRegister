import SwiftData
import SwiftUI

@MainActor
struct DayDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var dayPhotos: [PhotoRecord]

    @State private var previewPresentation: PreviewPresentation?
    @State private var alertContext: AppState.AlertContext?

    private let dayTitle: String
    private let fileStore: PhotoFileStore

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    init(dayStart: Date, dayTitle: String, fileStore: PhotoFileStore) {
        self.dayTitle = dayTitle
        self.fileStore = fileStore

        let start = dayStart
        let end = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)

        _dayPhotos = Query(
            filter: #Predicate<PhotoRecord> { record in
                record.createdAt >= start && record.createdAt < end
            },
            sort: \PhotoRecord.createdAt,
            order: .reverse
        )
    }

    var body: some View {
        ScrollView {
            if dayPhotos.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(dayPhotos) { photo in
                        Button {
                            openPreview(for: photo)
                        } label: {
                            DayPhotoCell(fileName: photo.fileName, fileStore: fileStore)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                delete(photo)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(dayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $alertContext) { context in
            Alert(
                title: Text(context.title),
                message: Text(context.message),
                dismissButton: .default(Text("知道了"))
            )
        }
        .fullScreenCover(item: $previewPresentation) { presentation in
            PhotoPreviewPagerView(
                photos: presentation.photos,
                initialIndex: presentation.initialIndex,
                fileStore: fileStore,
                albumService: .shared,
                permissionService: .shared,
                onDelete: { id in
                    deleteByID(id)
                }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("当天暂无照片")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }

    private func openPreview(for photo: PhotoRecord) {
        let snapshots = dayPhotos.map { record in
            PhotoSnapshot(id: record.id, createdAt: record.createdAt, fileName: record.fileName)
        }
        guard !snapshots.isEmpty,
              let index = snapshots.firstIndex(where: { $0.id == photo.id }) else { return }
        previewPresentation = PreviewPresentation(photos: snapshots, initialIndex: index)
    }

    private func deleteByID(_ id: UUID) {
        guard let target = dayPhotos.first(where: { $0.id == id }) else { return }
        delete(target)
    }

    private func delete(_ photo: PhotoRecord) {
        var warningMessage: String?

        do {
            try fileStore.deleteImage(fileName: photo.fileName)
        } catch {
            if let appError = error as? AppError, appError == .fileMissing {
                warningMessage = "原文件不存在，已仅删除本地索引。"
            } else {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                alertContext = AppState.AlertContext(
                    title: "删除失败",
                    message: message,
                    allowsOpenSettings: false
                )
                return
            }
        }

        modelContext.delete(photo)

        do {
            try modelContext.save()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            alertContext = AppState.AlertContext(
                title: "删除失败",
                message: message,
                allowsOpenSettings: false
            )
            return
        }

        if let warningMessage {
            alertContext = AppState.AlertContext(
                title: "删除完成",
                message: warningMessage,
                allowsOpenSettings: false
            )
        }
    }
}

private struct PreviewPresentation: Identifiable {
    let id = UUID()
    let photos: [PhotoSnapshot]
    let initialIndex: Int
}

private struct DayPhotoCell: View {
    let fileName: String
    let fileStore: PhotoFileStore

    var body: some View {
        ZStack {
            if let image = fileStore.loadThumbnail(fileName: fileName, maxPixelSize: 360) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.18)
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 110)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
