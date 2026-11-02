import SwiftUI

// MARK: - Launcher tab

struct LauncherView: View {
    @ObservedObject var store = Store.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editing = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    private var liquid: Animation {
        .inertiaLiquid(speed: store.animSpeed, reduceMotion: reduceMotion)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                grid
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .opacity(store.showMenu ? 0.34 : 1)
                    .scaleEffect(store.showMenu ? 0.985 : 1, anchor: .topLeading)
                    .allowsHitTesting(!store.showMenu)

                if store.showMenu {
                    Color.black.opacity(0.40)
                        .contentShape(Rectangle())
                        .onTapGesture { closeMenu() }
                        .transition(.opacity)
                        .zIndex(1)

                    LauncherMenuCard { tool in
                        withAnimation(liquid) {
                            store.pinLauncher(tool)
                            store.showMenu = false
                        }
                    } openSettings: {
                        // FIX 6: open Settings window and collapse island.
                        store.showMenu = false
                        SettingsWindowController.shared.show()
                    }
                    .frame(width: IslandLayout.menuWidth,
                           height: max(geo.size.height - IslandLayout.launcherTopInset - 4, 0))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, IslandLayout.launcherTopInset)
                    .padding(.bottom, 4)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                    .zIndex(2)
                }
            }
            .clipped()
            .animation(liquid, value: store.showMenu)
        }
        .onChange(of: store.tab) { _, _ in store.showMenu = false }
        .onDisappear { store.showMenu = false }
    }

    private var grid: some View {
        // BUG 4 fix: PINNED label + Edit pill in one HStack row above the grid.
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("PINNED")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.32))
                    .tracking(0.7)
                Spacer(minLength: 0)
                // BUG 4: Edit pill sits in the PINNED row, not floating over background.
                Button(editing ? "Done" : "Edit") {
                    withAnimation(liquid) { editing.toggle() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(editing ? IslandTab.launcher.tint : .white.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(.white.opacity(editing ? 0.10 : 0.06)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
                .contentShape(Capsule())
            }
            .frame(height: 18)

            // BUG 4: ScrollView with hidden indicators + 16pt bottom padding so
            // nothing is clipped; content anchored to top.
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(store.launcherPins.enumerated()), id: \.element.id) { index, tool in
                        LauncherTile(tool: tool,
                                     index: index,
                                     editing: editing,
                                     open: { open(tool) },
                                     remove: { remove(tool) })
                            .transition(.scale(scale: 0.78).combined(with: .opacity))
                    }
                    AddLauncherTile {
                        withAnimation(liquid) { store.showMenu = true }
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, 16)
                .animation(liquid, value: store.launcherPins)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .scrollIndicators(.hidden)
        }
        .padding(.top, IslandLayout.launcherTopInset)
    }

    private func open(_ tool: LauncherTool) {
        guard !editing else { return }
        store.showMenu = false
        withAnimation(liquid) {
            store.tab = tool.tab
        }
    }

    private func remove(_ tool: LauncherTool) {
        withAnimation(liquid) {
            store.unpinLauncher(tool)
        }
    }

    private func closeMenu() {
        withAnimation(liquid) {
            store.showMenu = false
        }
    }
}

// MARK: - Grid items

private struct LauncherTile: View {
    let tool: LauncherTool
    let index: Int
    let editing: Bool
    let open: () -> Void
    let remove: () -> Void
    @ObservedObject var store = Store.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hover = false
    @State private var appeared = false

