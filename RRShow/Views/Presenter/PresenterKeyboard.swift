import SwiftUI
import UIKit

/// Everything the presenter can do from a key.
enum PresenterCommand: Sendable {
    case next
    case previous
    case first
    case last
    case blackScreen
    case whiteScreen
    case clearBlank
    case toggleThumbnails
    case toggleMarkup
    case clearMarkup
    case toggleLaser
    case toggleTimer
}

/// Hardware keyboard and presenter-remote handling.
///
/// Clicker remotes almost universally present themselves as keyboards sending arrow keys
/// or Page Up / Page Down, so covering the standard key set covers the hardware too.
///
/// This goes through UIKit rather than SwiftUI's `onKeyPress` or `keyboardShortcut`
/// because neither can claim the arrow keys. UIKit's focus engine reserves the arrows
/// (and space, Page Up/Down and Return) for moving focus between on-screen controls and
/// consumes them before either SwiftUI mechanism is consulted — verified on Mac
/// Catalyst, where `b` and `End` arrived but the arrows never did. `UIKeyCommand`'s
/// `wantsPriorityOverSystemBehavior` is the documented way to take them back, and
/// SwiftUI does not expose it.
struct PresenterKeyboardShortcuts: ViewModifier {

    @Environment(PresentationViewModel.self) private var model

    func body(content: Content) -> some View {
        content
            .background {
                PresenterKeyCommandHost { command in
                    perform(command)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }

    private func perform(_ command: PresenterCommand) {
        switch command {
        case .next:
            model.goToNextPage()
        case .previous:
            model.goToPreviousPage()
        case .first:
            model.goToFirstPage()
        case .last:
            model.goToLastPage()
        case .blackScreen:
            withAnimation(.easeOut(duration: 0.15)) { model.toggleBlank(.black) }
        case .whiteScreen:
            withAnimation(.easeOut(duration: 0.15)) { model.toggleBlank(.white) }
        case .clearBlank:
            guard model.isBlanked else { return }
            withAnimation(.easeOut(duration: 0.15)) { model.clearBlank() }
        case .toggleThumbnails:
            withAnimation(.snappy(duration: 0.2)) { model.toggleThumbnailBar() }
        case .toggleMarkup:
            withAnimation(.snappy(duration: 0.2)) { model.toggleMarkup() }
        case .clearMarkup:
            model.clearCurrentMarkup()
        case .toggleLaser:
            withAnimation(.snappy(duration: 0.2)) { model.toggleLaser() }
        case .toggleTimer:
            model.timer.toggle()
        }
    }
}

extension View {
    func presenterKeyboardShortcuts() -> some View {
        modifier(PresenterKeyboardShortcuts())
    }
}

// MARK: - UIKit bridge

private struct PresenterKeyCommandHost: UIViewRepresentable {

    let onCommand: (PresenterCommand) -> Void

    func makeUIView(context: Context) -> PresenterKeyCommandView {
        let view = PresenterKeyCommandView()
        view.onCommand = onCommand
        return view
    }

    func updateUIView(_ view: PresenterKeyCommandView, context: Context) {
        view.onCommand = onCommand
        // Something else may have taken first responder — a slider drag, say. Key
        // commands are collected from the responder chain, so take it back.
        if view.window != nil, !view.isFirstResponder {
            view.becomeFirstResponder()
        }
    }
}

private final class PresenterKeyCommandView: UIView {

    var onCommand: ((PresenterCommand) -> Void)?

    /// Every key that drives the presentation, in responder-chain order.
    private static let bindings: [(input: String, command: PresenterCommand)] = [
        (UIKeyCommand.inputRightArrow, .next),
        (UIKeyCommand.inputDownArrow, .next),
        (UIKeyCommand.inputPageDown, .next),
        (" ", .next),
        ("\r", .next),
        ("n", .next),

        (UIKeyCommand.inputLeftArrow, .previous),
        (UIKeyCommand.inputUpArrow, .previous),
        (UIKeyCommand.inputPageUp, .previous),
        ("\u{8}", .previous),
        ("p", .previous),

        (UIKeyCommand.inputHome, .first),
        (UIKeyCommand.inputEnd, .last),

        ("b", .blackScreen),
        (".", .blackScreen),
        ("w", .whiteScreen),
        (",", .whiteScreen),
        ("t", .toggleThumbnails),
        ("m", .toggleMarkup),
        ("c", .clearMarkup),
        ("l", .toggleLaser),
        ("r", .toggleTimer),
        (UIKeyCommand.inputEscape, .clearBlank),
    ]

    private lazy var commands: [UIKeyCommand] = Self.bindings.indices.map { index in
        // `propertyList` is read-only, so it has to be supplied at construction; it
        // carries the index back to the handler. An empty title keeps these off the
        // ⌘-key HUD, which nineteen single-key entries would otherwise fill.
        let command = UIKeyCommand(
            title: "",
            image: nil,
            action: #selector(handleKeyCommand(_:)),
            input: Self.bindings[index].input,
            modifierFlags: [],
            propertyList: index
        )
        // Without this the focus engine keeps the arrows, space and Return for itself.
        command.wantsPriorityOverSystemBehavior = true
        return command
    }

    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? { commands }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            becomeFirstResponder()
        }
    }

    @objc private func handleKeyCommand(_ command: UIKeyCommand) {
        guard let index = command.propertyList as? Int,
              Self.bindings.indices.contains(index) else { return }
        onCommand?(Self.bindings[index].command)
    }
}
