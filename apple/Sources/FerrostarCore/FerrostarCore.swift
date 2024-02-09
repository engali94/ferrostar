import CoreLocation
import UniFFI
import Foundation

enum FerrostarCoreError: Error, Equatable {
    /// The user has disabled location services for this app.
    case locationServicesDisabled
    case userLocationUnknown
    /// The route request from the route adapter has an invalid URL.
    ///
    /// This should never be encountered by end users of the library, and indicates a programming error
    /// in the route adapter.
    case invalidRequestUrl
    /// Invalid (non-2xx) HTTP status
    case httpStatusCode(Int)
}

/// Receives events from ``FerrostarCore``.
///
/// This is the central point responsible for relaying updates back to the application.
public protocol FerrostarCoreDelegate: AnyObject {
    /// Called when the location manager failed to get the user's location.
    ///
    /// This is a serious error, and the UI layer should inform the user. They may need to check their settings
    /// to enable location services.
    func core(_ core: FerrostarCore, locationManagerFailedWithError error: Error)

    /// Called when the core gives us an updated navigation state.
    ///
    /// This method will be called whenever the user's location changes significantly enough to have an effect
    /// on the navigation state that is important enough to require a decision or UI update (quite often in the
    /// case of a moving vehicle).
    ///
    /// This is *probably* not the final interface for this function but it's something to start with.
    func core(_ core: FerrostarCore, didUpdateNavigationState update: TripState)
}


/// The Ferrostar core.
///
/// This is the entrypoint for end users of Ferrostar, and is responsible
/// for "driving" the navigation with location updates and other events.
///
/// The usual flow is for callers to configure an instance of the core, set a ``delegate``,
/// and reuse the core for as long as it makes sense (necessarily somewhat app-specific).
/// Note that it is the responsibility of the caller to ensure that the location manager is authorized to get
/// live user location with high precision.
///
/// Users will first want to call ``getRoutes(waypoints:userLocation:)``
/// to fetch a list of possible routes asynchronously. Upon successfully computing a set of
/// possible routes, one is selected, either interactively by the user, or programmatically.
/// The particulars will vary by app; do what makes the most sense for your user experience.
///
/// Finally, with a route selected, call ``startNavigation(route:)`` to start a session.
@objc public class FerrostarCore: NSObject, ObservableObject {
    /// The delegate which will receive Ferrostar core events.
    public weak var delegate: FerrostarCoreDelegate?

    /// The observable state of the model (for easy binding in SwiftUI views).
    @Published public private(set) var state: NavigationState?

    private let networkSession: URLRequestLoading
    private let routeAdapter: UniFFI.RouteAdapterProtocol
    private let locationProvider: LocationProviding
    private var navigationController: UniFFI.NavigationControllerProtocol?
    private var tripState: UniFFI.TripState?

    public init(routeAdapter: UniFFI.RouteAdapterProtocol, locationManager: LocationProviding, networkSession: URLRequestLoading) {
        self.routeAdapter = routeAdapter
        locationProvider = locationManager
        self.networkSession = networkSession

        super.init()

        // Location provider setup
        locationProvider.delegate = self
    }

    public convenience init(valhallaEndpointUrl: URL, profile: String, locationManager: LocationProviding, networkSession: URLRequestLoading = URLSession.shared) {
        let routeAdapter = UniFFI.RouteAdapter.newValhallaHttp(endpointUrl: valhallaEndpointUrl.absoluteString, profile: profile)
        self.init(routeAdapter: routeAdapter, locationManager: locationManager, networkSession: networkSession)
    }

    /// Tries to get routes visiting one or more waypoints starting from the initial location.
    ///
    /// Success and failure are communicated via ``delegate`` methods.
    public func getRoutes(initialLocation: CLLocation, waypoints: [CLLocationCoordinate2D]) async throws -> [Route] {
        let routeRequest = try routeAdapter.generateRequest(userLocation: initialLocation.userLocation, waypoints: waypoints.map { $0.geographicCoordinates })

        switch routeRequest {
        case let .httpPost(url: url, headers: headers, body: body):
            guard let url = URL(string: url) else {
                throw FerrostarCoreError.invalidRequestUrl
            }

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            for (header, value) in headers {
                urlRequest.setValue(value, forHTTPHeaderField: header)
            }
            urlRequest.httpBody = Data(body)

            let (data, response) = try await networkSession.loadData(with: urlRequest)

            if let res = response as? HTTPURLResponse, res.statusCode < 200 || res.statusCode >= 300 {
                throw FerrostarCoreError.httpStatusCode(res.statusCode)
            } else {
                let routes = try routeAdapter.parseResponse(response: data)

                return routes.map { Route(inner: $0) }
            }
        }
    }

