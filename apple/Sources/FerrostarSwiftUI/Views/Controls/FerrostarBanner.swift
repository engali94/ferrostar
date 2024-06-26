import SwiftUI

public struct FerrostarBanner<Label: View>: View {
    public enum Severity {
        case info, error, loading
    }

    var severity: Severity
    var backgroundColor: Color
    var label: Label

    /// The basic Ferrostar SwiftUI button style.
    ///
    /// - Parameters:
    ///   - action: The action the button performs on tap.
    ///   - backgroundColor: The capsule's background color.
    ///   - label: The label subview.
    public init(
        severity: FerrostarBanner.Severity,
        backgroundColor: Color = Color(.systemBackground),
        @ViewBuilder label: () -> Label
    ) {
        self.severity = severity
        self.backgroundColor = backgroundColor
        self.label = label()
    }

    public var body: some View {
        HStack {
            image(for: severity)

            label
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(backgroundColor)
        .clipShape(Capsule())
    }

    @ViewBuilder func image(for severity: FerrostarBanner.Severity) -> some View {
        switch severity {
        case .info:
            Image(systemName: "info.circle.fill")
        case .error:
            Image(systemName: "exclamationmark.triangle")
        case .loading:
            Image(systemName: "hourglass.circle.fill")
        }
    }
}

#Preview {
    VStack {
        FerrostarBanner(severity: .info) {
            Text(verbatim: "Something Useful")
        }

        FerrostarBanner(severity: .loading) {
            Text(verbatim: "Rerouting...")
        }

        FerrostarBanner(severity: .error) {
            Text(verbatim: "No Location Available")
        }
    }
    .padding()
    .background(Color.green)
}