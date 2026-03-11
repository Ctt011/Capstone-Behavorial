import SwiftUI

struct ContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenWalkthrough") private var hasSeenWalkthrough = false
    @State private var showingWalkthrough = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                BodyBatteryView()
                    .environmentObject(healthKitManager)
            }
        }
        .environmentObject(healthKitManager)
        .onChange(of: healthKitManager.isAuthorized) { _, isAuthorized in
            if isAuthorized {
                hasCompletedOnboarding = true
                if !hasSeenWalkthrough {
                    // Show walkthrough after a brief delay for smooth transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showingWalkthrough = true
                    }
                }
            }
        }
        .onAppear {
            // Migrate users who already authorized before this update
            if healthKitManager.isAuthorized {
                hasCompletedOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showingWalkthrough) {
            OnboardingWalkthroughView(isPresented: $showingWalkthrough)
                .onDisappear {
                    hasSeenWalkthrough = true
                }
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var heartScale: CGFloat = 1.0
    @State private var heartOpacity: Double = 0.8
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.ptTeal.opacity(0.1))
                        .frame(width: 180, height: 180)
                        .scaleEffect(heartScale)
                        .opacity(heartOpacity)

                    Circle()
                        .fill(Color.ptTeal.opacity(0.15))
                        .frame(width: 140, height: 140)
                        .scaleEffect(heartScale * 0.9)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.ptTeal)
                        .scaleEffect(heartScale)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        heartScale = 1.15
                        heartOpacity = 0.4
                    }
                }

                VStack(spacing: 16) {
                    Text("PhysioTwin")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("Your physiological digital twin")
                        .font(.title3)
                        .foregroundColor(.ptTeal)

                    Text("Connect your health data to get personalized insights, track trends, and understand your daily wellness patterns.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                }

                Spacer()

                Button(action: {
                    HapticManager.medium()
                    healthKitManager.requestAuthorization()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.title2)
                        Text("Connect Apple Health")
                            .font(.headline)
                    }
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
                .padding(.bottom, 20)
                .accessibilityLabel("Connect Apple Health")
                .accessibilityHint("Grant access to your health data to enable body battery tracking")

                Text("Works with any wearable synced to Apple Health")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
}
