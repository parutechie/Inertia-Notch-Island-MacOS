import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Shelf / clipboard history

private enum ShelfFilter: String, CaseIterable, Identifiable {
    case all, text, links, images, files
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .text: return "Text"
        case .links: return "Links"
        case .images: return "Images"
        case .files: return "Files"
        }
    }
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .text: return "text.alignleft"
        case .links: return "link"
        case .images: return "photo"
        case .files: return "doc"
        }
    }
    func matches(_ item: ClipItem) -> Bool {
        switch self {
        case .all: return true
        case .text: return item.kind == .text
        case .links: return item.kind == .link
        case .images: return item.kind == .image
        case .files: return item.kind == .files
        }
    }
}

struct ShelfView: View {
    @ObservedObject var store = Store.shared
    @ObservedObject private var clip = ClipboardManager.shared
    @State private var filter = ShelfFilter.all
    @State private var dropTarget = false

    private let tint = IslandTab.shelf.tint

    private var shown: [ClipItem] {
        clip.filtered.filter(filter.matches)
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }

    var body: some View {
        VStack(spacing: IslandLayout.verticalSpacing) {
            header
            if shown.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(shown) { item in
                            ShelfCard(item: item)
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                    // FIX 2B: 16pt bottom so last card clears the panel's rounded corners.
                    .padding(.bottom, 16)
                }
                // Soft 24pt bottom fade so a partially visible card row looks
                // intentionally clipped instead of cut off.
                .mask(
                    VStack(spacing: 0) {
                        Rectangle().fill(.black)
                        LinearGradient(colors: [.black, .clear],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 24)
                    }
                )
                .animation(.inertiaLiquid(speed: store.animSpeed, reduceMotion: false), value: clip.items)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(dropTarget ? tint.opacity(0.13) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(dropTarget ? tint.opacity(0.75) : Color.clear, style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
        )
        .onDrop(of: [.fileURL, .image, .plainText, .text], isTargeted: $dropTarget) { providers in
            ingest(providers)
            return true
        }
    }

    private var header: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    TextField("Search the shelf", text: $clip.query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                    if !clip.query.isEmpty {
                        Button { clip.query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.45))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 7).glass(14)

                if !clip.items.isEmpty {
                    Button {
                        clip.clear()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(width: 28, height: 28).glass(14)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Clear unpinned items")
                }
            }

            HStack(spacing: 5) {
                ForEach(ShelfFilter.allCases) { f in
                    Chip(text: f.title, on: filter == f, tint: tint) {
                        withAnimation(.easeOut(duration: 0.15)) { filter = f }
                    }
                }
                Spacer(minLength: 2)
                Image(systemName: clip.pinnedCount > 0 ? "pin.fill" : "tray.full.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tint.opacity(0.8))
                Text("\(clip.items.count)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 7) {
            Spacer()
            Image(systemName: clip.query.isEmpty ? "tray.full" : "magnifyingglass")
                .font(.system(size: 24)).foregroundStyle(tint)
            Text(clip.query.isEmpty
                 ? "Copy something or drop files here."
                 : "Nothing matches “\(clip.query)”.")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
            if clip.query.isEmpty {
                Text("Text, links, images and files stay for this session.")
                    .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.35))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ingest(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    guard let data else { return }
                    var url: URL?
                    if let data = data as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                    else if let string = data as? String { url = URL(string: string) }
                    else if let nsurl = data as? NSURL { url = nsurl as URL }
                    guard let url, url.isFileURL else { return }
                    DispatchQueue.main.async {
                        ClipboardManager.shared.addFiles([url], appName: "Dropped")
                    }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                    guard let image = object as? NSImage else { return }
                    DispatchQueue.main.async {
                        ClipboardManager.shared.addImage(image, appName: "Dropped")
                    }
                }
            } else if provider.canLoadObject(ofClass: NSString.self) {
                _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                    guard let string = object as? String,
                          !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    DispatchQueue.main.async {
                        let kind: ClipKind = string.hasPrefix("http://") || string.hasPrefix("https://") ? .link : .text
                        ClipboardManager.shared.add(ClipItem(kind: kind, text: string, appName: "Dropped"))
                    }
                }
            }
        }
    }
}

// MARK: - Card
private struct ShelfCard: View {
    let item: ClipItem
    @ObservedObject private var clip = ClipboardManager.shared

    private var tint: Color { IslandTab.shelf.tint }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                thumbnail
                VStack(alignment: .leading, spacing: 1) {
                    Text(kindTitle)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(tint.opacity(0.9))
                    Text(item.appName.isEmpty ? relativeTime : "\(item.appName) · \(relativeTime)")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if item.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(tint)
                }
            }

            Text(item.preview.isEmpty ? "Image" : item.preview)
                .font(.system(size: 11.5, weight: item.kind == .link ? .medium : .regular))
                .foregroundStyle(item.kind == .link ? tint : .white.opacity(0.86))
                .lineLimit(item.kind == .files ? 3 : 3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                cardButton("doc.on.doc", help: "Copy") { clip.copyToClipboard(item) }
                cardButton("arrow.down.doc", help: "Paste into the active app") { clip.paste(item) }
                Spacer()
                Menu {
                    Button(item.pinned ? "Unpin" : "Pin") { clip.togglePin(item) }
                    Button("Delete", role: .destructive) { clip.remove(item) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 24, height: 20)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 118, maxHeight: 118, alignment: .topLeading)
        .inertiaGlassBackground(cornerRadius: 13, showsStroke: true, tint: tint, gloss: 0.7)
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onTapGesture(count: 2) { clip.paste(item) }
        .onDrag { provider }
        .contextMenu {
            Button("Copy") { clip.copyToClipboard(item) }
            Button("Paste") { clip.paste(item) }
            Button(item.pinned ? "Unpin" : "Pin") { clip.togglePin(item) }
            Button("Delete", role: .destructive) { clip.remove(item) }
        }
    }

    @ViewBuilder private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.14))
            switch item.kind {
            case .image:
                if let image = clip.image(for: item) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    Image(systemName: "photo").font(.system(size: 13)).foregroundStyle(tint)
                }
            case .files:
                if let icon = clip.fileIcon(for: item) {
                    Image(nsImage: icon).resizable().scaledToFit().padding(4)
                } else {
                    Image(systemName: "doc").font(.system(size: 13)).foregroundStyle(tint)
                }
            case .link:
                Image(systemName: "link").font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
            case .text:
                Image(systemName: "text.alignleft").font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
            }
        }
        .frame(width: 30, height: 30)
    }

    private func cardButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 24, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var kindTitle: String {
        switch item.kind {
        case .text: return "TEXT"
        case .link: return "LINK"
        case .image: return "IMAGE"
        case .files: return "FILE"
        }
    }

    private var relativeTime: String {
        item.timestamp.formatted(.relative(presentation: .named))
    }

    private var provider: NSItemProvider {
        switch item.kind {
        case .text, .link:
            return NSItemProvider(object: (item.text ?? "") as NSString)
        case .image:
            if let image = clip.image(for: item) { return NSItemProvider(object: image) }
            return NSItemProvider()
        case .files:
            if let first = item.fileURLs?.first, let url = URL(string: first) {
                return NSItemProvider(contentsOf: url) ?? NSItemProvider()
            }
            return NSItemProvider()
        }
    }
}
