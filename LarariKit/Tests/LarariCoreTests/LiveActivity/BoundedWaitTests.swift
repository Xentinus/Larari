import Foundation
import Testing
@testable import LarariCore

@MainActor
@Suite("BoundedWait")
struct BoundedWaitTests {
    @Test func aTaskThatFinishesInTimeReportsTrue() async {
        let task = Task<Void, Never> { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(await BoundedWait.finished(task, within: .seconds(5)))
    }

    @Test func aTaskThatRunsLongerReportsFalseAtTheBound() async {
        let task = Task<Void, Never> { try? await Task.sleep(for: .seconds(30)) }
        defer { task.cancel() }
        let clock = ContinuousClock()
        let start = clock.now
        #expect(await BoundedWait.finished(task, within: .milliseconds(50)) == false)
        #expect(clock.now - start < .seconds(5))
    }
}
