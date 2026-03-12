import AppKit
import SwiftUI

@MainActor
final class CaptionWindowController {
    private let panel: NSPanel

    init(model: ASRAppModel) {
        let rootView = CaptionOverlayView(model: model)
        let hostingView = NSHostingView(rootView: rootView)

        let panel = NSPanel(
            contentRect: NSRect(x: 220, y: 720, width: 760, height: 240),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.ignoresMouseEvents = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        self.panel = panel

        positionAtTopCenter()
    }

    func show() {
        positionAtTopCenter()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func updateAppearance(opacity: Double) {
        panel.alphaValue = min(max(opacity, 0.25), 1.0)
    }

    private func positionAtTopCenter() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let width = min(visibleFrame.width - 48, 860)
        let height: CGFloat = 250
        let x = visibleFrame.midX - (width / 2)
        let y = visibleFrame.maxY - height - 18
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
