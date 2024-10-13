import Foundation

/// A Valhalla OSRM flavored annotations object.
public struct ValhallaOsrmAnnotation: Decodable {
    enum CodingKeys: String, CodingKey {
        case speedLimit = "maxspeed"
        case speed
        case distance
        case duration
        case congestion
        case congestionNumeric = "congestion_numeric"
    }

    /// The speed limit for the current line segment.
    public let speedLimit: MaxSpeed?

    public let speed: Double?

    public let distance: Double?

    public let duration: Double?
    
    public let congestion: String?
    
    public let congestionNumeric: Int?
}
