# Swift-Paper-ATProto — Roadmap Phases 6 to 15

This document outlines the long-term roadmap for **Swift-Paper-ATProto**, mapping out the next 10 phases of engineering (Phases 6 to 15) to transition this client from a functional local-first substrate to a world-class production decentralized reader.

---

```mermaid
gantt
    title Future Phases Roadmap (Phases 6 - 15)
    dateFormat  YYYY-MM-DD
    section Phase 6 - 8
    Phase 6: Multi-Account & Drafts      :active,   p6, 2026-09-01, 2026-09-15
    Phase 7: Custom Feed Sorting         :          p7, 2026-09-15, 2026-09-30
    Phase 8: Media Caching & Video       :          p8, 2026-10-01, 2026-10-15
    section Phase 9 - 11
    Phase 9: DID Identity & Handles     :          p9, 2026-10-15, 2026-10-30
    Phase 10: Rich Text & Facets         :          p10, 2026-11-01, 2026-11-15
    Phase 11: WebSockets Firehose        :          p11, 2026-11-15, 2026-12-05
    section Phase 12 - 15
    Phase 12: Network Proxy & DB Crypt   :          p12, 2026-12-05, 2026-12-25
    Phase 13: Moderation & Labelling    :          p13, 2026-12-25, 2027-01-15
    Phase 14: Widgets & iCloud Sync      :          p14, 2027-01-15, 2027-02-10
    Phase 15: Store Optimization & A11y :          p15, 2027-02-10, 2027-03-05
```

---

## Phase 6: Multi-Account Management & Offline Outbox

Enable users to switch profiles and write content offline safely.

- **Keychain Multi-Profile switcher:** Allow storing multiple session JWT credentials in the Keychain under unique index keys, switching active sessions without logging out.
- **Offline Outbox Queue:** Save draft posts, likes, and bookmarks in a dedicated ObjectBox table (`OutboxEntity`) when offline.
- **Self-Healing Sync Worker:** A network monitor that automatically flushes and publishes outbox queues via HTTP POST requests once connection returns.

---

## Phase 7: Custom Feed Generators & Local Algorithmic Sorting

Integrate subscription models for custom decentralized feeds.

- **Custom Feeds Subscriptions (`com.atproto.feed.getFeedGenerator`):** Add lists query mechanisms enabling users to search, pin, and subscribe to custom algorithms (e.g. Science, Art, News).
- **Feeds Horizontal Carousel:** Wire custom feeds as individual tabs or cards in the main SwiftUI timeline deck.
- **Local Algorithmic Sorting:** Implement local scoring algorithms sorting the ObjectBox cached timelines based on user read history, likes, safety ratings, and keyword filters.

---

## Phase 8: Rich Media Subsystem & Local Image Caching

Enhance card visuals with progressive media buffers and video features.

- **Progressive Image Loading:** Implement progressive thumbnails loading with blurred placeholding and double-tap zoom gestures.
- **Local Media Caching:** Cache external thumbnails locally in a restricted directory with owner-only permissions (`700`), avoiding repeated network requests.
- **Inline Video Player (AVKit):** Add inline video playback (using `AVPlayer`) following Apple HIG guidelines (muted autoplay, seamless transition to full screen, and pinch-to-dismiss).

---

## Phase 9: Identity Resolution & Handle Management

Support profile edits and DID cryptographic verifications.

- **Profile Editing client:** Write mapping queries to update a user's avatar, header banner, description, and displayName (`com.atproto.repo.putRecord` against `app.bsky.actor.profile`).
- **DID Resolver:** Resolve handles using DNS TXT record lookups (`_atproto`) or HTTP well-known files (`/.well-known/atproto-did`).
- **Identity Diagnosis Screen:** Telemetry showing resolved rotation logs, signing keys, and validation states.

---

## Phase 10: Rich Text parser & Facets Resolution

Decode and highlight interactive mentions, links, and tags.

- **Facet Byte-Index Parser:** Translate ATProto record byte facets (mentions, tags, external links) into clickable SwiftUI text ranges.
- **Inline Routing Navigation:** Implement route navigations: tapping handles routes to profile views, tapping hashtags routes to discovery query filters, and tapping links navigates to web browser sheets.

---

## Phase 11: Real-Time PubSub WebSocket Firehose

Integrate real-time stream consumers for instant updates.

- **Firehose Consumer:** Implement a WebSocket client consuming repository updates (`com.atproto.sync.subscribeRepos`) directly from relays.
- **Local Ingestion Engine:** Filter firehose operations for events matching the user's graph (replies, mentions, likes) and insert them directly into the ObjectBox cache.
- **Instant Feed Animation:** Push real-time animations to the UI timeline when a new matching post is cached.

---

## Phase 12: Network Proxy Privacy & DB Encryption

Harden privacy limits and encrypt local databases.

- **Tor/Orion Proxy Tunnels:** Support custom routing configs to tunnel API requests through secure proxy chains, masking user IP addresses.
- **ObjectBox Database Encryption:** Generate a random 32-byte database encryption key on first run, store it in Apple Keychain, and instantiate the ObjectBox database store in encrypted mode (AES-256).

---

## Phase 13: Moderation & Labelling Services

Enforce decentralized content filters and reporting flows.

- **Labels Parser (`com.atproto.moderation.defs`):** Query and cache account and post moderation labels issued by Bluesky or third-party Ozone labelers.
- **Visual Gating Overlays:** Blur sensitive images or hide flagged posts, displaying warnings that require explicit user tapping to bypass.
- **Content Reporting client:** Build flows allowing users to report posts, lists, or accounts directly from the UI.

---

## Phase 14: Home Widgets & iCloud Multi-Device Sync

Extend application presence across the system and multiple devices.

- **Home Screen Gist Widgets:** Build iOS/macOS widgets displaying the top compiled Neeva Gist story headlines.
- **iCloud Bookmarks Sync:** Sync bookmarks and read states across user devices (iPhone, iPad, Mac) using iCloud encrypted database containers.
- **Siri Shortcuts:** Expose intent actions like "Read my ATProto Feed" or "Gist Headlines".

---

## Phase 15: Distribution, Optimization & App Store Compliance

Prepare application for wide release.

- **Localization (l10n):** Export string properties and localize for Spanish, French, German, Japanese, etc.
- **Accessibility (a11y) Audit:** Support VoiceOver labels, adjustable sliders, font sizes, and high contrast modes.
- **fastlane TestFlight pipeline:** Establish CI/CD workflows building targets and pushing releases to App Store Connect.
