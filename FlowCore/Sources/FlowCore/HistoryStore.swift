import Foundation

/// Session history as a small JSON file. Plenty for years of sessions.
public struct HistoryStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// ~/Library/Application Support/FlowPomodoro/history.json
    public static func defaultURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("FlowPomodoro", isDirectory: true).appendingPathComponent("history.json")
    }

    public func load() -> [SessionRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([SessionRecord].self, from: data)) ?? []
    }

    public func save(_ records: [SessionRecord]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(to: url, options: .atomic)
    }
}
