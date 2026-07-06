import AppKit
import SwiftUI

/// The small floating pill shown near the bottom of the screen while
/// recording / transcribing, like Wispr Flow's indicator.
@MainActor
final class OverlayIndicator {
    enum Phase: Equatable {
        case recording
        case transcribing
        case success(String)
        case error(String)
    }

    private let model = OverlayModel()
    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    func show(_ phase: Phase) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        model.phase = phase
        if phase == .recording {
            model.levels = Array(repeating: 0.05, count: OverlayModel.barCount)
        }
        ensurePanel()
        panel?.orderFrontRegardless()

        // Success / error states auto-dismiss.
        switch phase {
        case .success, .error:
            scheduleHide(after: 1.6)
        default:
            break
        }
    }

    func pushLevel(_ level: Float) {
        guard model.phase == .recording else { return }
        model.levels.removeFirst()
        model.levels.append(max(0.05, CGFloat(level)))
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        panel?.orderOut(nil)
    }

    private func scheduleHide(after delay: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func ensurePanel() {
        if panel == nil {
            let size = NSSize(width: 240, height: 48)
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .statusBar
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.contentView = NSHostingView(rootView: OverlayView(model: model))
            self.panel = panel
        }
        positionPanel()
    }

    private func positionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + 60
        )
        panel.setFrameOrigin(origin)
    }
}

@MainActor
final class OverlayModel: ObservableObject {
    static let barCount = 18
    @Published var phase: OverlayIndicator.Phase = .recording
    @Published var levels: [CGFloat] = Array(repeating: 0.05, count: OverlayModel.barCount)
}

struct OverlayView: View {
    @ObservedObject var model: OverlayModel

    var body: some View {
        HStack(spacing: 10) {
            switch model.phase {
            case .recording:
                Circle()
                    .fill(Color.red)
                    .frame(width: 9, height: 9)
                LevelBars(levels: model.levels)
                Text("Listening…")
                    .font(.system(size: 13, weight: .medium))
            case .transcribing:
                ProgressView()
                    .controlSize(.small)
                Text("Transcribing…")
                    .font(.system(size: 13, weight: .medium))
            case .success(let message):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(message)
                    .font(.system(size: 13, weight: .medium))
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LevelBars: View {
    let levels: [CGFloat]

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(levels.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary.opacity(0.75))
                    .frame(width: 2.5, height: 4 + levels[i] * 16)
            }
        }
        .animation(.linear(duration: 0.08), value: levels)
    }
}
