import SwiftUI

// MARK: - Sticky section

/// A home page's section as a card: its header sits on the card's top, and as the page
/// scrolls the header hands over to a small minimised one, the content slides under the
/// card's edge, and the card itself scales and fades out of the way of the one behind it.
/// Ported from the reference WSSection. iOS only — the effect is a scrolling touch
/// screen's; the Mac and Apple TV keep their plain sections.
///
/// The layout is honest about what it is: the content isn't re-laid-out as it scrolls, it
/// is offset by its position and clipped, with the mask and background shrinking with it.
@available(iOS 18.0, macOS 15.0, tvOS 18.0, *)
struct StickySection<Content: View, Header: View, MinimisedHeader: View>: View {
    var config: StickySectionConfig = .init()
    var spacing: CGFloat = 10
    @ViewBuilder var content: Content
    @ViewBuilder var header: Header
    @ViewBuilder var minimisedHeader: MinimisedHeader

    @State private var headerSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            header
                .visualEffect { content, proxy in
                    let rect = proxy.frame(in: .named("SECTION"))
                    let minY = max(rect.minY - config.sectionPadding, 0)
                    let progress = max(min(minY / config.headerFadeDistance, 1), 0)

                    return content
                        .opacity(1 - progress)
                }
                .background {
                    minimisedHeader
                        .frame(maxHeight: .infinity)
                        .offset(y: config.minimisedHeaderOffset / 2)
                        .visualEffect { content, proxy in
                            let rect = proxy.frame(in: .named("SECTION"))
                            let minY = max(rect.minY - config.sectionPadding - config.headerFadeDistance, 0)
                            let progress = max(min(minY / config.headerFadeDistance, 1), 0)

                            return content
                                .opacity(progress)
                        }
                }
                .padding([.horizontal, .top], config.sectionPadding)
                .onGeometryChange(for: CGSize.self) {
                    $0.size
                } action: { newValue in
                    headerSize = newValue
                }

            content
                .padding([.horizontal, .bottom], config.sectionPadding)
                .visualEffect { content, proxy in
                    let rect = proxy.frame(in: .named("SECTION"))
                    let scrollMinY = proxy.frame(in: .scrollView(axis: .vertical)).minY
                    let minY = max(rect.minY - scrollMinY, 0)

                    return content
                        .offset(y: -minY)
                }
                .clipped()
        }
        .mask {
            GeometryReader { proxy in
                let rect = proxy.frame(in: .named("SECTION"))
                let viewHeight = proxy.size.height
                let headerHeight = headerSize.height + config.sectionPadding + config.minimisedHeaderOffset
                let bottomPadding = min(max(rect.minY, 0), viewHeight - headerHeight)

                RoundedRectangle(cornerRadius: config.cornerRadius)
                    .padding(.bottom, bottomPadding)
            }
        }
        .background {
            GeometryReader { proxy in
                let rect = proxy.frame(in: .named("SECTION"))
                let viewHeight = proxy.size.height
                let headerHeight = headerSize.height + config.sectionPadding + config.minimisedHeaderOffset
                let bottomPadding = min(max(rect.minY, 0), viewHeight - headerHeight)

                Group {
                    #if os(iOS)
                    if config.isGlassBackground, #available(iOS 26.0, *) {
                        Rectangle()
                            .fill(.clear)
                            .glassEffect(.regular, in: .rect(cornerRadius: config.cornerRadius))
                    } else {
                        RoundedRectangle(cornerRadius: config.cornerRadius)
                            .fill(config.background)
                    }
                    #else
                    RoundedRectangle(cornerRadius: config.cornerRadius)
                        .fill(config.background)
                    #endif
                }
                .padding(.bottom, bottomPadding)
            }
        }
        .compositingGroup()
        .visualEffect { [headerSize] content, proxy in
            let rect = proxy.frame(in: .scrollView(axis: .vertical))
            let minY = rect.minY
            let headerHeight = headerSize.height + config.sectionPadding + config.minimisedHeaderOffset
            let cutoffHeight = proxy.size.height - headerHeight
            let distance = abs(min(cutoffHeight + minY, 0))
            let progress = max(min(distance / config.fadeDistance, 1), 0)
            let scale = 1 - (progress * config.fadeScale)
            let opacity = 1 - progress

            return content
                .scaleEffect(scale, anchor: .top)
                .opacity(opacity)
                .offset(y: minY < 0 ? -minY : 0)
        }
        .coordinateSpace(.named("SECTION"))
    }
}

/// A sticky section's dials. `StickySection` is generic over its three view types, and a
/// Config nested in it would drag those arguments into every reference (`StickySection<
/// …>.Config`), so the dials stand at file scope beside it.
struct StickySectionConfig {
    var sectionPadding: CGFloat = 15
    var cornerRadius: CGFloat = 20
    var background: AnyShapeStyle = {
        // The 17 hierarchical fill is the look the cards were designed with; below
        // that, UIKit's tertiary fill is the closest of the older styles.
        if #available(iOS 17.0, tvOS 17.0, macOS 14.0, *) {
            return AnyShapeStyle(.fill.tertiary)
        }
        #if canImport(UIKit)
        return AnyShapeStyle(Color(uiColor: .tertiarySystemFill))
        #else
        return AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
        #endif
    }()
    /// Glass where the platform has the effect; set it with `StickySectionConfig.glass`,
    /// which resolves that itself.
    var isGlassBackground: Bool = false

    /// A smaller minimised header, shown when scrolled.
    var minimisedHeaderOffset: CGFloat = -10
    var headerFadeDistance: CGFloat = 15
    var fadeDistance: CGFloat = 45
    var fadeScale: CGFloat = 0.05

    /// The card look: glass on iOS 26, the plain fill below.
    static var glass: StickySectionConfig {
        var config = StickySectionConfig()
        #if os(iOS)
        if #available(iOS 26.0, *) {
            config.isGlassBackground = true
        }
        #endif
        return config
    }
}

// MARK: - Home section card

/// One home row as a sticky card where the platform has it, and as the plain header and
/// shelf it always was where it doesn't (below iOS 18, a Mac, Apple TV). The minimised
/// header is the row's title, uppercased — a glance is all it needs.
@ViewBuilder
func homeSectionCard<Content: View, Header: View>(
    title: String,
    config: StickySectionConfig = .glass,
    @ViewBuilder header: () -> Header,
    @ViewBuilder content: () -> Content
) -> some View {
    #if os(iOS)
    if #available(iOS 18.0, *) {
        StickySection(config: config) {
            content()
        } header: {
            header()
        } minimisedHeader: {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    } else {
        VStack(alignment: .leading, spacing: 14) {
            header()
            content()
        }
    }
    #else
    VStack(alignment: .leading, spacing: 14) {
        header()
        content()
    }
    #endif
}
