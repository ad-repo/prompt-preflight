import AppKit
import SwiftUI

struct WindowLevelConfigurator: NSViewRepresentable {
    let isFloating: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            applyWindowLevel(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            applyWindowLevel(from: nsView)
        }
    }

    private func applyWindowLevel(from view: NSView) {
        guard let window = view.window else { return }
        window.level = isFloating ? .floating : .normal
    }
}
