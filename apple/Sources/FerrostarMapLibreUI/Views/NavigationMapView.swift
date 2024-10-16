import FerrostarCore
import FerrostarSwiftUI
import MapKit
import MapLibre
import MapLibreSwiftDSL
import MapLibreSwiftUI
import SwiftUI

/// The most generic map view in Ferrostar.
///
/// This view includes renders a route line and includes a default camera.
/// It does not include other UI elements like instruction banners.
/// This is the basis of higher level views like
/// ``DynamicallyOrientingNavigationView``.
public struct NavigationMapView<T: MapViewHostViewController>: View {
    let makeViewController: () -> T
    let styleURL: URL
    var mapViewContentInset: UIEdgeInsets = .zero
    var onStyleLoaded: (MLNStyle) -> Void
    let userLayers: [StyleLayerDefinition]
    
    let mapViewModifiers: (_ view: MapView<MLNMapViewController>, _ isNavigating: Bool) -> MapView<MLNMapViewController>
    
    // TODO: Configurable camera and user "puck" rotation modes
    
    private var navigationState: NavigationState?
    
    private var locationManager: LocationManagerProxy?
    
    // MARK: Camera Settings
    
    @Binding var camera: MapViewCamera
    
    private var effectiveMapViewContentInset: UIEdgeInsets {
        return navigationState?.isNavigating == true ? mapViewContentInset : .zero
    }
    
    /// Initialize a map view tuned for turn by turn navigation.
    ///
    /// - Parameters:
    ///   - styleURL: The map's style url.
    ///   - camera: The camera binding that represents the current camera on the map.
    ///   - navigationState: The current ferrostar navigation state provided by ferrostar core.
    ///   - onStyleLoaded: The map's style has loaded and the camera can be manipulated (e.g. to user tracking).
    ///   - makeMapContent: Custom maplibre symbols to display on the map view.
    ///   - mapViewModifiers: An optional closure that allows you to apply custom view and map modifiers to the `MapView`. The closure
    ///     takes the `MapView` instance and provides a Boolean indicating if navigation is active, and returns an `AnyView`. Use this to attach onMapTapGesture and other view modifiers to the underlying MapView and customize when the modifiers are applied using
    ///       the isNavigating modifier.
    ///     By default, it returns the unmodified `MapView`.
    public init(
        makeViewController: @autoclosure @escaping () -> T,
        styleURL: URL,
        camera: Binding<MapViewCamera>,
        navigationState: NavigationState?,
        locationProvider: LocationProviding?,
        onStyleLoaded: @escaping ((MLNStyle) -> Void),
        @MapViewContentBuilder makeMapContent: () -> [StyleLayerDefinition] = { [] },
        mapViewModifiers: @escaping (_ view: MapView<T>, _ isNavigating: Bool) -> MapView<T> = { transferView, _ in
            transferView
        }
    ) {
        self.makeViewController = makeViewController
        self.styleURL = styleURL
        _camera = camera
        self.navigationState = navigationState
        self.onStyleLoaded = onStyleLoaded
        self.userLayers = makeMapContent()
        self.mapViewModifiers = mapViewModifiers
        if let locationProvider {
            self.locationManager = LocationManagerProxy(locationProvider: locationProvider)
        } else {
            self.locationManager = nil
        }
    }
    
    @ViewBuilder
    public var body: some View {
        MapView(
            makeViewController: makeViewController(),
            styleURL: styleURL,
            camera: $camera,
            locationManager: locationManager
        ) {
            // TODO: Create logic and style for route previews. Unless ferrostarCore will handle this internally.
            
            if let routePolyline = navigationState?.routePolyline {
                RouteStyleLayer(polyline: routePolyline,
                                identifier: "route-polyline",
                                style: TravelledRouteStyle())
            }
            
            if let remainingRoutePolyline = navigationState?.remainingRoutePolyline {
                RouteStyleLayer(polyline: remainingRoutePolyline,
                                identifier: "remaining-route-polyline")
            }
            
            updateCameraIfNeeded()
            
            // Overlay any additional user layers.
            userLayers
        }
        .mapViewContentInset(effectiveMapViewContentInset)
        .mapControls {
            // No controls
        }
        .onStyleLoaded(onStyleLoaded)
        .applyTransform(transform: mapViewModifiers, isNavigating: navigationState?.isNavigating == true)
        .ignoresSafeArea(.all)
    }
    
