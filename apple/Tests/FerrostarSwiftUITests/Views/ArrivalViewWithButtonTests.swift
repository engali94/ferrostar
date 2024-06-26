import XCTest
@testable import FerrostarCoreFFI
@testable import FerrostarSwiftUI

final class ArrivalViewWithButtonTests: XCTestCase {
    let referenceDate = Date(timeIntervalSince1970: 1_718_065_239)

    var etaFormatter: Date.FormatStyle = .init(timeZone: .init(secondsFromGMT: 0)!)
        .hour(.defaultDigits(amPM: .abbreviated))
        .minute(.twoDigits)

    var informationalTheme: any ArrivalViewTheme {
        var theme = DefaultArrivalViewTheme()
        theme.style = .informational
        return theme
    }

    func testArrivalViewDefaultTheme() {
        assertView {
            ArrivalView(
                progress: TripProgress(
                    distanceToNextManeuver: 123,
                    distanceRemaining: 120,
                    durationRemaining: 150
                ),
                estimatedArrivalFormatter: etaFormatter,
                fromDate: referenceDate,
                onTapExit: { }
            )
        }

        assertView {
            ArrivalView(
                progress: TripProgress(
                    distanceToNextManeuver: 5420,
                    distanceRemaining: 1_420_000,
                    durationRemaining: 520_800
                ),
                estimatedArrivalFormatter: etaFormatter,
                fromDate: referenceDate,
                onTapExit: { }
            )
        }
    }

    func testArrivalViewCompactTheme() {
        assertView {
            ArrivalView(
                progress: TripProgress(
                    distanceToNextManeuver: 5420,
                    distanceRemaining: 1_420_000,
                    durationRemaining: 520_800
                ),
                estimatedArrivalFormatter: etaFormatter,
                theme: informationalTheme,
                fromDate: referenceDate,
                onTapExit: { }
            )
        }
    }

    func testArrivalViewFormatters() {
        assertView {
            ArrivalView(
                progress: TripProgress(
                    distanceToNextManeuver: 5420,
                    distanceRemaining: 1_420_000,
                    durationRemaining: 520_800
                ),
                distanceFormatter: germanDistanceFormatter,
                estimatedArrivalFormatter: etaFormatter,
                durationFormatter: longDurationFormatter,
                fromDate: referenceDate,
                onTapExit: { }
            )
        }
    }

    func testArrivalViewFormatters_de_DE() {
        assertView {
            ArrivalView(
                progress: TripProgress(
                    distanceToNextManeuver: 123,
                    distanceRemaining: 14500,
                    durationRemaining: 1234
                ),
                distanceFormatter: germanDistanceFormatter,
                estimatedArrivalFormatter: germanArrivalFormatter,
                fromDate: referenceDate,
                onTapExit: { }
            )
            .environment(\.locale, .init(identifier: "de_DE"))
        }

        assertView {
            ArrivalView(
                progress: TripProgress(
                    distanceToNextManeuver: 5420,
                    distanceRemaining: 1_420_000,
                    durationRemaining: 520_800
                ),
                distanceFormatter: germanDistanceFormatter,
                estimatedArrivalFormatter: germanArrivalFormatter,
                theme: informationalTheme,
                fromDate: referenceDate,
                onTapExit: { }
            )
            .environment(\.locale, .init(identifier: "de_DE"))
        }
    }

    // MARK: Dark Mode

    func testArrivalViewDefaultTheme_darkMode() {
        assertView(colorScheme: .dark) {
            ArrivalView(
                progress: TripProgress(
                    distanceToNextManeuver: 123,
                    distanceRemaining: 120,
                    durationRemaining: 150
                ),
                estimatedArrivalFormatter: etaFormatter,
                fromDate: referenceDate,
                onTapExit: { }
            )
        }

        assertView(colorScheme: .dark) {
            ArrivalView(
                progress: TripProgress(
                    distanceToNextManeuver: 5420,
                    distanceRemaining: 1_420_000,
                    durationRemaining: 520_800
                ),
                estimatedArrivalFormatter: etaFormatter,
                fromDate: referenceDate,
                onTapExit: { }
            )
        }
    }

    func testArrivalViewCompactTheme_darkMode() {
        assertView(colorScheme: .dark) {
            ArrivalView(
                progress: TripProgress(
                    distanceToNextManeuver: 5420,
                    distanceRemaining: 1_420_000,
                    durationRemaining: 520_800
                ),
                estimatedArrivalFormatter: etaFormatter,
                theme: informationalTheme,
                fromDate: referenceDate,
                onTapExit: { }
            )
        }
    }

    func testArrivalViewFormatters_darkMode() {
        assertView(colorScheme: .dark) {
            ArrivalView(
                progress: TripProgress(
                    distanceToNextManeuver: 5420,
                    distanceRemaining: 1_420_000,
                    durationRemaining: 520_800
                ),
                distanceFormatter: germanDistanceFormatter,
                estimatedArrivalFormatter: etaFormatter,
                durationFormatter: longDurationFormatter,
                fromDate: referenceDate,
                onTapExit: { }
            )
        }
    }

    func testArrivalViewFormatters_de_DE_darkMode() {
        assertView(colorScheme: .dark) {
            ArrivalView(
                progress: TripProgress(
                    distanceToNextManeuver: 123,
                    distanceRemaining: 14500,
                    durationRemaining: 1234
                ),
                distanceFormatter: germanDistanceFormatter,
                estimatedArrivalFormatter: germanArrivalFormatter,
                fromDate: referenceDate,
                onTapExit: { }
            )
            .environment(\.locale, .init(identifier: "de_DE"))
        }

        assertView(colorScheme: .dark) {
            ArrivalView(
                progress: TripProgress(
                    distanceToNextManeuver: 5420,
                    distanceRemaining: 1_420_000,
                    durationRemaining: 520_800
                ),
                distanceFormatter: germanDistanceFormatter,
                estimatedArrivalFormatter: germanArrivalFormatter,
                theme: informationalTheme,
                fromDate: referenceDate,
                onTapExit: { }
            )
            .environment(\.locale, .init(identifier: "de_DE"))
        }
    }
}