import SwiftUI

/// The presenter's screen: a configurable pane layout, a thumbnail strip, paging
/// controls, and full hardware-keyboard navigation.
struct PresenterView: View {

    @Environment(PresentationViewModel.self) private var model
    @Environment(\.openWindow) private var openWindow

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

            if showsAudienceWindowButton {
                Button {
                    openWindow(id: AudienceWindow.id)
                } label: {
                    Label("Audience Window", systemImage: "macwindow.on.rectangle")
                }
                .help("Open the audience window, then move it to the projector")
                .accessibilityIdentifier(AccessibilityID.Presenter.openAudienceWindow)
            }

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

    /// Offered whenever nothing has already claimed an audience scene.
    ///
    /// One rule covers both platforms: on iPad a connected display takes the scene and
    /// the button disappears; on the Mac no scene ever arrives, so it stays available.
    /// No `#if` needed, and it self-corrects if either platform's behaviour changes.
    private var showsAudienceWindowButton: Bool {
        !ExternalDisplayMonitor.shared.isConnected
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

            Section("Audience Display") {
                ForEach(AudienceTransition.allCases) { transition in
                    Button {
                        model.audienceTransition = transition
                    } label: {
                        Label(
                            "\(transition.displayName) — \(transition.detail)",
                            systemImage: model.audienceTransition == transition
                                ? "checkmark" : "rectangle.on.rectangle"
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
