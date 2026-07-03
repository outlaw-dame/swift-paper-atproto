import Foundation
import CryptoKit

public final class SecureMediaCache: Sendable {
    public static let shared = SecureMediaCache()
    
    private let cacheDirectory: URL
    
    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let directory = paths[0].appendingPathComponent("SecureMediaCache", isDirectory: true)
        self.cacheDirectory = directory
        
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // Hardening: Restrict folder access to owner only (700)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        } catch {
            print("Failed to initialize secure media cache directory: \(error.localizedDescription)")
        }
    }
    
    // Hash function to prevent URL/path injection and traversal exploits
    public func cacheKey(for url: URL) -> String {
        let inputData = Data(url.absoluteString.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined() + ".cache"
    }
    
    public func cacheMedia(url: URL, data: Data) throws {
        let key = cacheKey(for: url)
        let targetURL = cacheDirectory.appendingPathComponent(key)
        
        // Hardening Check: Prevent directory traversal exploits (SSRF / IDOR containment)
        let resolvedTarget = targetURL.resolvingSymlinksInPath().path
        let resolvedCacheDir = cacheDirectory.resolvingSymlinksInPath().path
        
        guard resolvedTarget.hasPrefix(resolvedCacheDir) else {
            throw NSError(domain: "SecureMediaCache", code: 403, userInfo: [NSLocalizedDescriptionKey: "Adversarial path traversal target blocked."])
        }
        
        try data.write(to: targetURL, options: .atomic)
    }
    
    public func getCachedMedia(url: URL) throws -> Data? {
        let key = cacheKey(for: url)
        let targetURL = cacheDirectory.appendingPathComponent(key)
        
        // Hardening Check: Path containment assertion
        let resolvedTarget = targetURL.resolvingSymlinksInPath().path
        let resolvedCacheDir = cacheDirectory.resolvingSymlinksInPath().path
        
        guard resolvedTarget.hasPrefix(resolvedCacheDir) else {
            throw NSError(domain: "SecureMediaCache", code: 403, userInfo: [NSLocalizedDescriptionKey: "Adversarial path traversal target blocked."])
        }
        
        guard FileManager.default.fileExists(atPath: targetURL.path) else { return nil }
        return try Data(contentsOf: targetURL)
    }
    
    public func clearCache() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
            print("SecureMediaCache: successfully cleared cached media files.")
        } catch {
            print("Failed to clear media cache: \(error.localizedDescription)")
        }
    }
    
    // Helper to check directory permissions - for unit tests
    public func verifyCacheDirectoryPermissions() -> Bool {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: cacheDirectory.path)
            if let permissions = attributes[.posixPermissions] as? NSNumber {
                return permissions.uint16Value == 0o700
            }
        } catch {
            print("Failed to verify folder permissions: \(error)")
        }
        return false
    }
}
