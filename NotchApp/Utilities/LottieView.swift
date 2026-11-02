import SwiftUI
import Lottie
import AppKit

// UI-6: LottieView — correctly sized and transparent on macOS.
//
// Root cause of the "always big" bug:
//   LottieAnimationView overrides -layout on macOS and resets its own frame to
//   the composition's intrinsic size (280×200 for Loader_cat) every time the
//   view tree is laid out. SwiftUI's .frame() modifier only reserves a layout
//   slot; it never calls setFrameSize on the NSView again after Lottie resets it.
//
// Fix:
//   Wrap LottieAnimationView inside a plain NSView container whose frame IS
//   controlled by Auto Layout constraints we set ourselves. The container clips
//   its bounds, so whatever Lottie does internally stays invisible outside the
//   requested size. We pin Lottie's center to the container's center and let
//   .scaleAspectFit scale the composition down to fill the container.

struct LottieView: NSViewRepresentable {
    let name: String
    var loop: Bool = true
    var animationSpeed: CGFloat = 1.0
    /// UI-6: the rendered square side length in points.
    /// Controlled by IslandLayout.collapsedLottieSize — change that one constant.
    var size: CGFloat = IslandLayout.collapsedLottieSize

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSView {
        let container = ClippingView(frame: NSRect(x: 0, y: 0, width: size, height: size))

        let lottie = LottieAnimationView(
            animation: LottieAnimation.named(name, bundle: .main),
            configuration: LottieConfiguration(renderingEngine: .automatic)
        )
        lottie.loopMode       = loop ? .loop : .playOnce
        lottie.animationSpeed = animationSpeed
        lottie.contentMode    = .scaleAspectFit   // scale 280×200 down to fit

        // UI-6: transparent — strip opaque backing from both the lottie view and
        // its layer before and after play() because the SDK resets it on first render.
        applyTransparency(to: lottie)
        lottie.backgroundBehavior = .pauseAndRestore
        lottie.play()
        applyTransparency(to: lottie)

        // UI-6: use Auto Layout so Lottie cannot escape the container.
        lottie.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(lottie)
        NSLayoutConstraint.activate([
            lottie.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            lottie.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            lottie.widthAnchor.constraint(equalToConstant: size),
            lottie.heightAnchor.constraint(equalToConstant: size),
        ])

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let container = nsView as? ClippingView,
              let lottie = container.subviews.first as? LottieAnimationView else { return }

        lottie.loopMode       = loop ? .loop : .playOnce
        lottie.animationSpeed = animationSpeed

        // UI-6: resize constraints when size changes.
        for c in lottie.constraints where c.firstAttribute == .width || c.firstAttribute == .height {
            c.constant = size
        }
        container.frame.size = NSSize(width: size, height: size)
        applyTransparency(to: lottie)
    }

    // MARK: - Helpers

    private func applyTransparency(to view: LottieAnimationView) {
        view.wantsLayer             = true
        view.layer?.isOpaque        = false
        view.layer?.backgroundColor = CGColor.clear
    }
}

// MARK: - ClippingView

/// A plain NSView that clips its bounds so LottieAnimationView cannot paint
/// outside the requested size even if it resets its own frame internally.
private final class ClippingView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer             = true
        layer?.masksToBounds   = true
        layer?.isOpaque        = false
        layer?.backgroundColor = CGColor.clear
    }
    required init?(coder: NSCoder) { fatalError() }

    // UI-6: report exact intrinsic size so SwiftUI's layout system honours it.
    override var intrinsicContentSize: NSSize {
        return frame.size
    }
}
