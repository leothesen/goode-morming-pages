import Foundation

/// Creates one Notion page per session and confirms every block landed.
///
/// The screen is only cleared once this returns successfully. You keep no local
/// archive, so a half-completed sync that wiped the buffer anyway would destroy
/// the session — confirm first, clear second.
struct SyncService {
    /// Notion allows roughly three requests a second on average. Spacing the
    /// append batches keeps a long session from tripping the limiter.
    static let batchInterval: TimeInterval = 0.35

    let client: NotionClient
    let destinationID: String
    let titleKey: String

    func sync(text: String, title: String) async throws -> NotionPage {
        let blocks = BlockBuilder.blocks(from: text)
        let batches = BlockBuilder.batches(blocks)

        let page = try await withRetry {
            try await client.createPage(
                dataSourceID: destinationID,
                titleKey: titleKey,
                title: title,
                children: batches.first ?? []
            )
        }

        for batch in batches.dropFirst() {
            try await Task.sleep(nanoseconds: UInt64(Self.batchInterval * 1_000_000_000))
            try await withRetry {
                try await client.appendBlocks(pageID: page.id, blocks: batch)
            }
        }

        return page
    }

    /// Retries once on the two transient statuses, honouring `Retry-After`.
    private func withRetry<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch let error as NotionError {
            let pause: TimeInterval?
            switch error {
            case .rateLimited(let retryAfter): pause = retryAfter ?? 2
            case .overloaded: pause = 2
            default: pause = nil
            }
            guard let pause else { throw error }
            try await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
            return try await work()
        }
    }
}
