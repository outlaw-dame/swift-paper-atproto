// Generated using the ObjectBox Swift Generator — https://objectbox.io
// DO NOT EDIT

// swiftlint:disable all
import ObjectBox
import Foundation

// MARK: - Entity metadata

extension CachedPostEntity: ObjectBox.Entity {}
extension CustomFeedEntity: ObjectBox.Entity {}
extension OutboxActionEntity: ObjectBox.Entity {}

extension CachedPostEntity: ObjectBox.__EntityRelatable {
    internal typealias EntityType = CachedPostEntity

    internal var _id: EntityId<CachedPostEntity> {
        return EntityId<CachedPostEntity>(self.id.value)
    }
}

extension CachedPostEntity: ObjectBox.EntityInspectable {
    internal typealias EntityBindingType = CachedPostEntityBinding

    /// Generated metadata used by ObjectBox to persist the entity.
    internal static let entityInfo = ObjectBox.EntityInfo(name: "CachedPostEntity", id: 1)

    internal static let entityBinding = EntityBindingType()

    fileprivate static func buildEntity(modelBuilder: ObjectBox.ModelBuilder) throws {
        let entityBuilder = try modelBuilder.entityBuilder(for: CachedPostEntity.self, id: 1, uid: 5322533035072352768)
        try entityBuilder.addProperty(name: "id", type: PropertyType.long, flags: [.id], id: 1, uid: 3713420248862201856)
        try entityBuilder.addProperty(name: "uri", type: PropertyType.string, id: 2, uid: 3284299487935660800)
        try entityBuilder.addProperty(name: "cid", type: PropertyType.string, id: 3, uid: 5374747489309035776)
        try entityBuilder.addProperty(name: "authorDid", type: PropertyType.string, id: 4, uid: 6191497627755416064)
        try entityBuilder.addProperty(name: "authorHandle", type: PropertyType.string, id: 5, uid: 1362111370511290112)
        try entityBuilder.addProperty(name: "authorDisplayName", type: PropertyType.string, id: 6, uid: 7354406130303424512)
        try entityBuilder.addProperty(name: "authorAvatar", type: PropertyType.string, id: 7, uid: 7849087965115020544)
        try entityBuilder.addProperty(name: "text", type: PropertyType.string, id: 8, uid: 4426258536157592576)
        try entityBuilder.addProperty(name: "createdAt", type: PropertyType.string, id: 9, uid: 1342116696713779456)
        try entityBuilder.addProperty(name: "likeCount", type: PropertyType.long, id: 10, uid: 690218762273127936)
        try entityBuilder.addProperty(name: "replyCount", type: PropertyType.long, id: 11, uid: 3639687886344543488)
        try entityBuilder.addProperty(name: "repostCount", type: PropertyType.long, id: 12, uid: 7881804541460733952)
        try entityBuilder.addProperty(name: "indexedAt", type: PropertyType.string, id: 13, uid: 6960558265693307904)
        try entityBuilder.addProperty(name: "isSaved", type: PropertyType.bool, id: 14, uid: 7554181504210117632)
        try entityBuilder.addProperty(name: "isRead", type: PropertyType.bool, id: 15, uid: 8300531260535375360)
        try entityBuilder.addProperty(name: "localAbuseScore", type: PropertyType.double, id: 16, uid: 2867624284589171200)
        try entityBuilder.addProperty(name: "externalUri", type: PropertyType.string, id: 17, uid: 8873590641820877056)
        try entityBuilder.addProperty(name: "externalTitle", type: PropertyType.string, id: 18, uid: 4674677728696803840)
        try entityBuilder.addProperty(name: "externalDescription", type: PropertyType.string, id: 19, uid: 1674986707777005312)
        try entityBuilder.addProperty(name: "externalThumb", type: PropertyType.string, id: 20, uid: 4717700332511933696)
        try entityBuilder.addProperty(name: "imageThumbsCsv", type: PropertyType.string, id: 21, uid: 4445592542173910784)
        try entityBuilder.addProperty(name: "imageFullsCsv", type: PropertyType.string, id: 22, uid: 5149573903898599936)
        try entityBuilder.addProperty(name: "videoPlaylistUrl", type: PropertyType.string, id: 23, uid: 9196379733427265280)
        try entityBuilder.addProperty(name: "videoThumbnailUrl", type: PropertyType.string, id: 24, uid: 4403326334398934016)

        try entityBuilder.lastProperty(id: 24, uid: 4403326334398934016)
    }
}

