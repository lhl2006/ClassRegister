import SwiftData
import SwiftUI

struct DayPhotosView: View {
    let dayStart: Date

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhotoRecord.createdAt, order: .reverse) private var allRecords: [PhotoRecord]

    @State private var previewSelection: PreviewSelection?
    @State private var deleteCandidate: PhotoRecord?
    @State private var deleteErrorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    private var dayRecords: [PhotoRecord] {
        let interval = DayGrouper.dayInterval(for: dayStart)
        return allRecords.filter { interval.contains($0.createdAt) }
    }

    var body: some View {
        ScrollView {
            if dayRecords.isEmpty {
                ContentUnavailableView("当天没有照片", systemImage: "photo.on.rectangle")
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(dayRecords, id: \.id) { record in
                        Button {
                            previewSelection = PreviewSelection(id: record.id)
                        } label: {
                            PhotoThumbnailView(fileName: record.fileName)
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("删除", role: .destructive) {
                                deleteCandidate = record
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
        .navigationTitle(DayGrouper.displayString(for: dayStart))
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $previewSelection) { selection in
            DayPhotoPreviewPager(dayStart: dayStart, initialPhotoID: selection.id)
        }
        .confirmationDialog(
            "确认删除这张照片？",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { visible in
                    if !visible {
                        deleteCandidate = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let deleteCandidate {
                    delete(deleteCandidate)
                }
                self.deleteCandidate = nil
            }
            Button("取消", role: .cancel) {
                deleteCandidate = nil
            }
        }
        .alert(
            "删除失败",
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { visible in
                    if !visible {
                        deleteErrorMessage = nil
                    }
                }
            )
        ) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    private func delete(_ record: PhotoRecord) {
        modelContext.delete(record)

        do {
            try modelContext.save()
        } catch {
            deleteErrorMessage = error.localizedDescription
            return
        }

        do {
            try PhotoFileStore.shared.deleteImage(fileName: record.fileName)
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
    }
}

private struct PreviewSelection: Identifiable {
    let id: UUID
}
