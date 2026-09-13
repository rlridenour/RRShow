import SwiftUI

/// The presenter's screen: a configurable pane layout, a thumbnail strip, paging
/// controls, and full hardware-keyboard navigation.
struct PresenterView: View {

    @Environment(PresentationViewModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            PresenterLayoutContainer()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    if model.isMarkupEnabled {
                        MarkupToolPalette()
                            .padding(.bottom, 14)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

            if model.showsThumbnailBar, model.pageCount > 1 {
                Divider()
                SlideThumbnailBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Divider()
            TransportBar()
        }
        .background(PresenterPalette.background)
        .presenterKeyboardShortcuts()
        .toolbar { toolbarContent }
        .navigationTitle(model.title)
        #if !targetEnvironment(macCatalyst)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                model.closeDocument()
            } label: {
                Label("Close", systemImage: "xmark")
            }
            .accessibilityIdentifier(AccessibilityID.Presenter.close)
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { model.toggleMarkup() }
            } label: {
                Label(
                    "Markup",
                    systemImage: model.isMarkupEnabled ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle"
                )
            }
            .help("Draw on the slide (M)")
            .accessibilityIdentifier(AccessibilityID.Presenter.markupToggle)

            Button {
                withAnimation(.snappy(duration: 0.2)) { model.toggleLaser() }
            } label: {
                Label(
                    "Laser Pointer",
                    systemImage: model.isLaserEnabled
                        ? "dot.circle.and.hand.point.up.left.fill"
                        : "hand.point.up.left"
                )
            }
            .help("Laser pointer (L)")
            .accessibilityIdentifier(AccessibilityID.Presenter.laserToggle)

            Button {
                withAnimation(.snappy(duration: 0.2)) { model.toggleThumbnailBar() }
            } label: {
                Label(
                    "Thumbnails",
                    systemImage: model.showsThumbnailBar ? "rectangle.grid.1x2.fill" : "rectangle.grid.1x2"
                )
            }
            .help("Show or hide the slide strip (T)")
            .accessibilityIdentifier(AccessibilityID.Presenter.thumbnailsToggle)

            presenterLayoutMenu
            LayoutMenu()
        }
    }

    private var presenterLayoutMenu: some View {
        Menu {
            Section("Presenter Layout") {
                ForEach(PresenterLayoutMode.allCases) { mode in
                    Button {
                        model.layoutMode = mode
                    } label: {
                        Label(
                            mode.displayName,
                            systemImage: model.layoutMode == mode ? "checkmark" : mode.systemImage
                        )
                    }
                    .keyboardShortcut(
                        KeyEquivalent(Character("\(mode.shortcutNumber)")),
                        modifiers: .command
                    )
                }
            }

            if model.effectiveLayoutMode == .fullSlide, model.hasNotes {
                Section {
                    Button {
                        withAnimation(.snappy(duration: 0.25)) { model.toggleNotesDrawer() }
                    } label: {
                        Label(
                            model.isNotesDrawerExpanded ? "Hide Notes Drawer" : "Show Notes Drawer",
                            systemImage: model.isNotesDrawerExpanded ? "chevron.down" : "chevron.up"
                        )
                    }
                }
            }

            Section("Appearance") {
                ForEach(PresenterTheme.allCases) { theme in
                    Button {
                        model.theme = theme
                    } label: {
                        Label(
                            theme.displayName,
                            systemImage: model.theme == theme ? "checkmark" : theme.systemImage
                        )
                    }
                }
            }

            if model.isLayoutModeOverridden {
                Section {
                    Text("This deck has no notes frame, so it is showing full-slide.")
                }
            }
        } label: {
            Label("Presenter Layout", systemImage: model.effectiveLayoutMode.systemImage)
        }
    }
}
