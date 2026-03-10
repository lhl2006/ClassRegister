import Foundation

struct FailedExportItem: Hashable {
    let photoID: UUID
    let fileName: String
    let reason: String
}

struct ExportResult {
    let parentDirectoryURL: URL
    let exportedCount: Int
    let failedCount: Int
    let failedItems: [FailedExportItem]
}

final class PhotoBatchExportService {
    private static let parentDirectoryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    private static let fileNameTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .autoupdatingCurrent
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HHmmss"
        return formatter
    }()

    private let fileStore: PhotoFileStore
    private let fileManager: FileManager
    private let calendar: Calendar

    init(
        fileStore: PhotoFileStore,
        fileManager: FileManager = .default,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.fileStore = fileStore
        self.fileManager = fileManager
        self.calendar = calendar
    }

    func export(records: [PhotoRecord], startDate: Date, endDate: Date) throws -> ExportResult {
        let dateRange = try normalizedRange(startDate: startDate, endDate: endDate)
        let parentDirectory = try createParentDirectory()
        let filtered = records.filter { record in
            record.createdAt >= dateRange.start && record.createdAt < dateRange.endExclusive
        }

        let groupedByDay = Dictionary(grouping: filtered) { record in
            calendar.startOfDay(for: record.createdAt)
        }

        var exportedCount = 0
        var failedItems: [FailedExportItem] = []

        for dayStart in groupedByDay.keys.sorted() {
            guard let recordsInDay = groupedByDay[dayStart], !recordsInDay.isEmpty else { continue }
            let dayDirectory = parentDirectory.appendingPathComponent(
                DateGrouping.displayDate(for: dayStart),
                isDirectory: true
            )
            let sortedRecords = recordsInDay.sorted(by: { $0.createdAt < $1.createdAt })

            do {
                try fileManager.createDirectory(at: dayDirectory, withIntermediateDirectories: true)
            } catch {
                let reason = AppError.fileWriteFailed.errorDescription ?? "文件写入失败。"
                sortedRecords.forEach { record in
                    failedItems.append(
                        FailedExportItem(
                            photoID: record.id,
                            fileName: record.fileName,
                            reason: reason
                        )
                    )
                }
                continue
            }

            let dayExportCountBefore = exportedCount

            for record in sortedRecords {
                do {
                    try copyRecord(record, to: dayDirectory)
                    exportedCount += 1
                } catch {
                    let reason = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    failedItems.append(
                        FailedExportItem(
                            photoID: record.id,
                            fileName: record.fileName,
                            reason: reason
                        )
                    )
                }
            }

            if exportedCount == dayExportCountBefore {
                try? fileManager.removeItem(at: dayDirectory)
            }
        }

        if exportedCount == 0 {
            try? fileManager.removeItem(at: parentDirectory)
        }

        return ExportResult(
            parentDirectoryURL: parentDirectory,
            exportedCount: exportedCount,
            failedCount: failedItems.count,
            failedItems: failedItems
        )
    }

    private func copyRecord(_ record: PhotoRecord, to dayDirectory: URL) throws {
        let sourceURL = try fileStore.imageURL(fileName: record.fileName)

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw AppError.fileMissing
        }

        let fileExtension = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let outputName = makeOutputName(
            createdAt: record.createdAt,
            fileExtension: fileExtension,
            in: dayDirectory
        )
        let destinationURL = dayDirectory.appendingPathComponent(outputName, isDirectory: false)

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw AppError.fileWriteFailed
        }
    }

    private func makeOutputName(createdAt: Date, fileExtension: String, in dayDirectory: URL) -> String {
        let baseName = Self.fileNameTimeFormatter.string(from: createdAt)
        var candidate = "\(baseName).\(fileExtension)"
        var suffix = 2

        while fileManager.fileExists(atPath: dayDirectory.appendingPathComponent(candidate).path) {
            candidate = "\(baseName)_\(suffix).\(fileExtension)"
            suffix += 1
        }

        return candidate
    }

    private func normalizedRange(startDate: Date, endDate: Date) throws -> (start: Date, endExclusive: Date) {
        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedEnd = calendar.startOfDay(for: endDate)

        guard normalizedStart <= normalizedEnd else {
            throw AppError.unknown("开始日期不能晚于结束日期。")
        }

        guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: normalizedEnd) else {
            throw AppError.unknown("导出日期范围计算失败。")
        }

        return (normalizedStart, endExclusive)
    }

    private func createParentDirectory() throws -> URL {
        let baseName = "ClassRegisterExport_\(Self.parentDirectoryFormatter.string(from: Date()))"
        var candidate = fileManager.temporaryDirectory.appendingPathComponent(baseName, isDirectory: true)

        if fileManager.fileExists(atPath: candidate.path) {
            candidate = fileManager.temporaryDirectory.appendingPathComponent(
                "\(baseName)_\(UUID().uuidString.prefix(6))",
                isDirectory: true
            )
        }

        do {
            try fileManager.createDirectory(at: candidate, withIntermediateDirectories: true)
            return candidate
        } catch {
            throw AppError.fileWriteFailed
        }
    }
}
