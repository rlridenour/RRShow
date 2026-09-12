import Foundation
import Observation

/// Elapsed time and wall clock for the presenter.
///
/// Elapsed time is derived from timestamps rather than accumulated per tick, so it stays
/// accurate whether the tick fires on time, late, or not at all while the app is
/// backgrounded.
@MainActor
@Observable
final class PresentationTimer {

    private(set) var elapsed: TimeInterval = 0
    private(set) var now = Date()
    private(set) var isRunning = false

    /// Optional length to pace against. Drives the colour of the readout.
    var targetDuration: TimeInterval? {
        didSet { Self.store(targetDuration) }
    }

    private var accumulated: TimeInterval = 0
    private var startedAt: Date?
    private var ticker: Task<Void, Never>?

    /// Offered talk lengths, in minutes.
    static let targetChoices: [Int] = [10, 15, 20, 30, 45, 50, 60, 75, 90]

    init() {
        targetDuration = Self.restoredTarget()
        startClock()
    }

    // MARK: - Control

    func start() {
        guard !isRunning else { return }
        startedAt = Date()
        isRunning = true
        refresh()
    }

    func pause() {
        guard isRunning, let startedAt else { return }
        accumulated += Date().timeIntervalSince(startedAt)
        self.startedAt = nil
        isRunning = false
        refresh()
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func reset() {
        accumulated = 0
        startedAt = isRunning ? Date() : nil
        refresh()
    }

    /// Stops and zeroes — used when a deck closes.
    func stop() {
        accumulated = 0
        startedAt = nil
        isRunning = false
        refresh()
    }

    // MARK: - Readout

    var elapsedText: String { Self.format(elapsed) }

    var remaining: TimeInterval? {
        guard let targetDuration else { return nil }
        return targetDuration - elapsed
    }

    /// 0...1 against the target, or `nil` when no target is set. Can exceed 1.
    var progress: Double? {
        guard let targetDuration, targetDuration > 0 else { return nil }
        return elapsed / targetDuration
    }

    enum Pacing: Sendable {
        case untimed
        case onTrack
        /// Inside the last fifth of the allotted time.
        case nearingEnd
        case overrun
    }

    var pacing: Pacing {
        guard let progress else { return .untimed }
        if progress >= 1 { return .overrun }
        if progress >= 0.8 { return .nearingEnd }
        return .onTrack
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = Int(abs(interval).rounded(.down))
        let sign = interval < 0 ? "−" : ""
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%@%d:%02d:%02d", sign, hours, minutes, seconds)
            : String(format: "%@%d:%02d", sign, minutes, seconds)
    }

    // MARK: - Ticking

    private func startClock() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            // The weak capture is what stops this loop: once the timer is gone the
            // next wake-up returns. (A `@MainActor deinit` is nonisolated in Swift 6
            // and cannot reach `ticker` to cancel it.)
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self else { return }
                self.refresh()
            }
        }
    }

    private func refresh() {
        now = Date()
        elapsed = accumulated + (startedAt.map { now.timeIntervalSince($0) } ?? 0)
    }

    // MARK: - Persistence

    private static let targetKey = "presenter.timer.target"

    private static func restoredTarget() -> TimeInterval? {
        let stored = UserDefaults.standard.double(forKey: targetKey)
        return stored > 0 ? stored : nil
    }

    private static func store(_ target: TimeInterval?) {
        UserDefaults.standard.set(target ?? 0, forKey: targetKey)
    }
}
