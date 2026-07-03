import SwiftUI
import SwiftPaperATProtoCore

struct LoginView: View {
    @EnvironmentObject var client: ATProtoClient
    @State private var handle = ""
    @State private var password = ""
    @State private var isMockMode = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            RadialGradient(
                colors: [Color(red: 0.15, green: 0.25, blue: 0.6).opacity(0.4), .clear],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            RadialGradient(
                colors: [Color(red: 0.45, green: 0.15, blue: 0.5).opacity(0.35), .clear],
                center: .bottomLeading,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    VStack(spacing: 12) {
                        Image(systemName: "paperplane.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(brandGradient)
                            .shadow(color: Color(red: 0.1, green: 0.5, blue: 0.9).opacity(0.5), radius: 12)
                        
                        Text("Paper-ATProto")
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.bold)
                            .tracking(0.5)
                        
                        Text("A local-first, decentralized social reader")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                    
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bluesky Handle")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            TextField("username.bsky.social", text: $handle)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .autocorrectionDisabled()
                                .autocapitalization(.none)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("App Password")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            SecureField("Required for live accounts", text: $password)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .disabled(isMockMode)
                                .opacity(isMockMode ? 0.4 : 1.0)
                        }
                        
                        Toggle(isOn: $isMockMode) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mock Demo Mode")
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("Explore timeline without a Bluesky account")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.1, green: 0.5, blue: 0.9)))
                        .padding(.vertical, 8)
                        
                        if let error = client.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Button {
                            Task {
                                client.useMockData = isMockMode
                                await client.login(handle: handle, appPassword: password)
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if client.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isMockMode ? "Enter Demo" : "Sign In")
                                        .fontWeight(.bold)
                                    Image(systemName: "arrow.right")
                                }
                                Spacer()
                            }
                            .padding()
                            .background(brandGradient)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: Color(red: 0.1, green: 0.5, blue: 0.9).opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(client.isLoading || (!isMockMode && (handle.isEmpty || password.isEmpty)))
                        .opacity(client.isLoading || (!isMockMode && (handle.isEmpty || password.isEmpty)) ? 0.6 : 1.0)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
        }
    }
}
