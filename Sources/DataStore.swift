import Foundation

/// Handles reading and writing medications / dose records to JSON files
/// in `~/Library/Application Support/MedReminder/`.
enum DataStore {

    // MARK: - Storage directory

    private static let appSupportDir: URL = {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MedReminder", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let medicationsURL = appSupportDir.appendingPathComponent("medications.json")
    private static let recordsURL     = appSupportDir.appendingPathComponent("records.json")

    // MARK: - Public API

    /// A file that could not be decoded and was moved aside. The caller is
    /// expected to tell the user: silently showing an empty list looks exactly
    /// like "all my medications are gone".
    struct QuarantinedFile {
        let originalName: String
        let backupURL: URL
    }

    static func loadMedications() -> (items: [Medication], quarantine: QuarantinedFile?) {
        var quarantine: QuarantinedFile?
        let items: [Medication] = load(from: medicationsURL, quarantine: &quarantine) ?? []
        return (items, quarantine)
    }

    static func saveMedications(_ items: [Medication]) {
        save(items, to: medicationsURL)
    }

    static func loadRecords() -> (items: [DoseRecord], quarantine: QuarantinedFile?) {
        var quarantine: QuarantinedFile?
        let items: [DoseRecord] = load(from: recordsURL, quarantine: &quarantine) ?? []
        return (items, quarantine)
    }

    static func saveRecords(_ items: [DoseRecord]) {
        save(items, to: recordsURL)
    }

    // MARK: - Helpers

    /// Decoding note: the synthesized decoder only looks up declared keys, so
    /// removing a field keeps existing files decodable (unknown keys are
    /// ignored). The reverse is a trap — adding a non-optional property makes
    /// every existing file fail to decode and `load` then silently returns
    /// nil, showing the user an empty list. New fields must be Optional or
    /// decoded with `decodeIfPresent`.
    private static func load<T: Decodable>(
        from url: URL,
        quarantine: inout QuarantinedFile?
    ) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("⚠️ 无法解码 \(url.lastPathComponent): \(error)")
            if let backup = quarantineUndecodableFile(at: url) {
                quarantine = QuarantinedFile(
                    originalName: url.lastPathComponent, backupURL: backup
                )
            }
            return nil
        }
    }

    /// Moves a file the app cannot decode out of the way, so the empty list the
    /// caller falls back to cannot overwrite it on the next save. Returns the
    /// backup location, or nil when the move failed.
    @discardableResult
    static func quarantineUndecodableFile(at url: URL) -> URL? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let backup = url.deletingPathExtension()
            .appendingPathExtension("corrupt-\(formatter.string(from: Date())).json")
        guard (try? FileManager.default.moveItem(at: url, to: backup)) != nil else {
            print("⚠️ 备份失败，原文件未移动: \(url.path)")
            return nil
        }
        print("⚠️ 原文件已备份为 \(backup.lastPathComponent)")
        return backup
    }

    private static func save<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