    /// Starts navigation with the given route. Any previous navigation session is dropped.
    public func startNavigation(route: Route, stepAdvance: StepAdvanceMode, routeDeviationTracking: RouteDeviationTracking) throws {
        // This is technically possible, so we need to check and throw, but
        // it should be rather difficult to get a location fix, get a route,
        // and then somehow this property go nil again.
        guard let location = locationProvider.lastLocation else {
            throw FerrostarCoreError.userLocationUnknown
        }

        locationProvider.startUpdating()

        state = NavigationState(snappedLocation: location, heading: locationProvider.lastHeading, fullRoute: route.geometry, steps: route.inner.steps)
        let controller = NavigationController(route: route.inner, config: NavigationControllerConfig(stepAdvance: stepAdvance.ffiValue, routeDeviationTracking: routeDeviationTracking.ffiValue))
        navigationController = controller
        DispatchQueue.main.async {
            self.update(newState: controller.getInitialState(location: location.userLocation), location: location)
        }
    }

    /// Stops navigation and stops requesting location updates (to save battery).
    public func stopNavigation() {
        navigationController = nil
        state = nil
        tripState = nil
        locationProvider.stopUpdating()
    }

    /// Internal state update.
    ///
    /// You should call this rather than setting properties directly
    private func update(newState: UniFFI.TripState, location: CLLocation) {
        DispatchQueue.main.async {
            self.tripState = newState

            switch (newState) {
            case .navigating(snappedUserLocation: let snappedLocation, remainingSteps: let remainingSteps, distanceToNextManeuver: let distanceToNextManeuver, deviation: let deviation):
                self.state?.snappedLocation = CLLocation(userLocation: snappedLocation)
                self.state?.courseOverGround = location.course
                self.state?.currentStep = remainingSteps.first
                // TODO: This isn't great; the core should probably just tell us which instruction to display
                self.state?.visualInstructions = remainingSteps.first?.visualInstructions.last(where: { instruction in
                    distanceToNextManeuver <= instruction.triggerDistanceBeforeManeuver
                })
                self.state?.distanceToNextManeuver = distanceToNextManeuver
                // TODO
    //                observableState?.spokenInstruction = currentStep.spokenInstruction.last(where: { instruction in
    //                    currentStepRemainingDistance <= instruction.triggerDistanceBeforeManeuver
    //                })

                switch (deviation) {
                case .noDeviation:
                    // No action
                    break
                case .offRoute(deviationFromRouteLine: let deviationFromRouteLine):
                    // TODO: Recalculation logic; we have two options
                    //
                    // Option 1: "Fully managed" framework approach
                    // - Is another recalculation in flight?
                    // - Provide a hook for the user to decide whether to proceed with recalculation (defaults to yes? if you don't want recalculation, change your off route detection criterion!)
                    // - If recalculating should proceed, fetch routes using `getRoutes`
                    // - Call back via hook point to select a route (defaults to the first route)
                    //
                    // Option 2: Minimal approach; give developers more flexibility but also require some boilerplate for simple cases
                    // - Offer an "off route listener" hook point
                    // - Let the developer decide whether to make the call to `getRoutes`
                    // - Let the developer handle selection of the new route
                    // - Let the developer call `startNavigation` with the new route
                    break
                }
            case .complete:
                // TODO: "You have arrived"?
                self.state?.visualInstructions = nil
                self.state?.snappedLocation = location  // We arrived; no more snapping needed
                self.state?.courseOverGround = location.course
                self.state?.spokenInstruction = nil
            }

            self.delegate?.core(self, didUpdateNavigationState: TripState(newState))

        }
    }
}

extension FerrostarCore: LocationManagingDelegate {
    @MainActor
    public func locationManager(_ manager: LocationProviding, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              let state = tripState,
              let newState = navigationController?.updateUserLocation(location: location.userLocation, state: state) else {
            return
        }
        
        update(newState: newState, location: location)
    }

    public func locationManager(_ manager: LocationProviding, didUpdateHeading newHeading: CLHeading) {
        state?.heading = newHeading
    }

    public func locationManager(_: LocationProviding, didFailWithError error: Error) {
        delegate?.core(self, locationManagerFailedWithError: error)
    }
}
