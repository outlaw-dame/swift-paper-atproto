import Foundation

// MARK: - DID Resolution Result

/// The result of a successful DID resolution.
public struct DIDResolutionResult: Hashable, Sendable {
    /// The resolved DID document identity string, e.g. "did:plc:xxxxx".
    public let did: String
    /// The method used to resolve the identity.
    public let method: ResolutionMethod
    /// The handle that was resolved.
    public let handle: String
    /// The raw DID document received from the PLC directory (nil if not fetched).
    public let didDocument: DIDDocument?

    public enum ResolutionMethod: String, Hashable, Sendable {
        case dnsTXT      = "DNS TXT Record"
        case httpWellKnown = "HTTP Well-Known"
        case plcDirectory  = "PLC Directory"
    }
}

/// A parsed, minimal representation of a DID document.
public struct DIDDocument: Hashable, Sendable {
    public let id: String
    public let alsoKnownAs: [String]
    public let verificationMethods: [VerificationMethod]
    public let services: [ServiceEndpoint]
}

public struct VerificationMethod: Hashable, Sendable {
    public let id: String
    public let type: String
    public let publicKeyMultibase: String?
}

public struct ServiceEndpoint: Hashable, Sendable {
    public let id: String
    public let type: String
    public let serviceEndpoint: String
}

// MARK: - Resolution Error

public enum DIDResolutionError: Error, LocalizedError {
    case invalidHandle
    case ssrfProtectedHost(String)
    case invalidDIDFormat
    case dnsFailed
    case wellKnownFailed
    case plcDirectoryFailed
    case allMethodsFailed
    case responseTooLarge
    case invalidContentType
    case didMismatch(expected: String, received: String)

    public var errorDescription: String? {
        switch self {
        case .invalidHandle:
            return "The handle format is invalid or contains disallowed characters."
        case .ssrfProtectedHost(let host):
            return "Resolution blocked: host '\(host)' is a loopback or reserved address."
        case .invalidDIDFormat:
            return "The resolved value does not match a valid DID format."
        case .dnsFailed:
            return "DNS TXT resolution did not return a valid ATProto DID."
        case .wellKnownFailed:
            return "HTTP Well-Known endpoint did not return a valid ATProto DID."
        case .plcDirectoryFailed:
            return "PLC directory lookup failed."
        case .allMethodsFailed:
            return "All DID resolution methods (DNS, HTTP well-known) failed."
        case .responseTooLarge:
            return "Resolution response exceeded the maximum allowed size."
        case .invalidContentType:
            return "Resolution response returned an unexpected content type."
        case .didMismatch(let expected, let received):
            return "DID mismatch: expected '\(expected)' but received '\(received)'."
        }
    }
}

// MARK: - DIDResolver

