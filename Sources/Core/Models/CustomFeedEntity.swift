import ObjectBox
import Foundation

// objectbox: entity
class CustomFeedEntity {
    var id: Id = 0
    var uri: String = ""
    var displayName: String = ""
    var feedDescription: String = ""
    var avatar: String = ""
    var isPinned: Bool = false
    var isSubscribed: Bool = false
    
    init() {}
    
    init(uri: String, displayName: String, description: String, avatar: String, isPinned: Bool, isSubscribed: Bool) {
        self.uri = uri
        self.displayName = displayName
        self.feedDescription = description
        self.avatar = avatar
        self.isPinned = isPinned
        self.isSubscribed = isSubscribed
    }
}
