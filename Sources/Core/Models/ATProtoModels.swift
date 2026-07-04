import Foundation

// MARK: - Authentication Models
public struct CreateSessionResponse: Codable {
    public let did: String
    public let handle: String
    public let email: String?
    public let accessJwt: String
    public let refreshJwt: String
    /// Returned by getProfile; injected after session creation.
    public var displayName: String?
    public var avatar: String?

    public init(
        did: String,
        handle: String,
        email: String? = nil,
        accessJwt: String,
        refreshJwt: String,
        displayName: String? = nil,
        avatar: String? = nil
    ) {
        self.did = did
        self.handle = handle
        self.email = email
        self.accessJwt = accessJwt
        self.refreshJwt = refreshJwt
        self.displayName = displayName
        self.avatar = avatar
    }
}

// MARK: - Profile Models

/// Detailed profile record as returned by `app.bsky.actor.getProfile`.
public struct ProfileViewDetailed: Codable, Hashable {
    public let did: String
    public let handle: String
    public let displayName: String?
    public let description: String?
    public let avatar: String?
    public let banner: String?
    public let followersCount: Int?
    public let followsCount: Int?
    public let postsCount: Int?

    public init(
        did: String,
        handle: String,
        displayName: String? = nil,
        description: String? = nil,
        avatar: String? = nil,
        banner: String? = nil,
        followersCount: Int? = nil,
        followsCount: Int? = nil,
        postsCount: Int? = nil
    ) {
        self.did = did
        self.handle = handle
        self.displayName = displayName
        self.description = description
        self.avatar = avatar
        self.banner = banner
        self.followersCount = followersCount
        self.followsCount = followsCount
        self.postsCount = postsCount
    }
}

/// The ATProto record stored in `app.bsky.actor.profile`.
/// Used for both reading the current profile and constructing the `putRecord` body.
public struct ProfileRecord: Codable {
    public let type: String
    public var displayName: String?
    public var description: String?
    /// avatar and banner fields use blob references when submitted to the API;
    /// here we carry optional URL strings for the diagnostic / display layer.
    public var avatarUrl: String?
    public var bannerUrl: String?

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case displayName, description
        case avatarUrl, bannerUrl
    }

    public init(
        type: String = "app.bsky.actor.profile",
        displayName: String? = nil,
        description: String? = nil,
        avatarUrl: String? = nil,
        bannerUrl: String? = nil
    ) {
        self.type       = type
        self.displayName = displayName
        self.description = description
        self.avatarUrl  = avatarUrl
        self.bannerUrl  = bannerUrl
    }
}

/// Lightweight summary used inside `ProfileViewBasic` feed cards.
public struct ProfileViewBasic: Codable, Identifiable, Hashable {
    public var id: String { did }
    public let did: String
    public let handle: String
    public let displayName: String?
    public let avatar: String?
    
    public init(did: String, handle: String, displayName: String?, avatar: String?) {
        self.did = did
        self.handle = handle
        self.displayName = displayName
        self.avatar = avatar
    }
}

// MARK: - Post & Feed Models
public struct GetTimelineResponse: Codable {
    public let feed: [FeedViewPost]
    public let cursor: String?
}

public struct FeedViewPost: Codable, Identifiable, Hashable {
    public var id: String { post.uri }
    public let post: Post
    public let reply: ReplyRef?
    
    public init(post: Post, reply: ReplyRef? = nil) {
        self.post = post
        self.reply = reply
    }
}

public struct Post: Codable, Identifiable, Hashable {
    public var id: String { uri }
    public let uri: String
    public let cid: String
    public let author: ProfileViewBasic
    public let record: PostRecord
    public let embed: Embed?
    public let replyCount: Int?
    public let repostCount: Int?
    public let likeCount: Int?
    public let indexedAt: String
    
    public init(uri: String, cid: String, author: ProfileViewBasic, record: PostRecord, embed: Embed? = nil, replyCount: Int? = 0, repostCount: Int? = 0, likeCount: Int? = 0, indexedAt: String) {
        self.uri = uri
        self.cid = cid
        self.author = author
        self.record = record
        self.embed = embed
        self.replyCount = replyCount
        self.repostCount = repostCount
        self.likeCount = likeCount
        self.indexedAt = indexedAt
    }
}

public struct PostRecord: Codable, Hashable {
    public let text: String
    public let createdAt: String
    
    public init(text: String, createdAt: String) {
        self.text = text
        self.createdAt = createdAt
    }
}

// MARK: - Embed Models
public struct Embed: Codable, Hashable {
    public let type: String? // Custom type mapper
    public let images: [EmbedImage]?
    public let external: EmbedExternal?
    public let video: EmbedVideo?
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case images
        case external
        case video
    }
    
    public init(type: String? = nil, images: [EmbedImage]? = nil, external: EmbedExternal? = nil, video: EmbedVideo? = nil) {
        self.type = type
        self.images = images
        self.external = external
        self.video = video
    }
}

