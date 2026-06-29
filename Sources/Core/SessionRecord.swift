import Foundation

/// One logged focus session (plan §5). Serialized as a single JSON line.
struct SessionRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let startedAt: Date          // ISO-8601 on disk
    let plannedSeconds: Int      // duration the user dialed in
    let actualSeconds: Int       // planned − remaining-at-stop
    let completed: Bool          // true = ran to zero, false = stopped early
    var label: String?
}
