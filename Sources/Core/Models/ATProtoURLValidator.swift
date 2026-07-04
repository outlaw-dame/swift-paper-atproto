import Foundation

/// Centralised, scheme-allowlist-based URL validator for all ATProto network inputs.
///
/// This is the **single source of truth** for URL safety across the entire codebase.
/// Every place that accepts a URL from a decoded server response, a user paste, or
/// a local model must pass through one of these validators.
///
/// Security model:
/// - Only explicitly whitelisted schemes are accepted.
/// - Loopback hosts (127.0.0.1, ::1, localhost) are always rejected for remote resources.
/// - All comparisons are case-insensitive (scheme RFC 3986 §3.1 is case-insensitive).
public enum ATProtoURLValidator {

    // MARK: - Media URLs (images, video playlists)

    /// Returns `true` if `urlString` is a valid URL for a media resource (image / video).
    ///
    /// Allowed schemes: `https` only.
    /// HTTP is intentionally excluded for media to prevent clear-text content injection.
    public static func isAllowedMediaURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased() else { return false }
        guard scheme == "https" else { return false }
        return !isLoopbackHost(url)
    }

    // MARK: - External Link URLs (opened in browser)

    /// Returns `true` if `urlString` is safe to present as a tappable web link.
    ///
    /// Allowed schemes: `https`, `http`.
    /// `javascript:`, `data:`, `file:`, `blob:` and all others are rejected.
    public static func isAllowedExternalURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased() else { return false }
        guard scheme == "https" || scheme == "http" else { return false }
        return !isLoopbackHost(url)
    }

    // MARK: - AT Protocol URIs (records, feed generators)

    /// Returns `true` if `uriString` is a valid `at://` identifier.
    ///
    /// Format: `at://did:<method>:<identifier>/<collection>/<rkey>`
    /// The collection must be a known app.bsky namespace to prevent IDOR.
    public static func isValidATUri(_ uriString: String, allowedCollections: Set<String> = ATProtoURLValidator.defaultATCollections) -> Bool {
        guard uriString.hasPrefix("at://") else { return false }
        // No path traversal components allowed anywhere in the string.
        guard !uriString.contains("..") else { return false }
        // Match pattern: at://did:<method>:<id>/<collection>/<rkey>
        let pattern = #"^at://did:[a-z0-9]+:[a-zA-Z0-9._:%\-]+/([a-zA-Z0-9.]+)/[a-zA-Z0-9._\-]+$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: uriString,
                range: NSRange(uriString.startIndex..., in: uriString)
              ) else { return false }
        // Extract and validate the collection segment.
        if let collectionRange = Range(match.range(at: 1), in: uriString) {
            let collection = String(uriString[collectionRange])
            return allowedCollections.contains(collection)
        }
        return false
    }

    /// The set of ATProto collections this app is authorised to read.
    /// Any record type not in this list is rejected at the validator boundary.
    public static let defaultATCollections: Set<String> = [
        "app.bsky.feed.post",
        "app.bsky.feed.generator",
        "app.bsky.actor.profile",
        "app.bsky.graph.follow",
        "app.bsky.graph.block",
        "app.bsky.graph.list",
        "app.bsky.graph.listitem",
        "app.bsky.graph.listblock",
        "app.bsky.notification.listNotifications"
    ]

    // MARK: - Private

    private static func isLoopbackHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
    }
}