extension CachedPostEntity {
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.id == myId }
    internal static var id: Property<CachedPostEntity, Id, Id> { return Property<CachedPostEntity, Id, Id>(propertyId: 1, isPrimaryKey: true) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.uri.startsWith("X") }
    internal static var uri: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 2, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.cid.startsWith("X") }
    internal static var cid: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 3, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.authorDid.startsWith("X") }
    internal static var authorDid: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 4, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.authorHandle.startsWith("X") }
    internal static var authorHandle: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 5, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.authorDisplayName.startsWith("X") }
    internal static var authorDisplayName: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 6, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.authorAvatar.startsWith("X") }
    internal static var authorAvatar: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 7, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.text.startsWith("X") }
    internal static var text: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 8, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.createdAt.startsWith("X") }
    internal static var createdAt: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 9, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.likeCount > 1234 }
    internal static var likeCount: Property<CachedPostEntity, Int, Void> { return Property<CachedPostEntity, Int, Void>(propertyId: 10, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.replyCount > 1234 }
    internal static var replyCount: Property<CachedPostEntity, Int, Void> { return Property<CachedPostEntity, Int, Void>(propertyId: 11, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.repostCount > 1234 }
    internal static var repostCount: Property<CachedPostEntity, Int, Void> { return Property<CachedPostEntity, Int, Void>(propertyId: 12, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.indexedAt.startsWith("X") }
    internal static var indexedAt: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 13, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.isSaved == true }
    internal static var isSaved: Property<CachedPostEntity, Bool, Void> { return Property<CachedPostEntity, Bool, Void>(propertyId: 14, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.isRead == true }
    internal static var isRead: Property<CachedPostEntity, Bool, Void> { return Property<CachedPostEntity, Bool, Void>(propertyId: 15, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.localAbuseScore > 1234 }
    internal static var localAbuseScore: Property<CachedPostEntity, Double, Void> { return Property<CachedPostEntity, Double, Void>(propertyId: 16, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.externalUri.startsWith("X") }
    internal static var externalUri: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 17, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.externalTitle.startsWith("X") }
    internal static var externalTitle: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 18, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.externalDescription.startsWith("X") }
    internal static var externalDescription: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 19, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.externalThumb.startsWith("X") }
    internal static var externalThumb: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 20, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.imageThumbsCsv.startsWith("X") }
    internal static var imageThumbsCsv: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 21, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.imageFullsCsv.startsWith("X") }
    internal static var imageFullsCsv: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 22, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.videoPlaylistUrl.startsWith("X") }
    internal static var videoPlaylistUrl: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 23, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CachedPostEntity.videoThumbnailUrl.startsWith("X") }
    internal static var videoThumbnailUrl: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 24, isPrimaryKey: false) }

    fileprivate func __setId(identifier: ObjectBox.Id) {
        self.id = Id(identifier)
    }
}

