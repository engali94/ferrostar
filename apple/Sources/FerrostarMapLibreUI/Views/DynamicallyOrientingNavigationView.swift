import FerrostarCore
import FerrostarSwiftUI
import MapKit
import MapLibre
import MapLibreSwiftDSL
import MapLibreSwiftUI
import SwiftUI

/// A navigation view that dynamically switches between portrait and landscape orientations.
public struct DynamicallyOrientingNavigationView: View, CustomizableNavigatingInnerGridView {
    @Environment(\.navigationFormatterCollection) var formatterCollection: any FormatterCollection

    @State private var orientation = UIDevice.current.orientation

    let styleURL: URL
    @Binding var camera: MapViewCamera
    let navigationCamera: MapViewCamera

    private var navigationState: NavigationState?
    private let userLayers: () -> [StyleLayerDefinition]
    
    private let mapViewModifiers: (_ view: MapView<MLNMapViewController>, _ isNavigating: Bool) -> MapView<MLNMapViewController>

    public var topCenter: (() -> AnyView)?
    public var topTrailing: (() -> AnyView)?
    public var midLeading: (() -> AnyView)?
    public var bottomTrailing: (() -> AnyView)?

    var calculateSpeedLimit: ((NavigationState?) -> Measurement<UnitSpeed>?)?
    @State var speedLimit: Measurement<UnitSpeed>?

    var onTapExit: (() -> Void)?

    public var minimumSafeAreaInsets: EdgeInsets

    private var locationProviding: LocationProviding?
    /// Create a dynamically orienting navigation view. This view automatically arranges child views for both portait
    /// and landscape orientations.
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
    ///   - makeMapContent: Custom maplibre layers to display on the map view.
    ///   - mapViewModifiers: An optional closure that allows you to apply custom view and map modifiers to the `MapView`. The closure
    ///     takes the `MapView` instance and provides a Boolean indicating if navigation is active, and returns an `AnyView`. Use this to attach onMapTapGesture and other view modifiers to the underlying MapView and customize when the modifiers are applied using
    ///       the isNavigating modifier.
    ///     By default, it returns the unmodified `MapView`.
    public init(
        styleURL: URL,
        camera: Binding<MapViewCamera>,
        navigationCamera: MapViewCamera = .automotiveNavigation(),
        locationProviding: LocationProviding?,
        navigationState: NavigationState?,
        calculateSpeedLimit: ((NavigationState?) -> Measurement<UnitSpeed>?)? = nil,
        minimumSafeAreaInsets: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        onTapExit: (() -> Void)? = nil,
        @MapViewContentBuilder makeMapContent: @escaping () -> [StyleLayerDefinition] = { [] },
        mapViewModifiers: @escaping (_ view: MapView<MLNMapViewController>, _ isNavigating: Bool) -> MapView<MLNMapViewController> = { transferView, _ in
            transferView
        }
    ) {
        self.styleURL = styleURL
        self.navigationState = navigationState
        self.calculateSpeedLimit = calculateSpeedLimit
        self.minimumSafeAreaInsets = minimumSafeAreaInsets
        self.onTapExit = onTapExit
        self.locationProviding = locationProviding
        userLayers = makeMapContent

        _camera = camera
        self.navigationCamera = navigationCamera
        self.mapViewModifiers = mapViewModifiers
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                NavigationMapView(
                    styleURL: styleURL,
                    camera: $camera,
                    navigationState: navigationState,
                    locationProvider: locationProviding,
                    onStyleLoaded: { _ in
                        if navigationState?.isNavigating == true {
                            camera = navigationCamera
                        }
                        
                    },
                    makeMapContent: userLayers,
                    mapViewModifiers: mapViewModifiers)
                
                .navigationMapViewContentInset(NavigationMapViewContentInsetMode(
                    orientation: orientation,
                    geometry: geometry
                ))

                switch orientation {
                case .landscapeLeft, .landscapeRight:
                    LandscapeNavigationOverlayView(
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
                    }.complementSafeAreaInsets(parentGeometry: geometry, minimumInsets: minimumSafeAreaInsets)
                default:
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
                    }.complementSafeAreaInsets(parentGeometry: geometry, minimumInsets: minimumSafeAreaInsets)
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            orientation = UIDevice.current.orientation
        }
        .onChange(of: navigationState) { value in
            speedLimit = calculateSpeedLimit?(value)
        }
    }
}
