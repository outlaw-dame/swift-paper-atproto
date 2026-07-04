import Foundation
import CryptoKit

/// A thread-safe, hardened, local-first media file cache.
///
/// Security guarantees:
/// - All filenames are SHA-256 hashes of the source URL; no user-controlled characters ever touch the filesystem.
/// - Cache directory is created with POSIX 700 (owner-only) permissions on every open.
/// - Every read/write verifies the resolved path stays inside the cache directory (symlink-escape prevention).
/// - Each cached file is limited to `maxFileSizeBytes` to prevent disk-exhaustion attacks.
/// - Each cached file carries a creation-date attribute; files older than `ttlSeconds` are evicted on access.
/// - All `print` calls are limited to debug builds so production binaries don't leak internal paths.
public final class SecureMediaCache: Sendable {

    // MARK: - Constants (hardened limits)

    /// Maximum allowed size in bytes for a single cached media file (5 MB).
    public static let maxFileSizeBytes: Int = 5 * 1024 * 1024

    /// Time-to-live for cached entries in seconds (24 hours).
    public static let ttlSeconds: TimeInterval = 24 * 60 * 60

    // MARK: - Singleton

    public static let shared = SecureMediaCache()

    // MARK: - Private State

    private let cacheDirectory: URL

    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let directory = paths[0].appendingPathComponent("SecureMediaCache", isDirectory: true)
        self.cacheDirectory = directory
        Self.ensureDirectory(directory)
    }

    // MARK: - Public API

    /// Returns the SHA-256 hex-digest-keyed filename for a given URL.
    /// This guarantees that no URL component (path, query, fragment) can be used as a
    /// filesystem path component — all attacker-controlled input is fully hashed away.
    public func cacheKey(for url: URL) -> String {
        let inputData = Data(url.absoluteString.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined() + ".cache"
    }

    /// Writes `data` to the cache for `url`.
    ///
    /// Throws if:
    /// - The data is larger than `maxFileSizeBytes`.
    /// - The resolved target path escapes the cache directory (symlink traversal).
    public func cacheMedia(url: URL, data: Data) throws {
        guard data.count <= Self.maxFileSizeBytes else {
            throw CacheError.fileTooLarge(bytes: data.count)
        }
        let targetURL = try containedURL(for: url)
        // Atomic write: temp file is renamed into place; never partially visible.
        try data.write(to: targetURL, options: [.atomic, .completeFileProtection])
    }

    /// Returns cached `Data` for `url` if it exists and has not expired, else `nil`.
    ///
    /// Throws if the resolved target path escapes the cache directory.
    public func getCachedMedia(url: URL) throws -> Data? {
        let targetURL = try containedURL(for: url)
        guard FileManager.default.fileExists(atPath: targetURL.path) else { return nil }

        // TTL eviction: check modification date
        if let attrs = try? FileManager.default.attributesOfItem(atPath: targetURL.path),
           let created = attrs[.creationDate] as? Date {
            if Date().timeIntervalSince(created) > Self.ttlSeconds {
                try? FileManager.default.removeItem(at: targetURL)
                return nil
            }
        }

        return try Data(contentsOf: targetURL)
    }

    /// Removes all files inside the cache directory.
    /// Each file's resolved path is verified to reside inside the cache directory
    /// before deletion to prevent symlink-based escape.
    public func clearCache() {
        do {
            let resolvedCacheDir = cacheDirectory.resolvingSymlinksInPath().path
            let files = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            for file in files {
                let resolvedFile = file.resolvingSymlinksInPath().path
                guard resolvedFile.hasPrefix(resolvedCacheDir + "/") else {
                    debugLog("SecureMediaCache: Skipping suspicious file outside cache dir: \(file.lastPathComponent)")
                    continue
                }
                try FileManager.default.removeItem(at: file)
            }
        } catch {
            debugLog("SecureMediaCache: clearCache failed: \(error.localizedDescription)")
        }
    }

    /// Evicts all entries older than `ttlSeconds`. Call periodically (e.g., on app foreground).
    public func evictExpired() {
        do {
            let resolvedCacheDir = cacheDirectory.resolvingSymlinksInPath().path
            let files = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            let now = Date()
            for file in files {
                let resolvedFile = file.resolvingSymlinksInPath().path
                guard resolvedFile.hasPrefix(resolvedCacheDir + "/") else { continue }
                if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let created = attrs[.creationDate] as? Date,
                   now.timeIntervalSince(created) > Self.ttlSeconds {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            debugLog("SecureMediaCache: evictExpired failed: \(error.localizedDescription)")
        }
    }

    /// Returns `true` if the cache directory has POSIX 700 (owner-only) permissions.
    /// Used in unit tests to assert security invariants.
    public func verifyCacheDirectoryPermissions() -> Bool {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: cacheDirectory.path)
            if let permissions = attributes[.posixPermissions] as? NSNumber {
                return permissions.uint16Value == 0o700
            }
        } catch {
            debugLog("SecureMediaCache: permission check failed: \(error)")
        }
        return false
    }

    // MARK: - Private Helpers

    /// Computes a path-contained URL for `url` inside `cacheDirectory`.
    ///
    /// The containment check resolves symlinks on both sides before comparing, so a
    /// symlink inside the cache directory pointing outside cannot be used to escape.
    private func containedURL(for url: URL) throws -> URL {
        let key = cacheKey(for: url)
        let targetURL = cacheDirectory.appendingPathComponent(key)

        let resolvedTarget = targetURL.resolvingSymlinksInPath().path
        let resolvedCacheDir = cacheDirectory.resolvingSymlinksInPath().path

        // Path must begin with cache dir + "/" — the trailing slash prevents a directory
        // named "SecureMediaCache-evil" from passing a bare hasPrefix check.
        guard resolvedTarget.hasPrefix(resolvedCacheDir + "/") else {
            throw CacheError.pathTraversalAttempt
        }
        return targetURL
    }

    private static func ensureDirectory(_ directory: URL) {
        do {
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: NSNumber(value: 0o700)]
                )
            } else {
                // Re-enforce permissions in case they were changed externally.
                try FileManager.default.setAttributes(
                    [.posixPermissions: NSNumber(value: 0o700)],
                    ofItemAtPath: directory.path
                )
            }
        } catch {
            debugLog("SecureMediaCache: failed to ensure directory: \(error.localizedDescription)")
        }
    }

    // MARK: - Error Types

    public enum CacheError: Error, LocalizedError {
        case pathTraversalAttempt
        case fileTooLarge(bytes: Int)

        public var errorDescription: String? {
            switch self {
            case .pathTraversalAttempt:
                return "Blocked: cache path resolved outside the designated cache directory."
            case .fileTooLarge(let bytes):
                return "Blocked: incoming data (\(bytes) bytes) exceeds the \(SecureMediaCache.maxFileSizeBytes)-byte limit."
            }
        }
    }
}

// MARK: - Debug-only logging

private func debugLog(_ message: String) {
    #if DEBUG
    print(message)
    #endif
}
