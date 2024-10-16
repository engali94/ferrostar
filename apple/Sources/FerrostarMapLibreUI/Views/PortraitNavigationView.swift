import FerrostarCore
import FerrostarSwiftUI
import MapKit
import MapLibre
import MapLibreSwiftDSL
import MapLibreSwiftUI
import SwiftUI

/// A portrait orientation navigation view that includes the InstructionsView at the top.
public struct PortraitNavigationView<T: MapViewHostViewController>: View, CustomizableNavigatingInnerGridView {
    @Environment(\.navigationFormatterCollection) var formatterCollection: any FormatterCollection

    let styleURL: URL
    let makeViewController: () -> T
    // TODO: Configurable camera and user "puck" rotation modes

    private var navigationState: NavigationState?
    private let userLayers: [StyleLayerDefinition]

    public var topCenter: (() -> AnyView)?
    public var topTrailing: (() -> AnyView)?
    public var midLeading: (() -> AnyView)?
    public var bottomTrailing: (() -> AnyView)?
    public var bottomLeading: (() -> AnyView)?

    public var minimumSafeAreaInsets: EdgeInsets

    @Binding var camera: MapViewCamera
    let navigationCamera: MapViewCamera

    var calculateSpeedLimit: ((NavigationState?) -> Measurement<UnitSpeed>?)?
    @State var speedLimit: Measurement<UnitSpeed>?
    
    private var locationProviding: LocationProviding?
    
    var onTapExit: (() -> Void)?

    /// Create a portrait navigation view. This view is optimized for display on a portrait screen where the
    /// instructions and arrival view are on the top and bottom of the screen.
    /// The user puck and route are optimized for the center of the screen.
    ///
    /// - Parameters:
    ///   - styleURL: The map's style url.
    ///   - camera: The camera binding that represents the current camera on the map.
    ///   - navigationCamera: The default navigation camera. This sets the initial camera & is also used when the center
    /// on user button it tapped.
    ///   - navigationState: The current ferrostar navigation state provided by the Ferrostar core.
    ///   - minimumSafeAreaInsets: The minimum padding to apply from safe edges. See `complementSafeAreaInsets`.
    ///   - onTapExit: An optional behavior to run when the ArrivalView exit button is tapped. When nil (default) the
    /// exit button is hidden.
    ///   - makeMapContent: Custom maplibre symbols to display on the map view.
    public init(
        makeViewController: @autoclosure @escaping () -> T,
        styleURL: URL,
        camera: Binding<MapViewCamera>,
        navigationCamera: MapViewCamera = .automotiveNavigation(),
        navigationState: NavigationState?,
        locationProviding: LocationProviding?,
        calculateSpeedLimit: ((NavigationState?) -> Measurement<UnitSpeed>?)? = nil,
        minimumSafeAreaInsets: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        onTapExit: (() -> Void)? = nil,
        @MapViewContentBuilder makeMapContent: () -> [StyleLayerDefinition] = { [] }
    ) {
        self.makeViewController = makeViewController
        self.styleURL = styleURL
        self.navigationState = navigationState
        self.calculateSpeedLimit = calculateSpeedLimit
        self.minimumSafeAreaInsets = minimumSafeAreaInsets
        self.onTapExit = onTapExit
        self.locationProviding = locationProviding
        userLayers = makeMapContent()

        _camera = camera
        self.navigationCamera = navigationCamera
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                NavigationMapView(
                    makeViewController: makeViewController(),
                    styleURL: styleURL,
                    camera: $camera,
                    navigationState: navigationState,
                    locationProvider: locationProviding,
                    onStyleLoaded: { _ in
                        camera = navigationCamera
                    }
                ) {
                    userLayers
                }
                .navigationMapViewContentInset(.portrait(within: geometry))

                PortraitNavigationOverlayView(
                    navigationState: navigationState,
                    speedLimit: speedLimit,
                    showZoom: true,
                    onZoomIn: { camera.incrementZoom(by: 1) },
                    onZoomOut: { camera.incrementZoom(by: -1) },
                    showCentering: !camera.isTrackingUserLocationWithCourse,
                    onCenter: { camera = navigationCamera },
                    onTapExit: onTapExit
                )
                .innerGrid {
                    topCenter?()
                } topTrailing: {
                    topTrailing?()
                } midLeading: {
                    midLeading?()
                } bottomTrailing: {
                    bottomTrailing?()
                } bottomLeading: {
                    bottomLeading?()
                }.complementSafeAreaInsets(parentGeometry: geometry, minimumInsets: minimumSafeAreaInsets)
            }
        }
        .onChange(of: navigationState) { value in
            speedLimit = calculateSpeedLimit?(value)
        }
    }
}

extension PortraitNavigationView where T == MLNMapViewController {
    /// Create a portrait navigation view. This view is optimized for display on a portrait screen where the
    /// instructions and arrival view are on the top and bottom of the screen.
    /// The user puck and route are optimized for the center of the screen.
    ///
    /// - Parameters:
    ///   - styleURL: The map's style url.
    ///   - camera: The camera binding that represents the current camera on the map.
    ///   - navigationCamera: The default navigation camera. This sets the initial camera & is also used when the center
    /// on user button it tapped.
    ///   - navigationState: The current ferrostar navigation state provided by the Ferrostar core.
    ///   - minimumSafeAreaInsets: The minimum padding to apply from safe edges. See `complementSafeAreaInsets`.
    ///   - onTapExit: An optional behavior to run when the ArrivalView exit button is tapped. When nil (default) the
    /// exit button is hidden.
    ///   - makeMapContent: Custom maplibre symbols to display on the map view.
    public init(
        styleURL: URL,
        camera: Binding<MapViewCamera>,
        navigationCamera: MapViewCamera = .automotiveNavigation(),
        navigationState: NavigationState?,
        locationProviding: LocationProviding?,
        calculateSpeedLimit: ((NavigationState?) -> Measurement<UnitSpeed>?)? = nil,
        minimumSafeAreaInsets: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        onTapExit: (() -> Void)? = nil,
        @MapViewContentBuilder makeMapContent: () -> [StyleLayerDefinition] = { [] }
    ) {
        self.makeViewController = MLNMapViewController.init
        self.styleURL = styleURL
        self.navigationState = navigationState
        self.calculateSpeedLimit = calculateSpeedLimit
        self.minimumSafeAreaInsets = minimumSafeAreaInsets
        self.onTapExit = onTapExit
        self.locationProviding = locationProviding
        userLayers = makeMapContent()

        _camera = camera
        self.navigationCamera = navigationCamera
    }
}
