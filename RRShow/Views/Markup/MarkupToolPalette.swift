import SwiftUI

/// The floating palette: three tools, four colours, and a way to wipe the slide.
struct MarkupToolPalette: View {

    @Environment(PresentationViewModel.self) private var model

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MarkupTool.allCases) { tool in
                button(
                    systemImage: tool.systemImage,
                    isSelected: model.markupTool == tool,
                    help: tool.displayName
                ) {
                    model.markupTool = tool
                }
                .accessibilityIdentifier(AccessibilityID.Markup.tool(tool.rawValue))
            }

            divider

            ForEach(MarkupColor.allCases) { color in
                colorButton(color)
            }

            divider

            button(
                systemImage: "trash",
                isSelected: false,
                help: "Clear marks on this slide"
            ) {
                model.clearCurrentMarkup()
            }
            .disabled(!model.hasMarkupOnCurrentSlide)
            .accessibilityIdentifier(AccessibilityID.Markup.clearSlide)

            settingsMenu
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            Capsule(style: .continuous)
                .fill(PresenterPalette.floating)
                .overlay {
                    Capsule(style: .continuous).strokeBorder(.white.opacity(0.12))
                }
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 3)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.18))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 2)
    }

    private func button(
        systemImage: String,
        isSelected: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.white.opacity(0.75)))
                .frame(width: 30, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? .white.opacity(0.16) : .clear)
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func colorButton(_ color: MarkupColor) -> some View {
        Button {
            model.markupColor = color
            // Picking a colour while erasing clearly means "go back to drawing".
            if model.markupTool == .eraser { model.markupTool = .pen }
        } label: {
            Circle()
                .fill(color.color)
                .frame(width: 18, height: 18)
                .overlay {
                    Circle()
                        .strokeBorder(.white, lineWidth: model.markupColor == color ? 2 : 0)
                }
                .padding(4)
        }
        .buttonStyle(.plain)
        .help(color.rawValue.capitalized)
    }

    private var settingsMenu: some View {
        Menu {
            Picker("When the slide changes", selection: Bindable(model).markupPersistence) {
                ForEach(MarkupPersistence.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }

            Toggle("Apple Pencil Only", isOn: Bindable(model).markupPencilOnly)

            Divider()

            Button(role: .destructive) {
                model.clearAllMarkup()
            } label: {
                Label("Clear Marks on All Slides", systemImage: "trash.slash")
            }
            .disabled(!model.hasAnyMarkup)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 30, height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}
