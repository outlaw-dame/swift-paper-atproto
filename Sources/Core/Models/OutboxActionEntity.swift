import ObjectBox
import Foundation

// objectbox: entity
class OutboxActionEntity {
    var id: Id = 0
    var actionType: String = ""
    var payloadJson: String = ""
    var createdAt: String = ""
    
    init() {}
    
    init(actionType: String, payloadJson: String, createdAt: String) {
        self.actionType = actionType
        self.payloadJson = payloadJson
        self.createdAt = createdAt
    }
}
