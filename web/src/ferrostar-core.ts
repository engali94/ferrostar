import { LitElement, html, css, unsafeCSS } from "lit";
import { customElement, property } from "lit/decorators.js";
import leafletStyles from "leaflet/dist/leaflet.css?inline";
import L from "leaflet";
import markerIconUrl from "../node_modules/leaflet/dist/images/marker-icon.png";
import markerIconRetinaUrl from "../node_modules/leaflet/dist/images/marker-icon-2x.png";
import markerShadowUrl from "../node_modules/leaflet/dist/images/marker-shadow.png";
import init, { NavigationController, RouteAdapter } from "ferrostar";

@customElement("ferrostar-core")
class FerrostarCore extends LitElement {
  @property()
  valhallaEndpointUrl: string = "";

  @property()
  profile: string = "";

  @property({ attribute: false })
  httpClient?: Function = fetch;

  // TODO: type
  @property({ type: Object })
  locationProvider!: any;

  // TODO: type
  @property({ type: Object })
  costingOptions!: any;

  routeAdapter: RouteAdapter | null = null;
  map: L.Map | null = null;
  navigationController: NavigationController | null = null;
  currentLocationMapMarker: L.Marker | null = null;

  static styles = [
    unsafeCSS(leafletStyles),
    css`
      #map {
        height: 100%;
        width: 100%;
      }
    `,
  ];

  constructor() {
    super();

    // A workaround for avoiding "Illegal invocation"
    if (this.httpClient === fetch) {
      this.httpClient = this.httpClient.bind(window);
    }

    // A workaround for loading the marker icon images in Vite
    L.Icon.Default.prototype.options.iconUrl = markerIconUrl;
    L.Icon.Default.prototype.options.iconRetinaUrl = markerIconRetinaUrl;
    L.Icon.Default.prototype.options.shadowUrl = markerShadowUrl;
  }

  updated(changedProperties: any) {
    if (changedProperties.has('locationProvider') && this.locationProvider) {
      this.locationProvider.updateCallback = this.onLocationUpdated.bind(this);
    }
  }

  firstUpdated() {
    this.map = L.map(this.shadowRoot!.getElementById("map")!).setView([0, 0], 13);

    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    }).addTo(this.map);
  }

  // TODO: type
  async getRoutes(initialLocation: any, waypoints: any) {
    await init();
    this.routeAdapter = new RouteAdapter(this.valhallaEndpointUrl, this.profile);

    const body = this.routeAdapter.generate_request(initialLocation, waypoints).get("body");
    // FIXME: assert httpClient is not null
    const response = await this.httpClient!(this.valhallaEndpointUrl, {
      method: "POST",
      // FIXME: assert body is not null
      body: new Uint8Array(body).buffer,
    });
    const responseData = new Uint8Array(await response.arrayBuffer());
    const routes = this.routeAdapter.parse_response(responseData);

    return routes;
  }

  // TODO: type
  async startNavigation(route: any, config: any) {
    this.locationProvider.updateCallback = this.onLocationUpdated.bind(this);
    this.navigationController = new NavigationController(route, config);

    const startingLocation = this.locationProvider.lastLocation
      ? this.locationProvider.lastLocation
      : {
          coordinates: route.geometry[0],
          horizontal_accuracy: 0.0,
          course_over_ground: null,
          // TODO: find a better way to create the timestamp?
          timestamp: {
            secs_since_epoch: Math.floor(Date.now() / 1000),
            nanos_since_epoch: 0,
          },
          speed: null,
        };

    // FIXME: should be camelCase
    const initialTripState = this.navigationController.get_initial_state(startingLocation);
    this.handleStateUpdate(initialTripState, startingLocation);

    const polyline = L.polyline(route.geometry, { color: "red" }).addTo(this.map!);
    this.map!.fitBounds(polyline.getBounds());

    this.currentLocationMapMarker = L.marker(route.geometry[0]).addTo(this.map!);
  }

  async replaceRoute(route: any, config: any) {
    // TODO
  }

  async advanceToNextStep() {
    // TODO
  }

  async stopNavigation() {
    // TODO
  }

  private async handleStateUpdate(newState: any, location: any) {
    // TODO
  }

  private onLocationUpdated() {
    this.currentLocationMapMarker!.setLatLng(this.locationProvider.lastLocation.coordinates);
  }

  render() {
    return html`<div id="map"></div>`;
  }
}