public struct EmbedVideo: Codable, Hashable {
    public let playlist: String
    public let thumbnail: String?

    /// Designated initialiser — validates playlist scheme before accepting.
    public init(playlist: String, thumbnail: String?) {
        self.playlist = playlist
        self.thumbnail = thumbnail
    }

    // MARK: - Hardened Decodable
    // Validates both `playlist` and `thumbnail` URLs at decode time.
    // Any non-http/https scheme causes the whole embed to decode as nil at the call-site.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawPlaylist = try container.decode(String.self, forKey: .playlist)
        guard ATProtoURLValidator.isAllowedMediaURL(rawPlaylist) else {
            throw DecodingError.dataCorruptedError(
                forKey: .playlist, in: container,
                debugDescription: "EmbedVideo.playlist has a disallowed URL scheme."
            )
        }
        self.playlist = rawPlaylist

        if let rawThumb = try container.decodeIfPresent(String.self, forKey: .thumbnail) {
            self.thumbnail = ATProtoURLValidator.isAllowedMediaURL(rawThumb) ? rawThumb : nil
        } else {
            self.thumbnail = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case playlist, thumbnail
    }
}

public struct EmbedImage: Codable, Hashable {
    public let thumb: String
    public let fullsize: String
    public let alt: String?

    public init(thumb: String, fullsize: String, alt: String?) {
        self.thumb = thumb
        self.fullsize = fullsize
        self.alt = alt
    }

    // MARK: - Hardened Decodable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawThumb    = try container.decode(String.self, forKey: .thumb)
        let rawFullsize = try container.decode(String.self, forKey: .fullsize)

        // Reject non-http/https image URLs at the model layer.
        guard ATProtoURLValidator.isAllowedMediaURL(rawThumb),
              ATProtoURLValidator.isAllowedMediaURL(rawFullsize) else {
            throw DecodingError.dataCorruptedError(
                forKey: .thumb, in: container,
                debugDescription: "EmbedImage contains a disallowed URL scheme."
            )
        }
        self.thumb    = rawThumb
        self.fullsize = rawFullsize
        self.alt      = try container.decodeIfPresent(String.self, forKey: .alt)
    }

    enum CodingKeys: String, CodingKey {
        case thumb, fullsize, alt
    }
}

public struct EmbedExternal: Codable, Hashable {
    public let uri: String
    public let title: String
    public let description: String
    public let thumb: String?

    public init(uri: String, title: String, description: String, thumb: String?) {
        self.uri = uri
        self.title = title
        self.description = description
        self.thumb = thumb
    }

    // MARK: - Hardened Decodable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawUri = try container.decode(String.self, forKey: .uri)

        // External link URIs must be http/https — blocks javascript:, data:, file: etc.
        guard ATProtoURLValidator.isAllowedExternalURL(rawUri) else {
            throw DecodingError.dataCorruptedError(
                forKey: .uri, in: container,
                debugDescription: "EmbedExternal.uri has a disallowed URL scheme."
            )
        }
        self.uri         = rawUri
        self.title       = String(try container.decode(String.self, forKey: .title).prefix(200))
        self.description = String(try container.decode(String.self, forKey: .description).prefix(500))

        if let rawThumb = try container.decodeIfPresent(String.self, forKey: .thumb) {
            self.thumb = ATProtoURLValidator.isAllowedMediaURL(rawThumb) ? rawThumb : nil
        } else {
            self.thumb = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case uri, title, description, thumb
    }
}

public struct ReplyRef: Codable, Hashable {
    public let root: Post?
    public let parent: Post?
    
    public init(root: Post?, parent: Post?) {
        self.root = root
        self.parent = parent
    }
}

// MARK: - Thread Models
public struct GetPostThreadResponse: Codable {
    public let thread: ThreadNode
}

public struct ThreadNode: Codable, Hashable {
    public let type: String
    public let post: Post?
    public let parent: ThreadNodeParent?
    public let replies: [ThreadNode]?
    
    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case post
        case parent
        case replies
    }
    
    public init(type: String, post: Post?, parent: ThreadNodeParent? = nil, replies: [ThreadNode]? = nil) {
        self.type = type
        self.post = post
        self.parent = parent
        self.replies = replies
    }
}

public indirect enum ThreadNodeParent: Codable, Hashable {
    case thread(ThreadNode)
    case notFound(NotFoundPost)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let node = try? container.decode(ThreadNode.self) {
            self = .thread(node)
        } else {
            let notFound = try container.decode(NotFoundPost.self)
            self = .notFound(notFound)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .thread(let node):
            try container.encode(node)
        case .notFound(let notFound):
            try container.encode(notFound)
        }
    }
}

public struct NotFoundPost: Codable, Hashable {
    public let uri: String
    public let notFound: Bool
}
