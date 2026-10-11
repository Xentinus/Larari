import Foundation

/// Cross-process file access in the App Group: the app writes, the extension reads and (iOS 26 ticks) edits.
enum FileCoordination {
    static func read<T>(_ url: URL, _ body: (URL) throws -> T) throws -> T {
        try coordinate(url, writing: false, options: [], body)
    }

    /// `.forMerging`: read-modify-write in one coordinated block.
    static func write<T>(_ url: URL, options: NSFileCoordinator.WritingOptions = .forReplacing,
                         _ body: (URL) throws -> T) throws -> T {
        try coordinate(url, writing: true, options: options, body)
    }

    private static func coordinate<T>(_ url: URL, writing: Bool, options: NSFileCoordinator.WritingOptions,
                                      _ body: (URL) throws -> T) throws -> T {
        var coordinationError: NSError?
        var result: Result<T, any Error>?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        if writing {
            coordinator.coordinate(writingItemAt: url, options: options, error: &coordinationError) { url in
                result = Result { try body(url) }
            }
        } else {
            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
                result = Result { try body(url) }
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
