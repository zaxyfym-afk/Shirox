import SwiftUI

// MARK: - Tour mark

/// AnyShape is 16's, and the tour reports its marks from iOS 15; this erases the shape
/// the same way on every version the app runs on.
struct AnyTourShape: Shape {
    private let path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        path = { rect in shape.path(in: rect) }
    }

    func path(in rect: CGRect) -> Path {
        path(rect)
    }
}

/// One stop of the tour: what it points at (a frame, in a mask shape) and what it says
/// there. Ported from the reference HView's highlight.
struct TourHighlight: Identifiable {
    let id: Int
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let maskShape: AnyTourShape
    let inset: CGFloat
    let frame: CGRect
}

extension View {
    /// Marks this view as the tour's `order`-th stop: the view reports where it is, and the
    /// tour overlay cuts its hole there. Below iOS 18, and on a Mac and Apple TV, this is
    /// nothing — the tour is a touch screen's.
    @ViewBuilder
    func tourHighlight<S: Shape>(
        order: Int,
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        maskShape: S = Capsule(),
        inset: CGFloat = 10,
        group: Binding<[Int: TourHighlight]>
    ) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            modifier(TourHighlightMarker(
                order: order, title: title, description: description,
                maskShape: AnyTourShape(maskShape), inset: inset, group: group
            ))
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// The tour itself: a clear cover over the app, everything dimmed but the current
    /// stop, and a small card beside it — "N of M", what this is, Skip or Next.
    @ViewBuilder
    func tourOverlay(isPresented: Binding<Bool>, group: Binding<[Int: TourHighlight]>) -> some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            fullScreenCover(isPresented: isPresented) {
                TourOverlayView(isPresented: isPresented, group: group)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .presentationBackground(.clear)
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#if os(iOS)
/// The mark's listener: a view that does nothing but report where it is, and stops when it
/// goes away — a marked view leaving the screen must not keep its old frame cut out.
@available(iOS 18.0, *)
private struct TourHighlightMarker: ViewModifier {
    var order: Int
    var title: LocalizedStringKey
    var description: LocalizedStringKey
    var maskShape: AnyTourShape
    var inset: CGFloat
    @Binding var group: [Int: TourHighlight]

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .global)
            } action: { newValue in
                group[order] = TourHighlight(
                    id: order, title: title, description: description,
                    maskShape: maskShape, inset: inset, frame: newValue
                )
            }
            .onDisappear {
                group[order] = nil
            }
    }
}

// MARK: - Tour overlay

@available(iOS 18.0, *)
private struct TourOverlayView: View {
    @Binding var isPresented: Bool
    @Binding var group: [Int: TourHighlight]

    @State private var current: TourHighlight?
    @State private var containerSize: CGSize = .zero

    var body: some View {
        Rectangle()
            .fill(.black.opacity(0.7))
            .mask {
                Rectangle()
                    .overlay(alignment: .topLeading) {
                        if let current {
                            let frame = current.frame
                            let inset = current.inset

                            current.maskShape
                                .frame(width: frame.width + inset, height: frame.height + inset)
                                .offset(x: frame.origin.x - inset / 2, y: frame.origin.y - inset / 2)
                                .blendMode(.destinationOut)
                        }
                    }
            }
            .overlay(alignment: .topLeading) {
                let frame = current?.frame ?? .zero
                let inset = current?.inset ?? 0
                // The card sits at whichever edge of the stop has room for it.
                let edge: Edge = frame.origin.y > (containerSize.height / 2) ? .bottom : .top

                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(width: frame.width + inset, height: frame.height + inset)
                    .popover(item: $current, arrowEdge: edge) { highlight in
                        card(highlight)
                            .frame(width: 330)
                            .presentationCompactAdaptation(.popover)
                            .interactiveDismissDisabled()
                    }
                    .offset(x: frame.origin.x - inset / 2, y: frame.origin.y - inset / 2)
            }
            .onGeometryChange(for: CGSize.self) {
                $0.size
            } action: { newValue in
                containerSize = newValue
            }
            .task {
                try? await Task.sleep(for: .seconds(0.25))
                if let first = group[0] {
                    withAnimation(animation) {
                        current = first
                    }
                } else {
                    // Nothing marked: a tour with no stops is no tour at all.
                    isPresented = false
                }
            }
    }

    private func card(_ highlight: TourHighlight) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("tour.step_of \(highlight.id + 1) \(group.count)")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(highlight.title)
                    .font(.title3.bold())
                    .lineLimit(1)

                Text(highlight.description)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.bottom, 4)

            HStack {
                Button("common.skip") {
                    isPresented = false
                }
                .tint(.secondary)

                Spacer(minLength: 0)

                nextButton(highlight)
                    .buttonBorderShape(.capsule)
            }
        }
        .padding(20)
    }

    /// Glass where the platform has it (the reference's own look); the plain prominent
    /// button below iOS 26.
    @ViewBuilder
    private func nextButton(_ highlight: TourHighlight) -> some View {
        let isLast = highlight.id == group.count - 1
        let button = Button {
            if isLast {
                isPresented = false
            } else {
                withAnimation(animation) {
                    current = group[min(highlight.id + 1, group.count - 1)]
                }
            }
        } label: {
            Text(isLast ? "common.finish" : "common.next")
                .fontWeight(.semibold)
                .padding(.horizontal, 25)
                .padding(.vertical, 4)
        }
        if #available(iOS 26.0, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }

    private var animation: Animation {
        .interpolatingSpring(duration: 0.25, bounce: 0, initialVelocity: 0)
    }
}
#endif
