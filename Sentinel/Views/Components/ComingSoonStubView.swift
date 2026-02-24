import SwiftUI

/// A reusable "Coming Soon" stub view for tabs that aren't implemented yet
struct ComingSoonStubView: View {
    let icon: String
    let title: String

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.primary)

                Text(title)
                    .font(Typography.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("Coming Soon")
                    .font(Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TabView {
        ComingSoonStubView(icon: "heart.fill", title: "Hope Box")
            .tabItem {
                Label("Hope Box", systemImage: "heart.fill")
            }

        ComingSoonStubView(icon: "shield.checkered", title: "Safety Plan")
            .tabItem {
                Label("Safety Plan", systemImage: "shield.checkered")
            }

        ComingSoonStubView(icon: "person.fill", title: "Profile")
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
    }
    .preferredColorScheme(.dark)
}
