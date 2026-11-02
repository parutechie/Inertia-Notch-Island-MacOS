import AppKit
import CoreImage
import Foundation
import SwiftUI

/// Extracts a dark, usable tint from the current artwork. The average colour is
/// deliberately used instead of a histogram peak: album art is usually busy, and
/// an average gives the calm "dark olive" wash seen behind the collapsed island.
@MainActor
enum ArtworkTint {
    private static var cache: [String: Color] = [:]
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func color(for url: URL?) async -> Color? {
        guard let url else { return nil }
        let key = url.absoluteString
        if let cached = cache[key] { return cached }

        do {
            // Album art is often a file URL from Music/Spotify, which URLSession
            // does not load; read local files directly.
            let data: Data
            if url.isFileURL {
                data = try Data(contentsOf: url)
            } else {
                data = try await URLSession.shared.data(from: url).0
            }
            guard !Task.isCancelled,
                  let image = NSImage(data: data),
                  let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  let filter = CIFilter(name: "CIAreaAverage") else { return nil }

            let input = CIImage(cgImage: cg)
            filter.setValue(input, forKey: kCIInputImageKey)
            filter.setValue(CIVector(cgRect: input.extent), forKey: kCIInputExtentKey)
            guard let output = filter.outputImage else { return nil }

            var pixels = [UInt8](repeating: 0, count: 4)
            pixels.withUnsafeMutableBytes { buffer in
                context.render(output,
                               toBitmap: buffer.baseAddress!,
                               rowBytes: 4,
                               bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                               format: .RGBA8,
                               colorSpace: CGColorSpaceCreateDeviceRGB())
            }

            let color = Color(.sRGB,
                              red: Double(pixels[0]) / 255,
                              green: Double(pixels[1]) / 255,
                              blue: Double(pixels[2]) / 255,
                              opacity: 1)
            cache[key] = color
            return color
        } catch {
            return nil
        }
    }
}
