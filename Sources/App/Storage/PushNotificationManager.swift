import Foundation
import UserNotifications
import Combine

#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class PushNotificationManager: ObservableObject {
    @Published public var isRegistered = false
    @Published public var lastNotification: PushNotificationPayload? = nil
    
    public init() {}
    
    public func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isRegistered = granted
                if let error = error {
                    print("APNS Authorization failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    public func registerForRemoteNotifications() {
        #if os(iOS) && canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #elseif os(macOS)
        NSApplication.shared.registerForRemoteNotifications()
        #endif
    }
    
    // MARK: - Payload Sanitization & Extraction (Hardening Boundary)
    
    public func parseNotificationPayload(from userInfo: [AnyHashable: Any]) -> PushNotificationPayload? {
        // Safe extraction of dictionary structures
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any],
              let title = alert["title"] as? String,
              let body = alert["body"] as? String else {
            return nil
        }
        
        // Input sanitation: cap character length to prevent buffer overruns
        let sanitizedTitle = String(title.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedBody = String(body.prefix(250)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Deep link ATProtocol post URI validation
        var postUri: String? = nil
        if let uri = userInfo["postUri"] as? String {
            let trimmedUri = uri.trimmingCharacters(in: .whitespacesAndNewlines)
            // Hardening: validate URI format before accepting
            let pattern = "^at://did:[a-z0-9]+:[a-zA-Z0-9._%:-]+/app\\.bsky\\.feed\\.post/[a-zA-Z0-9_-]+$"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: trimmedUri.utf16.count)
                if regex.firstMatch(in: trimmedUri, options: [], range: range) != nil {
                    postUri = trimmedUri
                }
            }
        }
        
        let payload = PushNotificationPayload(
            title: sanitizedTitle,
            body: sanitizedBody,
            postUri: postUri
        )
        self.lastNotification = payload
        return payload
    }
}

public struct PushNotificationPayload: Codable, Identifiable, Hashable {
    public var id = UUID()
    public let title: String
    public let body: String
    public let postUri: String?
    
    public init(title: String, body: String, postUri: String?) {
        self.title = title
        self.body = body
        self.postUri = postUri
    }
}
