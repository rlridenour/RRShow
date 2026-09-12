import SwiftUI

/// Renders one region of one page at exactly the size it will be displayed at,
/// letterboxed on black.
///
/// The render is driven by `.task(id:)`, so resizing, paging and layout changes all
/// funnel through the same path, and an in-flight render is cancelled when any of them
/// changes. Widths are bucketed so a few points of layout jitter does not trigger a
/// fresh rasterization.
struct SlideImageView: View {

    let region: SlideRegion
    let pageIndex: Int
    var background: Color = .black
    var cornerRadius: CGFloat = 6
    /// Cross-fade duration between slides. `nil` cuts straight to the new slide, which
    /// is what the presenter wants; the audience display fades.
    var crossfade: Double?

    @Environment(PresentationViewModel.self) private var model
    @Environment(\.displayScale) private var displayScale

    @State private var image: SlideImage?
    @State private var failureMessage: String?

    /// Renders snap to multiples of this many points of width.
    private let widthQuantum: CGFloat = 32

    var body: some View {
        GeometryReader { proxy in
            let renderWidth = fittedWidth(in: proxy.size)

            ZStack {
                background

                if let image {
                    Image(decorative: image.cgImage, scale: image.scale)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        // Identity keyed to the request so a page change swaps one image
                        // for another, which is what lets the two cross-fade.
                        .id(image.id)
                        .transition(.opacity)
                } else if let failureMessage {
                    Label(failureMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                        .multilineTextAlignment(.center)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .animation(crossfade.map { .easeOut(duration: $0) }, value: image?.id)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .task(id: renderKey(width: renderWidth)) {
                await render(width: renderWidth)
            }
        }
    }

    // MARK: - Sizing

    private var aspectRatio: CGFloat? {
        model.document?
            .geometry(atPageIndex: pageIndex)?
            .aspectRatio(of: region, layout: model.layout)
    }

    /// The width the slide will actually occupy once it is fitted into `size`.
    /// Rendering to that width rather than the container width avoids rasterizing
    /// pixels that letterboxing would throw away.
    private func fittedWidth(in size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 0 }
        guard let aspectRatio, aspectRatio > 0 else { return size.width }
        return min(size.width, size.height * aspectRatio)
    }

    private func quantized(_ width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        return (width / widthQuantum).rounded(.up) * widthQuantum
    }

    private func renderKey(width: CGFloat) -> SlideRenderRequest {
        SlideRenderRequest(
            pageIndex: pageIndex,
            region: region,
            layout: model.layout,
            pixelWidth: Int((quantized(width) * displayScale).rounded())
        )
    }

    // MARK: - Rendering

    private func render(width: CGFloat) async {
        let width = quantized(width)
        guard width > 0 else { return }

        do {
            let rendered = try await model.image(
                region: region,
                pageIndex: pageIndex,
                width: width,
                scale: displayScale
            )
            guard !Task.isCancelled else { return }
            image = rendered
            failureMessage = rendered == nil ? "Nothing to show here." : nil
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            image = nil
            failureMessage = error.localizedDescription
        }
    }
}
