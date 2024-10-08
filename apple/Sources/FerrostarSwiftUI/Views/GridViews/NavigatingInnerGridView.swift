import SwiftUI

/// When navigation is underway, we use this standardized grid view with pre-defined metadata and interactions.
/// This is the default UI and can be customized to some extent. If you need more customization,
/// use the ``InnerGridView``.
public struct NavigatingInnerGridView: View, CustomizableNavigatingInnerGridView {
    @Environment(\.navigationFormatterCollection) var formatterCollection: any FormatterCollection

    var speedLimit: Measurement<UnitSpeed>?

    var showZoom: Bool
    var onZoomIn: () -> Void
    var onZoomOut: () -> Void

    var showCentering: Bool
    var onCenter: () -> Void

    // MARK: Customizable Containers

    public var topCenter: (() -> AnyView)?
    public var topTrailing: (() -> AnyView)?
    public var midLeading: (() -> AnyView)?
    public var bottomTrailing: (() -> AnyView)?

    /// The default navigation inner grid view.
    ///
    /// This view provides all default navigation UI views that are used in the open map area. This area is defined as
    /// between the header/banner view and footer/arrival view in portrait mode.
    /// On landscape mode it is the trailing half of the screen.
    ///
    /// - Parameters:
    ///   - speedLimit: The speed limit provided by the navigation state (or nil)
    ///   - showZoom: Whether to show the provided zoom control or not.
    ///   - onZoomIn: The on zoom in tapped action. This should be used to zoom the user in one increment.
    ///   - onZoomOut: The on zoom out tapped action. This should be used to zoom the user out one increment.
    ///   - showCentering: Whether to show the centering control. This is typically determined by the Map's centering
    /// state.
    ///   - onCenter: The action that occurs when the user taps the centering control (to re-center the
    /// map on the user).
    public init(
        speedLimit: Measurement<UnitSpeed>? = nil,
        showZoom: Bool = false,
        onZoomIn: @escaping () -> Void = {},
        onZoomOut: @escaping () -> Void = {},
        showCentering: Bool = false,
        onCenter: @escaping () -> Void = {}
    ) {
        self.speedLimit = speedLimit
        self.showZoom = showZoom
        self.onZoomIn = onZoomIn
        self.onZoomOut = onZoomOut
        self.showCentering = showCentering
        self.onCenter = onCenter
    }

    public var body: some View {
        InnerGridView(
            topLeading: {
                if let speedLimit {
                    SpeedLimitView(
                        speedLimit: speedLimit,
                        valueFormatter: formatterCollection.speedValueFormatter,
                        unitFormatter: formatterCollection.speedWithUnitsFormatter
                    )
                }
            },
            topCenter: { topCenter?() },
            topTrailing: { topTrailing?() },
            midLeading: { midLeading?() },
            midCenter: {
                // This view does not allow center content.
                Spacer()
            },
            midTrailing: {
                if showZoom {
                    NavigationUIZoomButton(onZoomIn: onZoomIn, onZoomOut: onZoomOut)
                        .shadow(radius: 8)
                } else {
                    Spacer()
                }
            },
            bottomLeading: {
                if showCentering {
                    NavigationUIButton(action: onCenter) {
                        Image(systemName: "location.north.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                    }
                    .shadow(radius: 8)
                } else {
                    Spacer()
                }
            },
            bottomCenter: {
                // This view does not allow center content to prevent overlaying the puck.
                Spacer()
            },
            bottomTrailing: { bottomTrailing?() }
        )
    }
}

#Preview("Navigating Inner Minimal Example") {
    VStack(spacing: 16) {
        RoundedRectangle(cornerRadius: 12)
            .padding(.horizontal, 16)
            .frame(height: 128)

        NavigatingInnerGridView(
            speedLimit: .init(value: 55, unit: .milesPerHour),
            showZoom: true,
            showCentering: true
        )
        .padding(.horizontal, 16)

        RoundedRectangle(cornerRadius: 36)
            .padding(.horizontal, 16)
            .frame(height: 72)
    }
    .background(Color.green)
}
