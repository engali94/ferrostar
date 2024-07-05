import { advanceLocationSimulation, locationSimulationFromRoute } from "ferrostar";

export class SimulatedLocationProvider {
  private simulationState = null;

  lastLocation = null;
  lastHeading = null;
  warpFactor = 1;

  updateCallback: () => void;

  setSimulatedRoute(route) {
    this.simulationState = locationSimulationFromRoute(route, 10.0);
    this.startSimulation();
  }

  async startSimulation() {
    while (true) {
      await new Promise((resolve) => setTimeout(resolve, (1 / this.warpFactor) * 1000));
      const initialState = this.simulationState;
      const updatedState = advanceLocationSimulation(initialState);

      if (initialState === updatedState) {
        return;
      }

      this.simulationState = updatedState;
      this.lastLocation = updatedState.current_location;

      // Since Lit cannot detect changes inside objects, here we use a callback to trigger a re-render
      // This is a minimal approach if we don't want to use a state management library like MobX, but might not be the ideal solution
      if (this.updateCallback) {
        this.updateCallback();
      }
    }
  }

  stopSimulation() {
    this.simulationState = null;
  }
}
