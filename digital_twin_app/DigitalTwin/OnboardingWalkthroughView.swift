import SwiftUI

// MARK: - Onboarding Walkthrough
/// Shown after HealthKit authorization to explain the app's key concepts.
struct OnboardingWalkthroughView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    private let pages: [WalkthroughPage] = [
        WalkthroughPage(
            icon: "battery.100.bolt",
            iconColor: .ptSage,
            title: "Body Battery",
            description: "Your Body Battery starts at 100% each morning after sleep. Stress and activity drain it throughout the day, while recovery activities recharge it.",
            detail: "It's inspired by Garmin's Body Battery and backed by HRV research."
        ),
        WalkthroughPage(
            icon: "waveform.path.ecg",
            iconColor: .ptTeal,
            title: "Stress Detection",
            description: "Using your Apple Watch heart rate data, PhysioTwin detects stress in real-time through a 3-stage ML pipeline analyzing your heart rate variability.",
            detail: "An Apple Watch is required for accurate stress tracking."
        ),
        WalkthroughPage(
            icon: "moon.stars.fill",
            iconColor: .ptInfo,
            title: "Sleep Recovery",
            description: "Better sleep means better recovery. Your overnight HRV, heart rate, and sleep stages are analyzed to calculate how much battery you recharge.",
            detail: "Wear your watch to sleep for the best results."
        ),
        WalkthroughPage(
            icon: "figure.mind.and.body",
            iconColor: .ptMint,
            title: "Recovery Activities",
            description: "When your battery is low, try guided breathing, meditation, or a walk. PhysioTwin tracks your metrics during these sessions to show real improvement.",
            detail: "Tap any recovery activity to start a timed session."
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    walkthroughPageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)
            
            // Bottom controls
            VStack(spacing: 20) {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.ptTeal : Color(.systemGray4))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                
                // Action button
                Button(action: {
                    HapticManager.medium()
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        isPresented = false
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.ptTeal, .ptTealLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                
                // Skip button
                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        isPresented = false
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .interactiveDismissDisabled()
    }
    
    @ViewBuilder
    private func walkthroughPageView(_ page: WalkthroughPage) -> some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                
                Image(systemName: page.icon)
                    .font(.system(size: 48))
                    .foregroundColor(page.iconColor)
            }
            
            // Text
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Text(page.detail)
                    .font(.caption)
                    .foregroundColor(.ptMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
            }
            
            Spacer()
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(page.title). \(page.description)")
    }
}

// MARK: - Walkthrough Page Model
private struct WalkthroughPage {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let detail: String
}

#Preview {
    OnboardingWalkthroughView(isPresented: .constant(true))
}
