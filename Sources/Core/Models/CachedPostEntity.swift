import ObjectBox
import Foundation

// objectbox: entity
class CachedPostEntity {
    var id: Id = 0
    var uri: String = ""
    var cid: String = ""
    var authorDid: String = ""
    var authorHandle: String = ""
    var authorDisplayName: String = ""
    var authorAvatar: String = ""
    var text: String = ""
    var createdAt: String = ""
    var likeCount: Int = 0
    var replyCount: Int = 0
    var repostCount: Int = 0
    var indexedAt: String = ""
    
    // Caching states
    var isSaved: Bool = false
    var isRead: Bool = false
    var localAbuseScore: Double = 0.0
    
    // External Link Embed
    var externalUri: String = ""
    var externalTitle: String = ""
    var externalDescription: String = ""
    var externalThumb: String = ""
    
    // Comma-separated list of image thumbnail URLs
    var imageThumbsCsv: String = ""
    // Comma-separated list of image fullsize URLs
    var imageFullsCsv: String = ""
    
    // Parameter-less initializer required by ObjectBox
    init() {}
    
    // Mapper from FeedViewPost
    init(from feedItem: FeedViewPost, isSaved: Bool, isRead: Bool, abuseScore: Double) {
        self.uri = feedItem.post.uri
        self.cid = feedItem.post.cid
        self.authorDid = feedItem.post.author.did
        self.authorHandle = feedItem.post.author.handle
        self.authorDisplayName = feedItem.post.author.displayName ?? ""
        self.authorAvatar = feedItem.post.author.avatar ?? ""
        self.text = feedItem.post.record.text
        self.createdAt = feedItem.post.record.createdAt
        self.likeCount = feedItem.post.likeCount ?? 0
        self.replyCount = feedItem.post.replyCount ?? 0
        self.repostCount = feedItem.post.repostCount ?? 0
        self.indexedAt = feedItem.post.indexedAt
        
        self.isSaved = isSaved
        self.isRead = isRead
        self.localAbuseScore = abuseScore
        
        if let embed = feedItem.post.embed {
            if let external = embed.external {
                self.externalUri = external.uri
                self.externalTitle = external.title
                self.externalDescription = external.description
                self.externalThumb = external.thumb ?? ""
            }
            if let images = embed.images {
                self.imageThumbsCsv = images.map { $0.thumb.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "" }.joined(separator: ",")
                self.imageFullsCsv = images.map { $0.fullsize.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "" }.joined(separator: ",")
            }
        }
    }
    
    // Mapper to FeedViewPost
    func toFeedViewPost() -> FeedViewPost {
        let author = ProfileViewBasic(
            did: authorDid,
            handle: authorHandle,
            displayName: authorDisplayName.isEmpty ? nil : authorDisplayName,
            avatar: authorAvatar.isEmpty ? nil : authorAvatar
        )
        
        let record = PostRecord(
            text: text,
            createdAt: createdAt
        )
        
        var embed: Embed? = nil
        let thumbs = imageThumbsCsv.split(separator: ",").map(String.init).compactMap { $0.removingPercentEncoding }
        let fulls = imageFullsCsv.split(separator: ",").map(String.init).compactMap { $0.removingPercentEncoding }
        
        if !thumbs.isEmpty {
            var embedImages: [EmbedImage] = []
            for i in 0..<thumbs.count {
                let full = i < fulls.count ? fulls[i] : thumbs[i]
                embedImages.append(EmbedImage(thumb: thumbs[i], fullsize: full, alt: nil))
            }
            embed = Embed(type: "app.bsky.embed.images", images: embedImages)
        } else if !externalUri.isEmpty {
            let external = EmbedExternal(
                uri: externalUri,
                title: externalTitle,
                description: externalDescription,
                thumb: externalThumb.isEmpty ? nil : externalThumb
            )
            embed = Embed(type: "app.bsky.embed.external", external: external)
        }
        
        let post = Post(
            uri: uri,
            cid: cid,
            author: author,
            record: record,
            embed: embed,
            replyCount: replyCount,
            repostCount: repostCount,
            likeCount: likeCount,
            indexedAt: indexedAt
        )
        
        return FeedViewPost(post: post)
    }
}
