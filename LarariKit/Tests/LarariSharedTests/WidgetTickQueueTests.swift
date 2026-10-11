import Foundation
import Testing
@testable import LarariShared

@Suite("WidgetTickQueue")
struct WidgetTickQueueTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "larari-ticks-\(UUID().uuidString)",
                                                                     directoryHint: .isDirectory)
    var queue: WidgetTickQueue { WidgetTickQueue(directory: directory) }
    let at = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func drainReturnsTicksInOrderOnce() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = QueuedTick(itemID: UUID(), listID: UUID(), queuedAt: at)
        let second = QueuedTick(itemID: UUID(), listID: UUID(), queuedAt: at.addingTimeInterval(5))
        try queue.append(first)
        try queue.append(second)
        #expect(queue.pending() == [first, second])
        #expect(try queue.drain() == [first, second])
        #expect(try queue.drain().isEmpty)
    }

    @Test func theSameItemIsQueuedOnce() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = UUID(), list = UUID()
        try queue.append(QueuedTick(itemID: item, listID: list, queuedAt: at))
        try queue.append(QueuedTick(itemID: item, listID: list, queuedAt: at.addingTimeInterval(1)))
        #expect(queue.pending().count == 1)
    }

    @Test func aBrokenQueueIsDiscarded() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("[{".utf8).write(to: directory.appending(path: WidgetTickQueue.fileName))
        #expect(try queue.drain().isEmpty)
        try queue.append(QueuedTick(itemID: UUID(), listID: UUID(), queuedAt: at))
        #expect(queue.pending().count == 1)
    }
}