extension ObjectBox.Property where E == CachedPostEntity {
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .id == myId }

    internal static var id: Property<CachedPostEntity, Id, Id> { return Property<CachedPostEntity, Id, Id>(propertyId: 1, isPrimaryKey: true) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .uri.startsWith("X") }

    internal static var uri: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 2, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .cid.startsWith("X") }

    internal static var cid: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 3, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .authorDid.startsWith("X") }

    internal static var authorDid: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 4, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .authorHandle.startsWith("X") }

    internal static var authorHandle: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 5, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .authorDisplayName.startsWith("X") }

    internal static var authorDisplayName: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 6, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .authorAvatar.startsWith("X") }

    internal static var authorAvatar: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 7, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .text.startsWith("X") }

    internal static var text: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 8, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .createdAt.startsWith("X") }

    internal static var createdAt: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 9, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .likeCount > 1234 }

    internal static var likeCount: Property<CachedPostEntity, Int, Void> { return Property<CachedPostEntity, Int, Void>(propertyId: 10, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .replyCount > 1234 }

    internal static var replyCount: Property<CachedPostEntity, Int, Void> { return Property<CachedPostEntity, Int, Void>(propertyId: 11, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .repostCount > 1234 }

    internal static var repostCount: Property<CachedPostEntity, Int, Void> { return Property<CachedPostEntity, Int, Void>(propertyId: 12, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .indexedAt.startsWith("X") }

    internal static var indexedAt: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 13, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .isSaved == true }

    internal static var isSaved: Property<CachedPostEntity, Bool, Void> { return Property<CachedPostEntity, Bool, Void>(propertyId: 14, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .isRead == true }

    internal static var isRead: Property<CachedPostEntity, Bool, Void> { return Property<CachedPostEntity, Bool, Void>(propertyId: 15, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .localAbuseScore > 1234 }

    internal static var localAbuseScore: Property<CachedPostEntity, Double, Void> { return Property<CachedPostEntity, Double, Void>(propertyId: 16, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .externalUri.startsWith("X") }

    internal static var externalUri: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 17, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .externalTitle.startsWith("X") }

    internal static var externalTitle: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 18, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .externalDescription.startsWith("X") }

    internal static var externalDescription: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 19, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .externalThumb.startsWith("X") }

    internal static var externalThumb: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 20, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .imageThumbsCsv.startsWith("X") }

    internal static var imageThumbsCsv: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 21, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .imageFullsCsv.startsWith("X") }

    internal static var imageFullsCsv: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 22, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .videoPlaylistUrl.startsWith("X") }

    internal static var videoPlaylistUrl: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 23, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .videoThumbnailUrl.startsWith("X") }

    internal static var videoThumbnailUrl: Property<CachedPostEntity, String, Void> { return Property<CachedPostEntity, String, Void>(propertyId: 24, isPrimaryKey: false) }

}


/// Generated service type to handle persisting and reading entity data. Exposed through `CachedPostEntity.EntityBindingType`.
internal final class CachedPostEntityBinding: ObjectBox.EntityBinding, Sendable {
    internal typealias EntityType = CachedPostEntity
    internal typealias IdType = Id

    internal required init() {}

    internal func generatorBindingVersion() -> Int { 1 }

    internal func setEntityIdUnlessStruct(of entity: EntityType, to entityId: ObjectBox.Id) {
        entity.__setId(identifier: entityId)
    }

    internal func entityId(of entity: EntityType) -> ObjectBox.Id {
        return entity.id.value
    }

