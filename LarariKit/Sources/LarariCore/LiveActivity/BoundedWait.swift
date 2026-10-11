import Foundation

/// Waits for a task, but no longer than a bound (R14 I2): an app-process tick waits for the launch share refresh at
/// most this long. Awaiting `task.value` does not react to cancellation, so a task group would wait for the task
/// anyway; the first of the two to finish resumes the continuation instead.
@MainActor
public enum BoundedWait {
    @MainActor private final class Once {
        var resumed = false
    }

    /// True when `task` finished within `limit`, false when the bound was hit first (the task keeps running).
    public static func finished(_ task: Task<Void, Never>, within limit: Duration) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let once = Once()
            let timer = Task { @MainActor in
                do { try await Task.sleep(for: limit) } catch { return }
                guard !once.resumed else { return }
                once.resumed = true
                continuation.resume(returning: false)
            }
            Task { @MainActor in
                await task.value
                timer.cancel()
                guard !once.resumed else { return }
                once.resumed = true
                continuation.resume(returning: true)
            }
        }
    }
}
