import SwiftUI

/// Central coordinator for SwiftUI navigation, tab switching, and inline sheet routing.
///
/// Designed to receive deep links / custom ATProto scheme URL taps from AttributedString.
@MainActor
public final class NavigationRouter: ObservableObject {
    /// Active tab selection (0 = Feed, 1 = Explore/Discovery, 2 = Settings)
    @Published public var selectedTab: Int = 0
    
    /// Global text binder to feed queries into DiscoveryView search
    @Published public var discoverySearchText: String = ""
    
    /// Set this to a user DID to present their profile view as a sheet
    @Published public var selectedProfileDID: String? = nil
    
    /// Set this to an HTTPS web URL to present an in-app browser sheet
    @Published public var selectedWebURL: URL? = nil
    
    public init() {}
    
    /// Resets all temporary modal sheet states
    public func dismissAll() {
        selectedProfileDID = nil
        selectedWebURL = nil
    }
}
