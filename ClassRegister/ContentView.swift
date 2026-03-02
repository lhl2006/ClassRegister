//
//  ContentView.swift
//  ClassRegister
//
//  Created by lhl on 2026/3/2.
//

import AVFoundation
import Photos
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhotoRecord.createdAt, order: .reverse) private var records: [PhotoRecord]

    @State private var showCamera = false
    @State private var alertItem: ContentAlertItem?
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var isImporting = false

    private var dayGroups: [DayGroup] {
        let grouped = Dictionary(grouping: records) { DayGrouper.startOfDay(for: $0.createdAt) }
        return grouped
            .map { dayStart, items in
                DayGroup(
                    dayStart: dayStart,
                    records: items.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { $0.dayStart > $1.dayStart }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if dayGroups.isEmpty {
                        ContentUnavailableView(
                            "还没有照片",
                            systemImage: "camera",
                            description: Text("点击右下角“拍照”开始记录。")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                ForEach(dayGroups) { group in
                                    NavigationLink {
                                        DayPhotosView(dayStart: group.dayStart)
                                    } label: {
                                        DayGroupCardView(group: group)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 100)
                        }
                    }
                }

                captureButton
            }
            .navigationTitle("ClassRegister")
        }
        .overlay {
            if isImporting {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView("正在导入照片...")
                        .padding(16)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPickerView(
                onImagePicked: { image in
                    showCamera = false
                    saveCapturedImage(image)
                },
                onCancel: {
                    showCamera = false
                    alertItem = ContentAlertItem(title: "已取消", message: "你已取消本次拍照。")
                }
            )
            .ignoresSafeArea()
        }
        .onChange(of: selectedPickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await importFromPhotoLibrary(newItems)
            }
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
    }

    private var captureButton: some View {
        VStack(alignment: .trailing, spacing: 12) {
            PhotosPicker(
                selection: $selectedPickerItems,
                maxSelectionCount: nil,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("从相册添加", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }

            Button(action: openCamera) {
                Label("拍照", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            alertItem = ContentAlertItem(title: "无法使用相机", message: "当前设备不支持拍照。")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    } else {
                        alertItem = ContentAlertItem(
                            title: "相机权限被拒绝",
                            message: "请在系统设置中开启相机权限后重试。",
                            offerSettings: true
                        )
                    }
                }
            }
        case .denied, .restricted:
            alertItem = ContentAlertItem(
                title: "相机权限被拒绝",
                message: "请在系统设置中开启相机权限后重试。",
                offerSettings: true
            )
        @unknown default:
            alertItem = ContentAlertItem(title: "无法打开相机", message: "发生未知错误。")
        }
    }

    private func saveCapturedImage(_ image: UIImage) {
        do {
            let fileName = try PhotoFileStore.shared.saveImage(image)
            let record = PhotoRecord(createdAt: Date(), fileName: fileName)
            modelContext.insert(record)
            try modelContext.save()
        } catch {
            alertItem = ContentAlertItem(title: "保存失败", message: error.localizedDescription)
        }
    }

    private func importFromPhotoLibrary(_ items: [PhotosPickerItem]) async {
        isImporting = true
        defer {
            isImporting = false
            selectedPickerItems = []
        }

        var importedCount = 0
        var failedCount = 0

        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    failedCount += 1
                    continue
                }

                let fileName = try PhotoFileStore.shared.saveImage(image)
                let createdAt = photoCreationDate(from: item) ?? Date()
                let record = PhotoRecord(createdAt: createdAt, fileName: fileName)
                modelContext.insert(record)
                importedCount += 1
            } catch {
                failedCount += 1
            }
        }

        do {
            try modelContext.save()
        } catch {
            alertItem = ContentAlertItem(title: "导入失败", message: error.localizedDescription)
            return
        }

        if failedCount > 0 {
            alertItem = ContentAlertItem(
                title: "导入完成",
                message: "成功导入 \(importedCount) 张，失败 \(failedCount) 张。"
            )
        }
    }

    private func photoCreationDate(from pickerItem: PhotosPickerItem) -> Date? {
        guard let itemIdentifier = pickerItem.itemIdentifier else { return nil }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [itemIdentifier], options: nil)
        return result.firstObject?.creationDate
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct DayGroup: Identifiable {
    let dayStart: Date
    let records: [PhotoRecord]

    var id: Date { dayStart }
}

private struct DayGroupCardView: View {
    let group: DayGroup

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
    private var previewRecords: [PhotoRecord] {
        Array(group.records.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(DayGrouper.displayString(for: group.dayStart))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(group.records.count) 张")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(previewRecords, id: \.id) { record in
                    PhotoThumbnailView(fileName: record.fileName)
                        .frame(height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct ContentAlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var offerSettings: Bool = false
}

#Preview {
    ContentView()
        .modelContainer(for: [PhotoRecord.self], inMemory: true)
}
