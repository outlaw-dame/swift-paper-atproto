import SwiftUI
import SwiftPaperATProtoCore

struct ThreadView: View {
    let postUri: String
    
    @EnvironmentObject var client: ATProtoClient
    @State private var rootNode: ThreadNode? = nil
    @State private var isLoading = false
    @State private var errorMsg: String? = nil
    
    // Dynamic Thread Insights parsed via ThreadAnalytics substrate
    @State private var stanceCoverage: [String: Double] = [:]
    @State private var centralEntities: [String] = []
    @State private var integrityScore: Double = 1.0
    
    // Collapsible node states (Self-Healing / Navigational UI)
    @State private var collapsedNodeUris: Set<String> = []
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView("Analyzing Conversation Stream...")
                        .tint(.accentColor)
                    Spacer()
                } else if let error = errorMsg {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Thread Resolution Failed")
                            .font(.headline)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                } else if let root = rootNode {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            
                            // Dynamic Analytics Dashboard
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("Thread Interpretation Layer", systemImage: "brain.head.profile.fill")
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundStyle(brandGradient)
                                    
                                    Spacer()
                                    
                                    Text(String(format: "Integrity: %.0f%%", integrityScore * 100))
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                                
                                Text("Automated stance coverage and entity centrality resolved by local deterministic heuristics.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                // Dynamic Stance Progress Bars
                                VStack(spacing: 6) {
                                    ForEach(stanceCoverage.sorted(by: { $0.value > $1.value }), id: \.key) { key, val in
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(key)
                                                    .font(.system(size: 9, weight: .bold))
                                                Spacer()
                                                Text("\(Int(val * 100))%")
                                                    .font(.system(size: 9, design: .monospaced))
                                                    .foregroundColor(.secondary)
                                            }
                                            GeometryReader { barGeo in
                                                ZStack(alignment: .leading) {
                                                    Capsule().fill(Color.white.opacity(0.06))
                                                    Capsule()
                                                        .fill(key == "Supportive" ? Color.green : (key == "Skeptical" ? Color.orange : Color.blue))
                                                        .frame(width: barGeo.size.width * CGFloat(val))
                                                }
                                            }
                                            .frame(height: 4)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                                
                                // Dynamic Entity chips
                                FlowLayout(items: centralEntities) { entity in
                                    Text("#\(entity)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.accentColor)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.accentColor.opacity(0.12))
                                        .cornerRadius(4)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .padding(.horizontal)
                            .padding(.top, 10)
                            
                            // Root Post view
                            if let post = root.post {
                                RootPostView(post: post)
                                    .padding(.horizontal)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal)
                            
                            // Collapsible Comment Tree
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Resolved Comments")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                if let replies = root.replies, !replies.isEmpty {
                                    ForEach(replies, id: \.self) { node in
                                        ReplyNodeView(
                                            node: node,
                                            depth: 0,
                                            collapsedNodeUris: $collapsedNodeUris
                                        )
                                    }
                                } else {
                                    Text("No comments in this thread.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding()
                                }
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationTitle("Thread Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadThread()
        }
    }
    
    private func loadThread() {
        isLoading = true
        errorMsg = nil
        
        Task {
            do {
                let response = try await client.fetchThread(postUri: postUri)
                self.rootNode = response.thread
                
                // Parse metrics dynamically
                let insights = ThreadAnalytics.analyzeThread(response.thread)
                self.stanceCoverage = insights.stanceCoverage
                self.centralEntities = insights.centralEntities
                self.integrityScore = insights.integrityScore
            } catch {
                self.errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct RootPostView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                if let avatar = post.author.avatar, let avatarURL = URL(string: avatar) {
                    AsyncImage(url: avatarURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(Color.gray)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author.displayName ?? post.author.handle)
                        .font(.headline)
                    Text("@\(post.author.handle)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Verified")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12))
                .cornerRadius(6)
            }
            
            Text(post.record.text)
                .font(.system(.body, design: .serif))
                .lineSpacing(6)
            
            Text("Indexed at \(post.indexedAt)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white.opacity(0.02))
        .cornerRadius(14)
    }
}

struct ReplyNodeView: View {
    let node: ThreadNode
    let depth: Int
    @Binding var collapsedNodeUris: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let post = node.post {
                let isCollapsed = collapsedNodeUris.contains(post.uri)
                
                HStack(alignment: .top, spacing: 12) {
                    // Indent Line markers
                    if depth > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 1.5)
                            .padding(.leading, CGFloat(depth * 10))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            if let avatar = post.author.avatar, let avatarURL = URL(string: avatar) {
                                AsyncImage(url: avatarURL) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle().fill(Color.gray)
                                }
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(post.author.displayName ?? post.author.handle)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text("@\(post.author.handle)")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Collapsed/Collapsed badge indicator
                            if isCollapsed {
                                let totalRepliesCount = countAllReplies(node)
                                Text("[+ \(totalRepliesCount) comments]")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.12))
                                    .cornerRadius(4)
                            } else {
                                Text(String(format: "Score: %.2f", Double(post.likeCount ?? 0) / 10.0))
                                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !isCollapsed {
                            Text(post.record.text)
                                .font(.caption)
                                .lineSpacing(3)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(isCollapsed ? 0.02 : 0.04))
                    .cornerRadius(12)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25)) {
                            if isCollapsed {
                                collapsedNodeUris.remove(post.uri)
                            } else {
                                collapsedNodeUris.insert(post.uri)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                
                // Render children recursively (Only if NOT collapsed)
                if !isCollapsed, let replies = node.replies, !replies.isEmpty {
                    ForEach(replies, id: \.self) { child in
                        ReplyNodeView(
                            node: child,
                            depth: depth + 1,
                            collapsedNodeUris: $collapsedNodeUris
                        )
                    }
                }
            }
        }
    }
    
    // Count child replies recursive helper
    private func countAllReplies(_ node: ThreadNode) -> Int {
        guard let replies = node.replies else { return 0 }
        var count = replies.count
        for child in replies {
            count += countAllReplies(child)
        }
        return count
    }
}

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content
    
    var body: some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(items), id: \.self) { item in
                    self.content(item)
                        .padding([.horizontal, .vertical], 4)
                        .alignmentGuide(.leading, computeValue: { d in
                            if (abs(width - d.width) > geo.size.width) {
                                width = 0
                                height -= d.height
                            }
                            let result = width
                            if item == self.items.last {
                                width = 0
                            } else {
                                width -= d.width
                            }
                            return result
                        })
                        .alignmentGuide(.top, computeValue: { d in
                            let result = height
                            if item == self.items.last {
                                height = 0
                            }
                            return result
                        })
                }
            }
        }
        .frame(height: 30)
    }
}
