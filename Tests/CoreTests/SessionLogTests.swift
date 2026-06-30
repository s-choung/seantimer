import XCTest
@testable import Seantimer

final class SessionLogTests: XCTestCase {
    func testAppendThenReadRoundTrips() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("uf-test-\(UUID().uuidString)", isDirectory: true)
        let log = SessionLog(fileURL: dir.appendingPathComponent("sessions.jsonl"))

        let r1 = SessionRecord(id: UUID(),
                               startedAt: Date(timeIntervalSince1970: 1000),
                               plannedSeconds: 1500, actualSeconds: 1500,
                               completed: true, label: "deep work")
        let r2 = SessionRecord(id: UUID(),
                               startedAt: Date(timeIntervalSince1970: 2000),
                               plannedSeconds: 600, actualSeconds: 120,
                               completed: false, label: nil)

        try log.append(r1)
        try log.append(r2)

        let back = try log.readAll()
        XCTAssertEqual(back.count, 2)
        XCTAssertEqual(back[0], r1)
        XCTAssertEqual(back[1], r2)
    }

    func testReadAllOnMissingFileReturnsEmpty() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("uf-missing-\(UUID().uuidString)/sessions.jsonl")
        XCTAssertEqual(try SessionLog(fileURL: url).readAll(), [])
    }
}