    private func updateCameraIfNeeded() {
        if case let .navigating(_, snappedUserLocation: userLocation, _, _, _, _, _, _, _) = navigationState?.tripState,
           // There is no reason to push an update if the coordinate and heading are the same.
           // That's all that gets displayed, so it's all that MapLibre should care about.
            locationManager?.lastLocation != userLocation.coordinates
            .clLocationCoordinate2D
        {
            locationManager?.updateLocation(UserLocation(clLocation: userLocation.clLocation))
        }
    }
}

extension MapView {
    @ViewBuilder
    func applyTransform<Content: View>(
        transform: (MapView<MLNMapViewController>, Bool) -> Content, isNavigating: Bool) -> some View {
            transform(self, isNavigating)
        }
}

import FerrostarCoreFFI
import CoreLocation
import MapLibre
import FerrostarCore
import Combine

public typealias UserLocation = FerrostarCoreFFI.UserLocation

public class LocationManagerProxy: NSObject, MLNLocationManager, ObservableObject {
    public weak var delegate: (any MLNLocationManagerDelegate)?
    
    private let locationProvider: LocationProviding
    private var cancellable: AnyCancellable?
    
    public init(locationProvider: LocationProviding) {
        self.locationProvider = locationProvider
        super.init()
        setupLocationUpdates()
    }
    
    private func setupLocationUpdates() {
        if let simulatedProvider = locationProvider as? SimulatedLocationProvider {
            cancellable = simulatedProvider.$lastLocation
                .compactMap { $0 }
                .sink { [weak self] location in
                    self?.updateLocation(location)
                }
        } else {
            // Setup for real location provider if needed
        }
    }
    
    func updateLocation(_ location: UserLocation) {
        let clLocation = CLLocation(
            coordinate: location.coordinates.clLocationCoordinate2D,
            altitude: 0,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: -1,
            course: Double(location.courseOverGround?.degrees ?? 0),
            speed: location.speed?.value ?? -1,
            timestamp: location.timestamp
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.locationManager(self, didUpdate: [clLocation])
        }
    }
    
    public var lastLocation: CLLocationCoordinate2D? {
        locationProvider.lastLocation?.coordinates.clLocationCoordinate2D
    }
    
    public var lastCLHeading: CLHeading? {
        guard let heading = locationProvider.lastHeading else { return nil }
        let clHeading = CLHeading()
        clHeading.setValue(Double(heading.trueHeading), forKey: "trueHeading")
        clHeading.setValue(Double(heading.accuracy), forKey: "headingAccuracy")
        clHeading.setValue(heading.timestamp, forKey: "timestamp")
        return clHeading
    }
    
    public func requestAlwaysAuthorization() {
        // No-op, handled by LocationProviding implementation
    }
    
    public func requestWhenInUseAuthorization() {
        // No-op, handled by LocationProviding implementation
    }
    
    public func dismissHeadingCalibrationDisplay() {
        // No-op
    }
    
    public func startUpdatingLocation() {
        locationProvider.startUpdating()
    }
    
    public func stopUpdatingLocation() {
        locationProvider.stopUpdating()
    }
    
    public var headingOrientation: CLDeviceOrientation = .portrait
    
    public func startUpdatingHeading() {
        // Handled by startUpdating() in LocationProviding
    }
    
    public func stopUpdatingHeading() {
        // Handled by stopUpdating() in LocationProviding
    }
    
    public var authorizationStatus: CLAuthorizationStatus {
        locationProvider.authorizationStatus
    }
}

extension NavigationMapView where T == MLNMapViewController {
    /// Initialize a map view tuned for turn by turn navigation.
    ///
    /// - Parameters:
    ///   - styleURL: The map's style url.
    ///   - camera: The camera binding that represents the current camera on the map.
    ///   - navigationState: The current ferrostar navigation state provided by ferrostar core.
    ///   - onStyleLoaded: The map's style has loaded and the camera can be manipulated (e.g. to user tracking).
    ///   - makeMapContent: Custom maplibre symbols to display on the map view.
    public init(
        styleURL: URL,
        camera: Binding<MapViewCamera>,
        navigationState: NavigationState?,
        onStyleLoaded: @escaping ((MLNStyle) -> Void),
        @MapViewContentBuilder _ makeMapContent: () -> [StyleLayerDefinition] = { [] },
        mapViewModifiers: @escaping (_ view: MapView<T>, _ isNavigating: Bool) -> MapView<T> = { transferView, _ in
            transferView
        }
    ) {
        self.makeViewController = MLNMapViewController.init
        self.styleURL = styleURL
        _camera = camera
        self.navigationState = navigationState
        self.onStyleLoaded = onStyleLoaded
        userLayers = makeMapContent()
        self.mapViewModifiers = mapViewModifiers
    }
}
