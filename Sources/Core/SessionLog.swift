import Foundation

/// Append-only JSON Lines persistence (plan §5).
///
/// Default location (App Sandbox is OFF): `~/Library/Application
/// Support/Seantimer/sessions.jsonl`, one JSON object per line. Append-only
/// keeps it crash-safe and concurrency-trivial — the file is never rewritten.
struct SessionLog {
    let fileURL: URL

    init(fileURL: URL = SessionLog.defaultURL()) {
        self.fileURL = fileURL
    }

    static func defaultURL() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("Seantimer", isDirectory: true)
            .appendingPathComponent("sessions.jsonl")
    }

    private static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// Append one record as a single `\n`-terminated JSON line, creating the
    /// containing directory and file if they do not yet exist.
    func append(_ record: SessionRecord) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        var line = try SessionLog.makeEncoder().encode(record)
        line.append(0x0A) // '\n'

        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }

    /// Rewrite the whole log from `records` (newest-edit wins). The log is
    /// otherwise append-only; this is the one path that mutates existing lines,
    /// used by history edit/delete. Written to a sibling temp file then swapped
    /// into place so a crash mid-write can never truncate the live log.
    func overwrite(_ records: [SessionRecord]) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = SessionLog.makeEncoder()
        var blob = Data()
        for record in records {
            blob.append(try encoder.encode(record))
            blob.append(0x0A) // '\n'
        }
        let tmp = fileURL.appendingPathExtension("tmp")
        try blob.write(to: tmp, options: .atomic)
        _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
    }

    /// Decode every line back into records (for tests / a future history view).
    /// Malformed lines are skipped rather than aborting the whole read.
    func readAll() throws -> [SessionRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let decoder = SessionLog.makeDecoder()
        return data
            .split(separator: 0x0A, omittingEmptySubsequences: true)
            .compactMap { try? decoder.decode(SessionRecord.self, from: Data($0)) }
    }
}