    internal func collect(fromEntity entity: EntityType, id: ObjectBox.Id,
                                  propertyCollector: ObjectBox.FlatBufferBuilder, store: ObjectBox.Store) throws {
        let propertyOffset_uri = propertyCollector.prepare(string: entity.uri)
        let propertyOffset_cid = propertyCollector.prepare(string: entity.cid)
        let propertyOffset_authorDid = propertyCollector.prepare(string: entity.authorDid)
        let propertyOffset_authorHandle = propertyCollector.prepare(string: entity.authorHandle)
        let propertyOffset_authorDisplayName = propertyCollector.prepare(string: entity.authorDisplayName)
        let propertyOffset_authorAvatar = propertyCollector.prepare(string: entity.authorAvatar)
        let propertyOffset_text = propertyCollector.prepare(string: entity.text)
        let propertyOffset_createdAt = propertyCollector.prepare(string: entity.createdAt)
        let propertyOffset_indexedAt = propertyCollector.prepare(string: entity.indexedAt)
        let propertyOffset_externalUri = propertyCollector.prepare(string: entity.externalUri)
        let propertyOffset_externalTitle = propertyCollector.prepare(string: entity.externalTitle)
        let propertyOffset_externalDescription = propertyCollector.prepare(string: entity.externalDescription)
        let propertyOffset_externalThumb = propertyCollector.prepare(string: entity.externalThumb)
        let propertyOffset_imageThumbsCsv = propertyCollector.prepare(string: entity.imageThumbsCsv)
        let propertyOffset_imageFullsCsv = propertyCollector.prepare(string: entity.imageFullsCsv)
        let propertyOffset_videoPlaylistUrl = propertyCollector.prepare(string: entity.videoPlaylistUrl)
        let propertyOffset_videoThumbnailUrl = propertyCollector.prepare(string: entity.videoThumbnailUrl)

        propertyCollector.collect(id, at: 2 + 2 * 1)
        propertyCollector.collect(entity.likeCount, at: 2 + 2 * 10)
        propertyCollector.collect(entity.replyCount, at: 2 + 2 * 11)
        propertyCollector.collect(entity.repostCount, at: 2 + 2 * 12)
        propertyCollector.collect(entity.isSaved, at: 2 + 2 * 14)
        propertyCollector.collect(entity.isRead, at: 2 + 2 * 15)
        propertyCollector.collect(entity.localAbuseScore, at: 2 + 2 * 16)
        propertyCollector.collect(dataOffset: propertyOffset_uri, at: 2 + 2 * 2)
        propertyCollector.collect(dataOffset: propertyOffset_cid, at: 2 + 2 * 3)
        propertyCollector.collect(dataOffset: propertyOffset_authorDid, at: 2 + 2 * 4)
        propertyCollector.collect(dataOffset: propertyOffset_authorHandle, at: 2 + 2 * 5)
        propertyCollector.collect(dataOffset: propertyOffset_authorDisplayName, at: 2 + 2 * 6)
        propertyCollector.collect(dataOffset: propertyOffset_authorAvatar, at: 2 + 2 * 7)
        propertyCollector.collect(dataOffset: propertyOffset_text, at: 2 + 2 * 8)
        propertyCollector.collect(dataOffset: propertyOffset_createdAt, at: 2 + 2 * 9)
        propertyCollector.collect(dataOffset: propertyOffset_indexedAt, at: 2 + 2 * 13)
        propertyCollector.collect(dataOffset: propertyOffset_externalUri, at: 2 + 2 * 17)
        propertyCollector.collect(dataOffset: propertyOffset_externalTitle, at: 2 + 2 * 18)
        propertyCollector.collect(dataOffset: propertyOffset_externalDescription, at: 2 + 2 * 19)
        propertyCollector.collect(dataOffset: propertyOffset_externalThumb, at: 2 + 2 * 20)
        propertyCollector.collect(dataOffset: propertyOffset_imageThumbsCsv, at: 2 + 2 * 21)
        propertyCollector.collect(dataOffset: propertyOffset_imageFullsCsv, at: 2 + 2 * 22)
        propertyCollector.collect(dataOffset: propertyOffset_videoPlaylistUrl, at: 2 + 2 * 23)
        propertyCollector.collect(dataOffset: propertyOffset_videoThumbnailUrl, at: 2 + 2 * 24)
    }

    internal func createEntity(entityReader: ObjectBox.FlatBufferReader, store: ObjectBox.Store) -> EntityType {
        let entity = CachedPostEntity()

        entity.id = entityReader.read(at: 2 + 2 * 1)
        entity.uri = entityReader.read(at: 2 + 2 * 2)
        entity.cid = entityReader.read(at: 2 + 2 * 3)
        entity.authorDid = entityReader.read(at: 2 + 2 * 4)
        entity.authorHandle = entityReader.read(at: 2 + 2 * 5)
        entity.authorDisplayName = entityReader.read(at: 2 + 2 * 6)
        entity.authorAvatar = entityReader.read(at: 2 + 2 * 7)
        entity.text = entityReader.read(at: 2 + 2 * 8)
        entity.createdAt = entityReader.read(at: 2 + 2 * 9)
        entity.likeCount = entityReader.read(at: 2 + 2 * 10)
        entity.replyCount = entityReader.read(at: 2 + 2 * 11)
        entity.repostCount = entityReader.read(at: 2 + 2 * 12)
        entity.indexedAt = entityReader.read(at: 2 + 2 * 13)
        entity.isSaved = entityReader.read(at: 2 + 2 * 14)
        entity.isRead = entityReader.read(at: 2 + 2 * 15)
        entity.localAbuseScore = entityReader.read(at: 2 + 2 * 16)
        entity.externalUri = entityReader.read(at: 2 + 2 * 17)
        entity.externalTitle = entityReader.read(at: 2 + 2 * 18)
        entity.externalDescription = entityReader.read(at: 2 + 2 * 19)
        entity.externalThumb = entityReader.read(at: 2 + 2 * 20)
        entity.imageThumbsCsv = entityReader.read(at: 2 + 2 * 21)
        entity.imageFullsCsv = entityReader.read(at: 2 + 2 * 22)
        entity.videoPlaylistUrl = entityReader.read(at: 2 + 2 * 23)
        entity.videoThumbnailUrl = entityReader.read(at: 2 + 2 * 24)

        return entity
    }
}