    private var liquid: Animation {
        .inertiaLiquid(speed: store.animSpeed, reduceMotion: reduceMotion)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Button(action: open) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [tool.color, tool.color.opacity(0.74)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: tool.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(.white.opacity(0.20), lineWidth: 0.6)
                        )
                        .shadow(color: tool.color.opacity(hover ? 0.42 : 0.18), radius: hover ? 8 : 4, y: 3)
                        .scaleEffect(hover ? 1.05 : 1)
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(InertiaPressStyle(speed: store.animSpeed))
                .help(tool.title)

                if editing {
                    Button(action: remove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundStyle(.black)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(.white))
                            .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: 0.6))
                            .contentShape(Circle())
                    }
                    .buttonStyle(InertiaPressStyle(speed: store.animSpeed))
                    .offset(x: 5, y: -5)
                    .help("Remove \(tool.title)")
                }
            }
            .frame(width: 64, height: 64)

            Text(tool.title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.86)
        .onHover { hover = $0 }
        .animation(liquid, value: hover)
        .onAppear {
            let delay = reduceMotion ? 0 : Double(index) * 0.04
            let animation = reduceMotion
                ? Animation.easeInOut(duration: 0.18)
                : Animation.inertiaLiquid(speed: store.animSpeed, reduceMotion: false).delay(delay)
            withAnimation(animation) { appeared = true }
        }
    }
}

private struct AddLauncherTile: View {
    let action: () -> Void
    @ObservedObject var store = Store.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hover = false

    var body: some View {
        // BUG 4 fix: identical structure to LauncherTile —
        // a 64×64 rounded-square glass tile + "Add" label below.
        VStack(spacing: 6) {
            Button(action: action) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(hover ? 0.13 : 0.065))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white.opacity(hover ? 0.9 : 0.62))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(hover ? 0.18 : 0.10), lineWidth: 0.8)
                    )
                    .scaleEffect(hover ? 1.05 : 1)
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(InertiaPressStyle(speed: store.animSpeed))
            .help("Add a tool")

            Text("Add")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .onHover { hover = $0 }
        .animation(.inertiaLiquid(speed: store.animSpeed, reduceMotion: reduceMotion), value: hover)
    }
}

// MARK: - Add menu (FIX 3 + FIX 6)

private struct LauncherMenuCard: View {
    let choose: (LauncherTool) -> Void
    let openSettings: () -> Void  // FIX 6: Settings row callback

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(Array(LauncherTool.menuOrder.enumerated()), id: \.element) { index, tool in
                        LauncherMenuRow(tool: tool, index: index) { choose(tool) }
                    }
                }
                .padding(.top, 6)
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
            }

            // FIX 6: hairline divider + Settings row at bottom.
            Divider().opacity(0.25)
            Button(action: openSettings) {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 22, alignment: .center)
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Settings")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(SettingsRowHoverBG())
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: IslandLayout.menuCornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: IslandLayout.menuCornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: IslandLayout.menuCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.38), radius: 18, x: 6, y: 10)
    }
}

// Thin hover background for the Settings row (avoids state duplication).
private struct SettingsRowHoverBG: View {
    @State private var hover = false
    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(hover ? Color.white.opacity(0.12) : Color.clear)
            .onHover { hover = $0 }
            .animation(.easeOut(duration: 0.14), value: hover)
    }
}

private struct LauncherMenuRow: View {
    let tool: LauncherTool
    let index: Int
    let action: () -> Void
    @ObservedObject var store = Store.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hover = false
    @State private var appeared = false

    private var liquid: Animation {
        .inertiaLiquid(speed: store.animSpeed, reduceMotion: reduceMotion)
    }

    var body: some View {
        Button(action: action) {
            // FIX 3: icon column left-aligned; label starts at same x across all rows.
            HStack(spacing: 10) {
                Image(systemName: tool.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, alignment: .center)
                    .foregroundStyle(.white.opacity(0.9))
                Text(tool.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(hover ? .white.opacity(0.12) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(InertiaPressStyle(speed: store.animSpeed))
        .onHover { hover = $0 }
        .animation(liquid, value: hover)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 14)
        .onAppear {
            let delay = reduceMotion ? 0 : Double(index) * 0.04
            let animation = reduceMotion
                ? Animation.easeInOut(duration: 0.18)
                : Animation.inertiaLiquid(speed: store.animSpeed, reduceMotion: false).delay(delay)
            withAnimation(animation) { appeared = true }
        }
    }
}
