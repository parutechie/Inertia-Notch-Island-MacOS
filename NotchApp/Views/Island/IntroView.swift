import SwiftUI
import WebKit

// MARK: - IntroView

/// Plays the animated "hello" intro under the physical notch.
/// Tap anywhere or press Esc to skip.
struct IntroView: View {
    let notchH: CGFloat
    @ObservedObject private var store = Store.shared

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Animation content — fills the full island area.
                // notchH is passed so the HTML can render the black top band itself.
                IntroWebView(notchH: notchH)
                    .frame(width: geo.size.width, height: geo.size.height)

                // Solid black top band sits on top to merge with the physical notch.
                Color.black
                    .frame(width: geo.size.width, height: notchH + 6)

                // Transparent hit area above the web view so a click anywhere
                // dismisses the intro instead of opening the panel.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { store.finishIntro() }
            }
        }
        // Tap anywhere to skip.
        .contentShape(Rectangle())
        .onTapGesture { store.finishIntro() }
        // Esc to skip is handled at the window level in AppDelegate.
    }
}

// MARK: - WKWebView wrapper

struct IntroWebView: NSViewRepresentable {
    let notchH: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "introDone")

        let wv = WKWebView(frame: .zero, configuration: config)
        // Transparent background so SwiftUI layers show through.
        wv.setValue(false, forKey: "drawsBackground")
        wv.layer?.backgroundColor = .clear
        wv.layer?.isOpaque = false
        wv.enclosingScrollView?.hasVerticalScroller = false
        wv.enclosingScrollView?.hasHorizontalScroller = false
        context.coordinator.webView = wv
        context.coordinator.startFallbackTimer()
        wv.loadHTMLString(IntroHTML.make(notchH: notchH), baseURL: nil)
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?
        private var fallbackTimer: Timer?

        func startFallbackTimer() {
            fallbackTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: false) { [weak self] _ in
                self?.finish()
            }
        }

        func userContentController(_ userContentController: WKUserContentController,
                                    didReceive message: WKScriptMessage) {
            if message.name == "introDone" { finish() }
        }

        private func finish() {
            fallbackTimer?.invalidate()
            fallbackTimer = nil
            DispatchQueue.main.async { Store.shared.finishIntro() }
        }
    }
}

// MARK: - HTML builder

enum IntroHTML {
    static func make(notchH: CGFloat = 32) -> String {
        // notchH + 6 is the black top band height in px
        let topBand = Int(notchH + 6)

        // Apple's hello: 5s animation with a 1.25s hold (25%), then draw.
        // Dismiss 0.8s after the draw finishes; the native fallback is 7s.
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }

        /* Black top band — merges seamlessly with the physical notch */
        .notch__band {
            position: absolute;
            top: 0; left: 0; right: 0;
            height: \(topBand)px;
            background: #000;
            z-index: 10;
        }

        /* Content area: black background, white handwriting */
        .stage {
            position: absolute;
            top: \(topBand)px; left: 0; right: 0; bottom: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            background: #000;
        }

        .hello__div {
            display: flex;
            justify-content: center;
            align-items: center;
            width: 100%;
            max-width: 600px;
            margin: 0 auto;
            padding: 0 12px;
        }

        .hello__svg {
            fill: none;
            stroke: #fff;
            stroke-linecap: round;
            stroke-miterlimit: 10;
            stroke-width: 48px;
            stroke-dasharray: 5800px;
            stroke-dashoffset: 5800px;
            animation: anim__hello linear 5s forwards;
            height: 140px;
            width: auto;
            max-width: 100%;
            display: block;
        }
        @keyframes anim__hello {
            0%   { stroke-dashoffset: 5800px; }
            25%  { stroke-dashoffset: 5800px; }
            100% { stroke-dashoffset: 0px; }
        }
        </style>
        </head>
        <body>
        <div class="notch__band"></div>
        <div class="stage">
            <div class="hello__div">
                \(helloSVG)
            </div>
        </div>
        <script>
        setTimeout(function() {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.introDone) {
                window.webkit.messageHandlers.introDone.postMessage(1);
            }
        }, 5800);
        </script>
        </body>
        </html>
        """
    }

    private static var helloSVG: String {
        """
        <svg class="hello__svg" viewBox="0 0 1230.94 414.57">
          <path d="M-293.58-104.62S-103.61-205.49-60-366.25c9.13-32.45,9-58.31,0-74-10.72-18.82-49.69-33.21-75.55,31.94-27.82,70.11-52.22,377.24-44.11,322.48s34-176.24,99.89-183.19c37.66-4,49.55,23.58,52.83,47.92a117.06,117.06,0,0,1-3,45.32c-7.17,27.28-20.47,97.67,33.51,96.86,66.93-1,131.91-53.89,159.55-84.49,31.1-36.17,31.1-70.64,19.27-90.25-16.74-29.92-69.47-33-92.79,16.73C62.78-179.86,98.7-93.8,159-81.63S302.7-99.55,393.3-269.92c29.86-58.16,52.85-114.71,46.14-150.08-7.44-39.21-59.74-54.5-92.87-8.7-47,65-61.78,266.62-34.74,308.53S416.62-58,481.52-130.31s133.2-188.56,146.54-256.23c14-71.15-56.94-94.64-88.4-47.32C500.53-375,467.58-229.49,503.3-127a73.73,73.73,0,0,0,23.43,33.67c25.49,20.23,55.1,16,77.46,6.32a111.25,111.25,0,0,0,30.44-19.87c37.73-34.23,29-36.71,64.58-127.53C724-284.3,785-298.63,821-259.13a71,71,0,0,1,13.69,22.56c17.68,46,6.81,80-6.81,107.89-12,24.62-34.56,42.72-61.45,47.91-23.06,4.45-48.37-.35-66.48-24.27a78.88,78.88,0,0,1-12.66-25.8c-14.75-51,4.14-88.76,11-101.41,6.18-11.39,37.26-69.61,103.42-42.24,55.71,23.05,100.66-23.31,100.66-23.31" transform="translate(311.08 476.02)" style="fill:none;stroke:#fff;stroke-linecap:round;stroke-miterlimit:10;stroke-width:35px"/>
        </svg>
        """
    }
}
