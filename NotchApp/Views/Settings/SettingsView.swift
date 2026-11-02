import SwiftUI

// MARK: - Notch panel settings tab
// Just a launcher — all real settings live in the separate Settings window.
struct SettingsView: View {
    private let tint = IslandTab.settings.tint

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(
                    LinearGradient(colors: [IslandTab.tasks.tint, IslandTab.remind.tint],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "gearshape.2.fill").font(.system(size: 32)).foregroundStyle(.white)
            }
            .frame(width: 72, height: 72)

            VStack(spacing: 6) {
                Text("Inertia Settings").font(.system(size: 16, weight: .bold))
                Text("Opens in a dedicated window where you can manage all preferences, permissions and more.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320)
            }

            Button {
                SettingsWindowController.shared.show()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.forward.app.fill")
                    Text("Open Settings")
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 20).padding(.vertical, 9)
                .foregroundStyle(.black)
                .background(Capsule().fill(tint))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