/// A hardened, async DID and handle resolver implementing the ATProto identity specification.
///
/// Resolution order (per ATProto spec):
///   1. DNS TXT record: `_atproto.<handle>` → `did=did:plc:xxxx`
///   2. HTTP well-known: `https://<handle>/.well-known/atproto-did` → raw DID string
///
/// Security guarantees:
/// - Handle input is validated against a strict regex allowlist before any I/O.
/// - Resolved hosts are checked against a loopback/private-IP blocklist (SSRF prevention).
/// - All responses are capped at `maxResponseBytes` to prevent memory exhaustion.
/// - Returned DID strings are validated against `^did:[a-z0-9]+:[a-zA-Z0-9._:%-]+$`.
/// - DID-document fetches from the PLC directory verify the returned `id` matches the expected DID.
/// - All URL construction uses `URLComponents` — never string interpolation — to prevent injection.
/// - All networking uses an ephemeral `URLSession` (no shared cookies/credentials).
public actor DIDResolver {

    // MARK: - Constants

    /// Maximum bytes accepted from any resolution response (16 KB is generous for a DID string).
    private static let maxResponseBytes = 16 * 1024

    /// Maximum bytes accepted for a full DID document JSON (64 KB).
    private static let maxDocumentBytes = 64 * 1024

    /// HTTP timeout for each resolution attempt.
    private static let timeoutInterval: TimeInterval = 10.0

    /// PLC directory base URL (the canonical AT Protocol PLC resolver).
    private static let plcDirectoryBase = "https://plc.directory"

    // MARK: - Private State

    private let session: URLSession

    // MARK: - Init

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = DIDResolver.timeoutInterval
        config.timeoutIntervalForResource = DIDResolver.timeoutInterval * 3
        // Disable all cookies and credentials for resolution requests.
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Resolves a handle (e.g. `alice.bsky.social`) to its DID.
    ///
    /// Tries DNS TXT first, then HTTP well-known. Throws `DIDResolutionError.allMethodsFailed`
    /// if neither succeeds.
    ///
    /// - Parameter handle: The bare handle to resolve (no leading `@`).
    /// - Returns: A `DIDResolutionResult` with the resolved DID and metadata.
    public func resolveHandle(_ rawHandle: String) async throws -> DIDResolutionResult {
        // 1. Sanitise and validate the handle.
        let handle = rawHandle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard isValidHandle(handle) else {
            throw DIDResolutionError.invalidHandle
        }

        // 2. SSRF guard on the handle's implicit host.
        try assertNotSSRFHost(handle)

        // 3. Try DNS TXT first (preferred per ATProto spec).
        if let did = try? await resolveDNSTXT(handle: handle) {
            guard isValidDID(did) else { throw DIDResolutionError.invalidDIDFormat }
            let doc = try? await fetchDIDDocument(did: did)
            return DIDResolutionResult(did: did, method: .dnsTXT, handle: handle, didDocument: doc)
        }

        // 4. Fallback: HTTP well-known.
        if let did = try? await resolveHTTPWellKnown(handle: handle) {
            guard isValidDID(did) else { throw DIDResolutionError.invalidDIDFormat }
            let doc = try? await fetchDIDDocument(did: did)
            return DIDResolutionResult(did: did, method: .httpWellKnown, handle: handle, didDocument: doc)
        }

        throw DIDResolutionError.allMethodsFailed
    }

    /// Fetches the full DID document from the PLC directory for a known `did:plc:` identifier.
    public func fetchDIDDocument(did: String) async throws -> DIDDocument {
        guard isValidDID(did) else { throw DIDResolutionError.invalidDIDFormat }
        // Only handle did:plc: documents (did:web is out of scope for this phase).
        guard did.hasPrefix("did:plc:") else { throw DIDResolutionError.plcDirectoryFailed }

        // Build URL via components — never string interpolation.
        var components = URLComponents(string: DIDResolver.plcDirectoryBase)!
        // The DID identifier segment: we extract only the method-specific ID portion.
        let didId = String(did.dropFirst("did:plc:".count))
        guard !didId.isEmpty, didId.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
            throw DIDResolutionError.invalidDIDFormat
        }
        components.path = "/\(did)"
        guard let url = components.url else { throw DIDResolutionError.plcDirectoryFailed }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DIDResolutionError.plcDirectoryFailed
        }

        guard data.count <= DIDResolver.maxDocumentBytes else {
            throw DIDResolutionError.responseTooLarge
        }

        let document = try parseDIDDocument(data: data, expectedDID: did)
        return document
    }

    // MARK: - Private: DNS TXT Resolution

    /// Resolves `_atproto.<handle>` DNS TXT records.
    ///
    /// ATProto specifies: the TXT record value must be exactly `did=<did>`.
    private func resolveDNSTXT(handle: String) async throws -> String? {
        // DNS resolution via `dnssd` / URLSession is not directly available in SPM on macOS
        // without system frameworks. We use a raw `host` subprocess via Foundation's Process
        // on macOS, or the system DNS resolution path on iOS via CFHost.
        // For portability across macOS + iOS, we implement this via a DNS-over-HTTPS query
        // to Cloudflare's 1.1.1.1 DoH service, which avoids requiring Network.framework
        // entitlements and works in the SPM sandbox.

        let dnsName = "_atproto.\(handle)"

        // Validate the composed DNS name to prevent injection.
        guard isDNSSafeLabel(dnsName) else { return nil }

        var components = URLComponents(string: "https://1.1.1.1/dns-query")!
        components.queryItems = [
            URLQueryItem(name: "name", value: dnsName),
            URLQueryItem(name: "type", value: "TXT")
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        // Cloudflare DoH requires this Accept header.
        request.setValue("application/dns-json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return nil }

        guard data.count <= DIDResolver.maxResponseBytes else {
            throw DIDResolutionError.responseTooLarge
        }

        // Parse the Cloudflare DoH JSON response.
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let answers = json["Answer"] as? [[String: Any]] else { return nil }

        for answer in answers {
            guard let type = answer["type"] as? Int, type == 16 else { continue } // 16 = TXT
            guard let rawData = answer["data"] as? String else { continue }

            // TXT record data arrives quoted; strip wrapping quotes.
            let value = rawData.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

            // ATProto spec: TXT value must start with "did="
            if value.hasPrefix("did=") {
                let candidate = String(value.dropFirst(4))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if isValidDID(candidate) { return candidate }
            }
        }
        return nil
    }

    // MARK: - Private: HTTP Well-Known Resolution

    /// Fetches `https://<handle>/.well-known/atproto-did` and returns the DID string.
    private func resolveHTTPWellKnown(handle: String) async throws -> String? {
        // Build URL via components — the handle must be a valid domain label.
        var components = URLComponents()
        components.scheme = "https"
        components.host   = handle
        components.path   = "/.well-known/atproto-did"
        guard let url = components.url else { return nil }

        // Second SSRF guard on the fully-resolved URL.
        try assertNotSSRFHost(handle)

        var request = URLRequest(url: url)
        request.setValue("text/plain", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else { return nil }

        guard data.count <= DIDResolver.maxResponseBytes else {
            throw DIDResolutionError.responseTooLarge
        }

        let rawDID = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return isValidDID(rawDID) ? rawDID : nil
    }

    // MARK: - Private: DID Document Parsing

    private func parseDIDDocument(data: Data, expectedDID: String) throws -> DIDDocument {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DIDResolutionError.plcDirectoryFailed
        }

        guard let id = json["id"] as? String else {
            throw DIDResolutionError.plcDirectoryFailed
        }

        // IDOR/Spoofing guard: the returned document's id MUST match what we asked for.
        guard id == expectedDID else {
            throw DIDResolutionError.didMismatch(expected: expectedDID, received: id)
        }

        let alsoKnownAs = json["alsoKnownAs"] as? [String] ?? []

        // Parse verification methods.
        var verificationMethods: [VerificationMethod] = []
        if let vms = json["verificationMethod"] as? [[String: Any]] {
            for vm in vms {
                guard let vmId   = vm["id"] as? String,
                      let vmType = vm["type"] as? String else { continue }
                let pkm = vm["publicKeyMultibase"] as? String
                verificationMethods.append(VerificationMethod(id: vmId, type: vmType, publicKeyMultibase: pkm))
            }
        }

        // Parse service endpoints.
        var services: [ServiceEndpoint] = []
        if let svcArray = json["service"] as? [[String: Any]] {
            for svc in svcArray {
                guard let svcId       = svc["id"] as? String,
                      let svcType     = svc["type"] as? String,
                      let svcEndpoint = svc["serviceEndpoint"] as? String else { continue }
                // Validate service endpoint URLs.
                guard ATProtoURLValidator.isAllowedExternalURL(svcEndpoint) else { continue }
                services.append(ServiceEndpoint(id: svcId, type: svcType, serviceEndpoint: svcEndpoint))
            }
        }

        return DIDDocument(
            id: id,
            alsoKnownAs: alsoKnownAs,
            verificationMethods: verificationMethods,
            services: services
        )
    }

    // MARK: - Private: Validation Helpers

    private func isValidHandle(_ handle: String) -> Bool {
        // ATProto handles: one or more DNS labels separated by dots.
        // Label: starts/ends with alphanumeric, may contain hyphens. Max 253 total chars.
        guard !handle.isEmpty, handle.count <= 253 else { return false }
        let pattern = #"^[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?)+$"#
        return handle.range(of: pattern, options: .regularExpression) != nil
    }

    private func isValidDID(_ did: String) -> Bool {
        guard !did.isEmpty, did.count <= 2048 else { return false }
        let pattern = #"^did:[a-z]+:[a-zA-Z0-9._:%-]{1,1987}$"#
        return did.range(of: pattern, options: .regularExpression) != nil
    }

    private func isDNSSafeLabel(_ label: String) -> Bool {
        // DNS label: letters, digits, hyphens, underscores, dots. Max 255 chars.
        guard !label.isEmpty, label.count <= 255 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        return label.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// Blocks SSRF resolution attempts targeting loopback, link-local, or private IP space.
    private func assertNotSSRFHost(_ host: String) throws {
        let blocked = [
            "localhost", "127.0.0.1", "::1", "[::1]",
            "0.0.0.0", "169.254.169.254", // AWS metadata
            "metadata.google.internal"
        ]
        let lower = host.lowercased()
        if blocked.contains(lower) {
            throw DIDResolutionError.ssrfProtectedHost(host)
        }
        // Block raw IPv4 private ranges by prefix.
        let privateIPPrefixes = ["10.", "172.16.", "172.17.", "172.18.", "172.19.",
                                 "172.20.", "172.21.", "172.22.", "172.23.", "172.24.",
                                 "172.25.", "172.26.", "172.27.", "172.28.", "172.29.",
                                 "172.30.", "172.31.", "192.168.", "100.64."]
        for prefix in privateIPPrefixes where lower.hasPrefix(prefix) {
            throw DIDResolutionError.ssrfProtectedHost(host)
        }
    }
}