extension CustomFeedEntity: ObjectBox.__EntityRelatable {
    internal typealias EntityType = CustomFeedEntity

    internal var _id: EntityId<CustomFeedEntity> {
        return EntityId<CustomFeedEntity>(self.id.value)
    }
}

extension CustomFeedEntity: ObjectBox.EntityInspectable {
    internal typealias EntityBindingType = CustomFeedEntityBinding

    /// Generated metadata used by ObjectBox to persist the entity.
    internal static let entityInfo = ObjectBox.EntityInfo(name: "CustomFeedEntity", id: 3)

    internal static let entityBinding = EntityBindingType()

    fileprivate static func buildEntity(modelBuilder: ObjectBox.ModelBuilder) throws {
        let entityBuilder = try modelBuilder.entityBuilder(for: CustomFeedEntity.self, id: 3, uid: 5955998459275001856)
        try entityBuilder.addProperty(name: "id", type: PropertyType.long, flags: [.id], id: 1, uid: 7119755141635343872)
        try entityBuilder.addProperty(name: "uri", type: PropertyType.string, id: 2, uid: 7782002610489864448)
        try entityBuilder.addProperty(name: "displayName", type: PropertyType.string, id: 3, uid: 8929152202499181568)
        try entityBuilder.addProperty(name: "feedDescription", type: PropertyType.string, id: 4, uid: 3102976637030169088)
        try entityBuilder.addProperty(name: "avatar", type: PropertyType.string, id: 5, uid: 3044805524189889792)
        try entityBuilder.addProperty(name: "isPinned", type: PropertyType.bool, id: 6, uid: 4711517269688850176)
        try entityBuilder.addProperty(name: "isSubscribed", type: PropertyType.bool, id: 7, uid: 6345507282819573248)

        try entityBuilder.lastProperty(id: 7, uid: 6345507282819573248)
    }
}

