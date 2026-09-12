import SwiftUI

/// A scrolling strip of every slide, kept centred on the current one.
struct SlideThumbnailBar: View {

    @Environment(PresentationViewModel.self) private var model

    private let thumbnailHeight: CGFloat = 58

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(0 ..< model.pageCount, id: \.self) { pageIndex in
                        SlideThumbnail(pageIndex: pageIndex, height: thumbnailHeight)
                            .id(pageIndex)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.currentPageIndex, initial: true) {
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollProxy.scrollTo(model.currentPageIndex, anchor: .center)
                }
            }
        }
        .frame(height: thumbnailHeight + 32)
        .background(PresenterPalette.chrome)
    }
}

struct SlideThumbnail: View {

    let pageIndex: Int
    var height: CGFloat

    @Environment(PresentationViewModel.self) private var model

    private var isCurrent: Bool { pageIndex == model.currentPageIndex }

    var body: some View {
        Button {
            model.go(to: pageIndex)
        } label: {
            VStack(spacing: 3) {
                SlideImageView(region: .slide, pageIndex: pageIndex, cornerRadius: 3)
                    .frame(width: height * model.slideAspectRatio, height: height)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(isCurrent ? Color.accentColor : .clear, lineWidth: 2)
                    }

                Text("\(pageIndex + 1)")
                    .font(.system(size: 10, weight: isCurrent ? .semibold : .regular).monospacedDigit())
                    .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
        }
        .buttonStyle(.plain)
    }
}

/// Grid of every slide, for jumping across a long deck.
struct SlideGridView: View {

    @Environment(PresentationViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(0 ..< model.pageCount, id: \.self) { pageIndex in
                            Button {
                                model.go(to: pageIndex)
                                dismiss()
                            } label: {
                                VStack(spacing: 4) {
                                    SlideImageView(region: .slide, pageIndex: pageIndex, cornerRadius: 4)
                                        .aspectRatio(model.slideAspectRatio, contentMode: .fit)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .strokeBorder(
                                                    pageIndex == model.currentPageIndex ? Color.accentColor : .clear,
                                                    lineWidth: 2.5
                                                )
                                        }
                                    Text("\(pageIndex + 1)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .id(pageIndex)
                        }
                    }
                    .padding(16)
                }
                .onAppear {
                    scrollProxy.scrollTo(model.currentPageIndex, anchor: .center)
                }
            }
            .navigationTitle("Go to Slide")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
