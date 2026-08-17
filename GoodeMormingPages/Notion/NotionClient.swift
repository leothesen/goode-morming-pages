import Foundation

/// A place pages can be created. In the current API this is a *data source*,
/// not a database — see `NotionClient.apiVersion`.
struct NotionDestination: Identifiable, Hashable {
    let id: String
    let name: String
    /// The key of this destination's title property. It is whatever the column
    /// is called; assuming "Name" breaks the moment someone renames it.
    let titlePropertyKey: String
    /// The select or multi-select property tags go in, if the database has one.
    let tagProperty: TagProperty?
}

/// A select / multi-select column, with the options Notion already knows about.
///
/// The options are only a convenience for the picker — Notion creates any name
/// it hasn't seen before on write, so a brand new tag works without setting it
/// up in Notion first.
struct TagProperty: Hashable {
    let key: String
    let allowsMultiple: Bool
    let options: [String]
}

struct NotionPage {
    let id: String
    let url: String?
}

enum NotionError: LocalizedError, Equatable {
    case notConfigured
    case unauthorized
    case notShared
    case noTitleProperty(String)
    case rateLimited(retryAfter: TimeInterval?)
    case overloaded
    case api(status: Int, message: String)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Add your Notion token and pick a database in Settings first."
        case .unauthorized:
            return "Notion rejected the token. Paste a fresh one in Settings."
        case .notShared:
            return "Notion can't see that database. Open it in Notion, click ··· → Connections, and add Goode Morming Pages."
        case .noTitleProperty(let name):
            return "\"\(name)\" has no title property, so there's nowhere to put the title."
        case .rateLimited:
            return "Notion is rate limiting. Retrying shortly."
        case .overloaded:
            return "Notion is overloaded. Try again in a moment."
        case .api(let status, let message):
            return message.isEmpty ? "Notion returned \(status)." : message
        case .malformedResponse:
            return "Notion sent a response this app couldn't read."
        }
    }
}

/// Minimal Notion client: find destinations, create a page, append blocks.
struct NotionClient {
    /// Current API version.
    ///
    /// Under this version a page parent must be `data_source_id`. The older
    /// `database_id` shape — which the WalkingPad app still uses on 2022-06-28 —
    /// fails here, and fails on multi-source databases everywhere.
    static let apiVersion = "2026-03-11"

    let token: String
    var session: URLSession = .shared

    private var base: URL { URL(string: "https://api.notion.com/v1")! }

    // MARK: - Destinations

    /// Every data source the integration has been connected to.
    ///
    /// An empty result almost never means "you have no databases" — it means
    /// none have been connected to this integration yet. Say that, not "none found".
    func destinations() async throws -> [NotionDestination] {
        var found: [NotionDestination] = []
        var cursor: String?

        repeat {
            var body: [String: Any] = [
                "filter": ["property": "object", "value": "data_source"],
                "page_size": 100,
            ]
            if let cursor { body["start_cursor"] = cursor }

            let json = try await request(path: "search", method: "POST", body: body)
            let results = json["results"] as? [[String: Any]] ?? []

            for result in results {
                guard let id = result["id"] as? String else { continue }
                let name = plainText(result["title"]) ?? "Untitled"
                guard let titleKey = titlePropertyKey(in: result) else { continue }
                found.append(
                    NotionDestination(
                        id: id,
                        name: name,
                        titlePropertyKey: titleKey,
                        tagProperty: tagProperty(in: result)
                    )
                )
            }

            cursor = (json["has_more"] as? Bool == true) ? json["next_cursor"] as? String : nil
        } while cursor != nil

        return found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Writing

    func createPage(
        dataSourceID: String,
        titleKey: String,
        title: String,
        icon: String?,
        tagProperty: TagProperty?,
        tags: [String],
        children: [[String: Any]]
    ) async throws -> NotionPage {
        var properties: [String: Any] = [
            titleKey: ["title": [["text": ["content": title]]]],
        ]

        // Notion creates select options it hasn't seen before, so a new tag name
        // works without being set up in Notion first.
        if let tagProperty, !tags.isEmpty {
            if tagProperty.allowsMultiple {
                properties[tagProperty.key] = ["multi_select": tags.map { ["name": $0] }]
            } else if let first = tags.first {
                properties[tagProperty.key] = ["select": ["name": first]]
            }
        }

        var body: [String: Any] = [
            "parent": ["type": "data_source_id", "data_source_id": dataSourceID],
            "properties": properties,
            "children": children,
        ]

        if let icon, !icon.isEmpty {
            body["icon"] = ["type": "emoji", "emoji": icon]
        }

        let json = try await request(path: "pages", method: "POST", body: body)
        guard let id = json["id"] as? String else { throw NotionError.malformedResponse }
        return NotionPage(id: id, url: json["url"] as? String)
    }

    func appendBlocks(pageID: String, blocks: [[String: Any]]) async throws {
        _ = try await request(
            path: "blocks/\(pageID)/children",
            method: "PATCH",
            body: ["children": blocks]
        )
    }

    /// Cheap credential check that doubles as the destination fetch.
    func verify() async throws -> [NotionDestination] {
        try await destinations()
    }

    // MARK: - Plumbing

    private func request(path: String, method: String, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NotionError.malformedResponse }

        switch http.statusCode {
        case 200..<300:
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NotionError.malformedResponse
            }
            return json
        case 401:
            throw NotionError.unauthorized
        case 404:
            throw NotionError.notShared
        case 429:
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw NotionError.rateLimited(retryAfter: retry)
        case 529:
            throw NotionError.overloaded
        default:
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw NotionError.api(
                status: http.statusCode,
                message: (json?["message"] as? String) ?? ""
            )
        }
    }

    private func plainText(_ value: Any?) -> String? {
        guard let parts = value as? [[String: Any]] else { return nil }
        let joined = parts.compactMap { $0["plain_text"] as? String }.joined()
        return joined.isEmpty ? nil : joined
    }

    private func titlePropertyKey(in object: [String: Any]) -> String? {
        guard let properties = object["properties"] as? [String: Any] else { return nil }
        for (key, value) in properties {
            if let property = value as? [String: Any], property["type"] as? String == "title" {
                return key
            }
        }
        return nil
    }

    /// Finds the column tags should go in.
    ///
    /// Prefers one actually called "Tags"; otherwise takes the first select or
    /// multi-select in the schema. Dictionaries are unordered, so the fallback
    /// is sorted by key to stay stable between runs.
    private func tagProperty(in object: [String: Any]) -> TagProperty? {
        guard let properties = object["properties"] as? [String: Any] else { return nil }

        func parse(key: String, value: Any) -> TagProperty? {
            guard let property = value as? [String: Any],
                  let type = property["type"] as? String,
                  type == "multi_select" || type == "select"
            else { return nil }

            let detail = property[type] as? [String: Any]
            let options = (detail?["options"] as? [[String: Any]] ?? [])
                .compactMap { $0["name"] as? String }

            return TagProperty(
                key: key,
                allowsMultiple: type == "multi_select",
                options: options
            )
        }

        if let named = properties.first(where: { $0.key.caseInsensitiveCompare("Tags") == .orderedSame }),
           let property = parse(key: named.key, value: named.value) {
            return property
        }
        for key in properties.keys.sorted() {
            if let property = parse(key: key, value: properties[key] as Any) { return property }
        }
        return nil
    }
}
