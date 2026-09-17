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

    static func loadMedications() -> [Medication] {
        load(from: medicationsURL) ?? []
    }

    static func saveMedications(_ items: [Medication]) {
        save(items, to: medicationsURL)
    }

    static func loadRecords() -> [DoseRecord] {
        load(from: recordsURL) ?? []
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
    private static func load<T: Decodable>(from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
