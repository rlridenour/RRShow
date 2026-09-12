import SwiftUI
import UniformTypeIdentifiers

/// Shown until a deck is loaded: an opener, a drop target, and the decks already imported.
struct WelcomeView: View {

    @Environment(PresentationViewModel.self) private var model

    @State private var isImporting = false
    @State private var isDropTargeted = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header
                openPanel
                if !model.recentDocuments.isEmpty {
                    recentsSection
                }
            }
            .frame(maxWidth: 720)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            Task { await model.open(result: result) }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else {
                return false
            }
            Task { await model.open(pickedURL: url) }
            return true
        } isTargeted: { isDropTargeted = $0 }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tint)
            Text("RRShow")
                .font(.largeTitle.weight(.semibold))
            Text("Present dual-screen Beamer PDFs: the slide goes to the room, the notes stay with you.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var openPanel: some View {
        VStack(spacing: 16) {
            Image(systemName: isDropTargeted ? "arrow.down.doc.fill" : "doc.badge.plus")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)

            Text("Drop a PDF here")
                .font(.headline)

            Button {
                isImporting = true
            } label: {
                Label("Open PDF…", systemImage: "folder")
                    .frame(maxWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if model.hasBundledSample {
                Button {
                    Task { await model.openBundledSample() }
                } label: {
                    Label("Try the Sample Deck", systemImage: "sparkles")
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if model.isLoading {
                ProgressView().controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.quaternary.opacity(isDropTargeted ? 0.5 : 0.2))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
        }
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Imported Presentations")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(model.recentDocuments, id: \.self) { url in
                    Button {
                        Task { await model.open(localURL: url) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.richtext")
                                .foregroundStyle(.tint)
                            Text(url.deletingPathExtension().lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            model.deleteRecentDocument(at: url)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                    if url != model.recentDocuments.last {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.quaternary.opacity(0.2))
            }
        }
    }
}
