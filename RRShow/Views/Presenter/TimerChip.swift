import SwiftUI

/// Elapsed time, the wall clock, and the controls for both.
///
/// Tapping runs or pauses — the thing a presenter does most and should not have to aim
/// for. Everything else is behind a long press.
struct TimerChip: View {

    @Environment(PresentationViewModel.self) private var model

    private var timer: PresentationTimer { model.timer }

    var body: some View {
        Menu {
            menuContent
        } label: {
            chip
        } primaryAction: {
            timer.toggle()
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    private var chip: some View {
        HStack(spacing: 8) {
            Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(timer.elapsedText)
                .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundStyle(pacingStyle)

            Divider().frame(height: 16)

            Text(timer.now, format: .dateTime.hour().minute())
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule().fill(.quaternary.opacity(0.4))
        }
        .contentShape(.capsule)
    }

    private var pacingStyle: AnyShapeStyle {
        switch timer.pacing {
        case .untimed, .onTrack:
            timer.isRunning ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)
        case .nearingEnd:
            AnyShapeStyle(Color.orange)
        case .overrun:
            AnyShapeStyle(Color.red)
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        Section {
            Button {
                timer.toggle()
            } label: {
                Label(timer.isRunning ? "Pause" : "Start", systemImage: timer.isRunning ? "pause" : "play")
            }

            Button {
                timer.reset()
            } label: {
                Label("Reset to Zero", systemImage: "arrow.counterclockwise")
            }
        }

        if let remaining = timer.remaining {
            Section {
                Text(
                    remaining >= 0
                        ? "\(PresentationTimer.format(remaining)) remaining"
                        : "\(PresentationTimer.format(remaining)) over"
                )
            }
        }

        Section("Talk Length") {
            Button {
                timer.targetDuration = nil
            } label: {
                Label("No Target", systemImage: timer.targetDuration == nil ? "checkmark" : "infinity")
            }

            ForEach(PresentationTimer.targetChoices, id: \.self) { minutes in
                let duration = TimeInterval(minutes * 60)
                Button {
                    timer.targetDuration = duration
                } label: {
                    Label(
                        "\(minutes) minutes",
                        systemImage: timer.targetDuration == duration ? "checkmark" : "clock"
                    )
                }
            }
        }
    }
}