extension CustomFeedEntity {
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CustomFeedEntity.id == myId }
    internal static var id: Property<CustomFeedEntity, Id, Id> { return Property<CustomFeedEntity, Id, Id>(propertyId: 1, isPrimaryKey: true) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CustomFeedEntity.uri.startsWith("X") }
    internal static var uri: Property<CustomFeedEntity, String, Void> { return Property<CustomFeedEntity, String, Void>(propertyId: 2, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CustomFeedEntity.displayName.startsWith("X") }
    internal static var displayName: Property<CustomFeedEntity, String, Void> { return Property<CustomFeedEntity, String, Void>(propertyId: 3, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CustomFeedEntity.feedDescription.startsWith("X") }
    internal static var feedDescription: Property<CustomFeedEntity, String, Void> { return Property<CustomFeedEntity, String, Void>(propertyId: 4, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CustomFeedEntity.avatar.startsWith("X") }
    internal static var avatar: Property<CustomFeedEntity, String, Void> { return Property<CustomFeedEntity, String, Void>(propertyId: 5, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CustomFeedEntity.isPinned == true }
    internal static var isPinned: Property<CustomFeedEntity, Bool, Void> { return Property<CustomFeedEntity, Bool, Void>(propertyId: 6, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { CustomFeedEntity.isSubscribed == true }
    internal static var isSubscribed: Property<CustomFeedEntity, Bool, Void> { return Property<CustomFeedEntity, Bool, Void>(propertyId: 7, isPrimaryKey: false) }

    fileprivate func __setId(identifier: ObjectBox.Id) {
        self.id = Id(identifier)
    }
}

extension ObjectBox.Property where E == CustomFeedEntity {
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .id == myId }

    internal static var id: Property<CustomFeedEntity, Id, Id> { return Property<CustomFeedEntity, Id, Id>(propertyId: 1, isPrimaryKey: true) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .uri.startsWith("X") }

    internal static var uri: Property<CustomFeedEntity, String, Void> { return Property<CustomFeedEntity, String, Void>(propertyId: 2, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .displayName.startsWith("X") }

    internal static var displayName: Property<CustomFeedEntity, String, Void> { return Property<CustomFeedEntity, String, Void>(propertyId: 3, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .feedDescription.startsWith("X") }

    internal static var feedDescription: Property<CustomFeedEntity, String, Void> { return Property<CustomFeedEntity, String, Void>(propertyId: 4, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .avatar.startsWith("X") }

    internal static var avatar: Property<CustomFeedEntity, String, Void> { return Property<CustomFeedEntity, String, Void>(propertyId: 5, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .isPinned == true }

    internal static var isPinned: Property<CustomFeedEntity, Bool, Void> { return Property<CustomFeedEntity, Bool, Void>(propertyId: 6, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .isSubscribed == true }

    internal static var isSubscribed: Property<CustomFeedEntity, Bool, Void> { return Property<CustomFeedEntity, Bool, Void>(propertyId: 7, isPrimaryKey: false) }

}


/// Generated service type to handle persisting and reading entity data. Exposed through `CustomFeedEntity.EntityBindingType`.
internal final class CustomFeedEntityBinding: ObjectBox.EntityBinding, Sendable {
    internal typealias EntityType = CustomFeedEntity
    internal typealias IdType = Id

    internal required init() {}

    internal func generatorBindingVersion() -> Int { 1 }

    internal func setEntityIdUnlessStruct(of entity: EntityType, to entityId: ObjectBox.Id) {
        entity.__setId(identifier: entityId)
    }

    internal func entityId(of entity: EntityType) -> ObjectBox.Id {
        return entity.id.value
    }

    internal func collect(fromEntity entity: EntityType, id: ObjectBox.Id,
                                  propertyCollector: ObjectBox.FlatBufferBuilder, store: ObjectBox.Store) throws {
        let propertyOffset_uri = propertyCollector.prepare(string: entity.uri)
        let propertyOffset_displayName = propertyCollector.prepare(string: entity.displayName)
        let propertyOffset_feedDescription = propertyCollector.prepare(string: entity.feedDescription)
        let propertyOffset_avatar = propertyCollector.prepare(string: entity.avatar)

        propertyCollector.collect(id, at: 2 + 2 * 1)
        propertyCollector.collect(entity.isPinned, at: 2 + 2 * 6)
        propertyCollector.collect(entity.isSubscribed, at: 2 + 2 * 7)
        propertyCollector.collect(dataOffset: propertyOffset_uri, at: 2 + 2 * 2)
        propertyCollector.collect(dataOffset: propertyOffset_displayName, at: 2 + 2 * 3)
        propertyCollector.collect(dataOffset: propertyOffset_feedDescription, at: 2 + 2 * 4)
        propertyCollector.collect(dataOffset: propertyOffset_avatar, at: 2 + 2 * 5)
    }

    internal func createEntity(entityReader: ObjectBox.FlatBufferReader, store: ObjectBox.Store) -> EntityType {
        let entity = CustomFeedEntity()

        entity.id = entityReader.read(at: 2 + 2 * 1)
        entity.uri = entityReader.read(at: 2 + 2 * 2)
        entity.displayName = entityReader.read(at: 2 + 2 * 3)
        entity.feedDescription = entityReader.read(at: 2 + 2 * 4)
        entity.avatar = entityReader.read(at: 2 + 2 * 5)
        entity.isPinned = entityReader.read(at: 2 + 2 * 6)
        entity.isSubscribed = entityReader.read(at: 2 + 2 * 7)

        return entity
    }
}



extension OutboxActionEntity: ObjectBox.__EntityRelatable {
    internal typealias EntityType = OutboxActionEntity

    internal var _id: EntityId<OutboxActionEntity> {
        return EntityId<OutboxActionEntity>(self.id.value)
    }
}

extension OutboxActionEntity: ObjectBox.EntityInspectable {
    internal typealias EntityBindingType = OutboxActionEntityBinding

    /// Generated metadata used by ObjectBox to persist the entity.
    internal static let entityInfo = ObjectBox.EntityInfo(name: "OutboxActionEntity", id: 2)

    internal static let entityBinding = EntityBindingType()

    fileprivate static func buildEntity(modelBuilder: ObjectBox.ModelBuilder) throws {
        let entityBuilder = try modelBuilder.entityBuilder(for: OutboxActionEntity.self, id: 2, uid: 5925817803454772992)
        try entityBuilder.addProperty(name: "id", type: PropertyType.long, flags: [.id], id: 1, uid: 9040406202272965120)
        try entityBuilder.addProperty(name: "actionType", type: PropertyType.string, id: 2, uid: 4395322439455836416)
        try entityBuilder.addProperty(name: "payloadJson", type: PropertyType.string, id: 3, uid: 1537627617565102080)
        try entityBuilder.addProperty(name: "createdAt", type: PropertyType.string, id: 4, uid: 4079471536940395008)

        try entityBuilder.lastProperty(id: 4, uid: 4079471536940395008)
    }
}

extension OutboxActionEntity {
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { OutboxActionEntity.id == myId }
    internal static var id: Property<OutboxActionEntity, Id, Id> { return Property<OutboxActionEntity, Id, Id>(propertyId: 1, isPrimaryKey: true) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { OutboxActionEntity.actionType.startsWith("X") }
    internal static var actionType: Property<OutboxActionEntity, String, Void> { return Property<OutboxActionEntity, String, Void>(propertyId: 2, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { OutboxActionEntity.payloadJson.startsWith("X") }
    internal static var payloadJson: Property<OutboxActionEntity, String, Void> { return Property<OutboxActionEntity, String, Void>(propertyId: 3, isPrimaryKey: false) }
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { OutboxActionEntity.createdAt.startsWith("X") }
    internal static var createdAt: Property<OutboxActionEntity, String, Void> { return Property<OutboxActionEntity, String, Void>(propertyId: 4, isPrimaryKey: false) }

    fileprivate func __setId(identifier: ObjectBox.Id) {
        self.id = Id(identifier)
    }
}

extension ObjectBox.Property where E == OutboxActionEntity {
    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .id == myId }

    internal static var id: Property<OutboxActionEntity, Id, Id> { return Property<OutboxActionEntity, Id, Id>(propertyId: 1, isPrimaryKey: true) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .actionType.startsWith("X") }

    internal static var actionType: Property<OutboxActionEntity, String, Void> { return Property<OutboxActionEntity, String, Void>(propertyId: 2, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .payloadJson.startsWith("X") }

    internal static var payloadJson: Property<OutboxActionEntity, String, Void> { return Property<OutboxActionEntity, String, Void>(propertyId: 3, isPrimaryKey: false) }

    /// Generated entity property information.
    ///
    /// You may want to use this in queries to specify fetch conditions, for example:
    ///
    ///     box.query { .createdAt.startsWith("X") }

    internal static var createdAt: Property<OutboxActionEntity, String, Void> { return Property<OutboxActionEntity, String, Void>(propertyId: 4, isPrimaryKey: false) }

}


/// Generated service type to handle persisting and reading entity data. Exposed through `OutboxActionEntity.EntityBindingType`.
internal final class OutboxActionEntityBinding: ObjectBox.EntityBinding, Sendable {
    internal typealias EntityType = OutboxActionEntity
    internal typealias IdType = Id

    internal required init() {}

    internal func generatorBindingVersion() -> Int { 1 }

    internal func setEntityIdUnlessStruct(of entity: EntityType, to entityId: ObjectBox.Id) {
        entity.__setId(identifier: entityId)
    }

    internal func entityId(of entity: EntityType) -> ObjectBox.Id {
        return entity.id.value
    }

    internal func collect(fromEntity entity: EntityType, id: ObjectBox.Id,
                                  propertyCollector: ObjectBox.FlatBufferBuilder, store: ObjectBox.Store) throws {
        let propertyOffset_actionType = propertyCollector.prepare(string: entity.actionType)
        let propertyOffset_payloadJson = propertyCollector.prepare(string: entity.payloadJson)
        let propertyOffset_createdAt = propertyCollector.prepare(string: entity.createdAt)

        propertyCollector.collect(id, at: 2 + 2 * 1)
        propertyCollector.collect(dataOffset: propertyOffset_actionType, at: 2 + 2 * 2)
        propertyCollector.collect(dataOffset: propertyOffset_payloadJson, at: 2 + 2 * 3)
        propertyCollector.collect(dataOffset: propertyOffset_createdAt, at: 2 + 2 * 4)
    }

    internal func createEntity(entityReader: ObjectBox.FlatBufferReader, store: ObjectBox.Store) -> EntityType {
        let entity = OutboxActionEntity()

        entity.id = entityReader.read(at: 2 + 2 * 1)
        entity.actionType = entityReader.read(at: 2 + 2 * 2)
        entity.payloadJson = entityReader.read(at: 2 + 2 * 3)
        entity.createdAt = entityReader.read(at: 2 + 2 * 4)

        return entity
    }
}


/// Helper function that allows calling Enum(rawValue: value) with a nil value, which will return nil.
fileprivate func optConstruct<T: RawRepresentable>(_ type: T.Type, rawValue: T.RawValue?) -> T? {
    guard let rawValue = rawValue else { return nil }
    return T(rawValue: rawValue)
}

// MARK: - Store setup

fileprivate func cModel() throws -> OpaquePointer {
    let modelBuilder = try ObjectBox.ModelBuilder()
    try CachedPostEntity.buildEntity(modelBuilder: modelBuilder)
    try CustomFeedEntity.buildEntity(modelBuilder: modelBuilder)
    try OutboxActionEntity.buildEntity(modelBuilder: modelBuilder)
    modelBuilder.lastEntity(id: 3, uid: 5955998459275001856)
    return modelBuilder.finish()
}

extension ObjectBox.Store {
    /// A store with a fully configured model. Created by the code generator with your model's metadata in place.
    ///
    /// # In-memory database
    /// To use a file-less in-memory database, instead of a directory path pass `memory:` 
    /// together with an identifier string:
    /// ```swift
    /// let inMemoryStore = try Store(directoryPath: "memory:test-db")
    /// ```
    ///
    /// - Parameters:
    ///   - directoryPath: The directory path in which ObjectBox places its database files for this store,
    ///     or to use an in-memory database `memory:<identifier>`.
    ///   - maxDbSizeInKByte: Limit of on-disk space for the database files. Default is `1024 * 1024` (1 GiB).
    ///   - fileMode: UNIX-style bit mask used for the database files; default is `0o644`.
    ///     Note: directories become searchable if the "read" or "write" permission is set (e.g. 0640 becomes 0750).
    ///   - maxReaders: The maximum number of readers.
    ///     "Readers" are a finite resource for which we need to define a maximum number upfront.
    ///     The default value is enough for most apps and usually you can ignore it completely.
    ///     However, if you get the maxReadersExceeded error, you should verify your
    ///     threading. For each thread, ObjectBox uses multiple readers. Their number (per thread) depends
    ///     on number of types, relations, and usage patterns. Thus, if you are working with many threads
    ///     (e.g. in a server-like scenario), it can make sense to increase the maximum number of readers.
    ///     Note: The internal default is currently around 120. So when hitting this limit, try values around 200-500.
    ///   - readOnly: Opens the database in read-only mode, i.e. not allowing write transactions.
    ///
    /// - important: This initializer is created by the code generator. If you only see the internal `init(model:...)`
    ///              initializer, trigger code generation by building your project.
    internal convenience init(directoryPath: String, maxDbSizeInKByte: UInt64 = 1024 * 1024,
                            fileMode: UInt32 = 0o644, maxReaders: UInt32 = 0, readOnly: Bool = false) throws {
        try self.init(
            model: try cModel(),
            directory: directoryPath,
            maxDbSizeInKByte: maxDbSizeInKByte,
            fileMode: fileMode,
            maxReaders: maxReaders,
            readOnly: readOnly)
    }
}

// swiftlint:enable all
