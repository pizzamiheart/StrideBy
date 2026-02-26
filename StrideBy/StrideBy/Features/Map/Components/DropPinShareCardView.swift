//
//  DropPinShareCardView.swift
//  StrideBy
//
//  Created by Codex on 2/25/26.
//

import CoreLocation
import MapKit
import SwiftUI
import UIKit

enum DropPinBackdropPreset: String, CaseIterable, Identifiable {
    case aurora
    case cobalt
    case sunset
    case ember
    case graphite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aurora: return "Aurora"
        case .cobalt: return "Cobalt"
        case .sunset: return "Sunset"
        case .ember: return "Ember"
        case .graphite: return "Graphite"
        }
    }

    var colors: [Color] {
        switch self {
        case .aurora:
            return [Color(red: 0.07, green: 0.09, blue: 0.18), Color(red: 0.09, green: 0.36, blue: 0.45), Color(red: 0.24, green: 0.60, blue: 0.48)]
        case .cobalt:
            return [Color(red: 0.03, green: 0.06, blue: 0.17), Color(red: 0.07, green: 0.21, blue: 0.45), Color(red: 0.26, green: 0.54, blue: 0.83)]
        case .sunset:
            return [Color(red: 0.22, green: 0.06, blue: 0.13), Color(red: 0.50, green: 0.19, blue: 0.23), Color(red: 0.88, green: 0.49, blue: 0.23)]
        case .ember:
            return [Color(red: 0.14, green: 0.06, blue: 0.05), Color(red: 0.39, green: 0.13, blue: 0.10), Color(red: 0.69, green: 0.27, blue: 0.14)]
        case .graphite:
            return [Color(red: 0.07, green: 0.08, blue: 0.10), Color(red: 0.13, green: 0.15, blue: 0.17), Color(red: 0.22, green: 0.24, blue: 0.28)]
        }
    }

    var swatchColor: Color {
        colors[1]
    }
}

enum DropPinOutlineStyle: String, CaseIterable, Identifiable {
    case subtle
    case bold
    case glow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .subtle: return "Subtle"
        case .bold: return "Bold"
        case .glow: return "Glow"
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .subtle: return 5
        case .bold: return 8
        case .glow: return 7
        }
    }
}

struct DropPinCardStyle {
    var backdrop: DropPinBackdropPreset = .aurora
    var outlineStyle: DropPinOutlineStyle = .bold
}

struct DropPinDraft: Identifiable {
    let id = UUID()
    let capturedImage: UIImage
    let initialScene: MKLookAroundScene?
    let route: RunRoute?
    let routeName: String
    let locationName: String
    let completedMiles: Double
    let lastRunMiles: Double
}

struct DropPinShareCardView: View {
    @AppStorage("strideby_distance_unit") private var distanceUnitRawValue = DistanceUnit.miles.rawValue

    let lookAroundImage: UIImage
    let route: RunRoute?
    let routeName: String
    let locationName: String
    let completedMiles: Double
    let lastRunMiles: Double
    var style: DropPinCardStyle = .init()
    var stageContent: AnyView? = nil

    private var distanceUnit: DistanceUnit {
        DistanceUnit(rawValue: distanceUnitRawValue) ?? .miles
    }

    private var lastRunText: String {
        let value = distanceUnit.convert(miles: max(0, lastRunMiles))
            .formatted(.number.precision(.fractionLength(1)))
        return "\(value) \(distanceUnit.abbreviation)"
    }

    private var progressText: String {
        guard let route else { return "--" }
        let value = distanceUnit.convert(miles: completedMiles)
            .formatted(.number.precision(.fractionLength(1)))
        let total = distanceUnit.convert(miles: route.totalDistanceMiles)
            .formatted(.number.precision(.fractionLength(1)))
        return "\(value) / \(total) \(distanceUnit.abbreviation)"
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: style.backdrop.colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    screenshotStage(height: proxy.size.height * 0.58)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(routeName)
                            .font(.system(size: 27, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)

                        statsRow
                    }
                    .padding(14)
                    .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Spacer(minLength: 8)

                    Text("StrideBy")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                }
                .padding(20)
            }
        }
    }

    private func screenshotStage(height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.24), lineWidth: 1)
                )

            RouteTraceShape(coordinates: route?.coordinates ?? [])
                .stroke(
                    routeStrokeStyle(),
                    style: StrokeStyle(
                        lineWidth: style.outlineStyle.lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .padding(18)
                .shadow(color: outlineShadowColor(), radius: style.outlineStyle == .glow ? 10 : 0)

            stageLayer
        }
        .frame(height: height)
    }

    private var stageLayer: some View {
        Group {
            if let stageContent {
                stageContent
            } else {
                Image(uiImage: lookAroundImage)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.92), lineWidth: 2)
        )
        .overlay(alignment: .topTrailing) {
            Label("Look Around", systemImage: "binoculars.fill")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.38), in: Capsule())
                .padding(10)
        }
        .overlay(alignment: .bottomLeading) {
            Text("Apple Maps")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.black.opacity(0.35), in: Capsule())
                .padding(10)
        }
        .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
        .padding(30)
    }

    private var statsRow: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 10
            let locationWidth = max(92, proxy.size.width * 0.24)
            let remaining = max(0, proxy.size.width - locationWidth - (spacing * 2))
            let mainWidth = remaining / 2

            HStack(alignment: .center, spacing: spacing) {
                statPill(title: "Last Run", value: lastRunText, valueFontSize: 16)
                    .frame(width: mainWidth, alignment: .leading)
                statPill(title: "Route", value: progressText, valueFontSize: 15, minScale: 0.68)
                    .frame(width: mainWidth, alignment: .leading)
                statPill(title: "Location", value: locationName, compact: true)
                    .frame(width: locationWidth, alignment: .leading)
            }
        }
        .frame(height: 62)
    }

    private func routeStrokeStyle() -> some ShapeStyle {
        switch style.outlineStyle {
        case .subtle:
            return AnyShapeStyle(.white.opacity(0.86))
        case .bold:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.white.opacity(0.97), StrideByTheme.accent.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .glow:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [StrideByTheme.accent.opacity(0.95), .white.opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private func outlineShadowColor() -> Color {
        style.outlineStyle == .glow
        ? StrideByTheme.accent.opacity(0.58)
        : .clear
    }

    private func statPill(
        title: String,
        value: String,
        compact: Bool = false,
        valueFontSize: CGFloat? = nil,
        minScale: CGFloat? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.72))

            Text(value)
                .font(.system(size: valueFontSize ?? (compact ? 14 : 17), weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(minScale ?? (compact ? 0.62 : 0.72))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct RouteTraceShape: Shape {
    let coordinates: [CLLocationCoordinate2D]

    func path(in rect: CGRect) -> Path {
        guard coordinates.count > 1 else {
            return RoundedRectangle(cornerRadius: 24, style: .continuous).path(in: rect.insetBy(dx: 14, dy: 14))
        }

        let sampled = sampledCoordinates(maxPoints: 300)
        let lats = sampled.map(\.latitude)
        let lons = sampled.map(\.longitude)

        guard let minLat = lats.min(),
              let maxLat = lats.max(),
              let minLon = lons.min(),
              let maxLon = lons.max() else {
            return Path()
        }

        let midLat = (minLat + maxLat) / 2
        let midLon = (minLon + maxLon) / 2

        let rawLatSpan = max(maxLat - minLat, 0.000001)
        let rawLonSpan = max(maxLon - minLon, 0.000001)
        let maxSpan = max(rawLatSpan, rawLonSpan)

        // Prevent almost-flat routes from collapsing to one line visually.
        let latSpan = max(rawLatSpan, maxSpan * 0.28)
        let lonSpan = max(rawLonSpan, maxSpan * 0.28)

        let drawRect = rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08)

        var path = Path()
        for (index, coordinate) in sampled.enumerated() {
            let xProgress = (coordinate.longitude - midLon) / lonSpan
            let yProgress = (coordinate.latitude - midLat) / latSpan

            // Push the path toward the frame edge so "mostly straight" routes still
            // read as a border trace instead of a single interior line.
            let edgeBias = 0.42
            let dominant = max(abs(xProgress), abs(yProgress), 0.0001)
            let edgeX = xProgress / dominant
            let edgeY = yProgress / dominant

            let framedX = (xProgress * (1 - edgeBias)) + (edgeX * edgeBias)
            let framedY = (yProgress * (1 - edgeBias)) + (edgeY * edgeBias)

            let point = CGPoint(
                x: drawRect.midX + (framedX * drawRect.width * 0.9),
                y: drawRect.midY - (framedY * drawRect.height * 0.9)
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }

    private func sampledCoordinates(maxPoints: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPoints else { return coordinates }
        let strideSize = max(1, coordinates.count / maxPoints)
        return stride(from: 0, to: coordinates.count, by: strideSize).map { coordinates[$0] }
    }
}

@MainActor
enum DropPinShareCardRenderer {
    static func makeStoryImage(
        lookAroundImage: UIImage,
        route: RunRoute?,
        routeName: String,
        locationName: String,
        completedMiles: Double,
        lastRunMiles: Double,
        style: DropPinCardStyle,
        cardSize: CGSize = CGSize(width: 360, height: 640),
        scale: CGFloat = 3
    ) -> UIImage? {
        let content = DropPinShareCardView(
            lookAroundImage: lookAroundImage,
            route: route,
            routeName: routeName,
            locationName: locationName,
            completedMiles: completedMiles,
            lastRunMiles: lastRunMiles,
            style: style
        )
        .frame(width: cardSize.width, height: cardSize.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        return renderer.uiImage
    }
}

#Preview {
    DropPinShareCardView(
        lookAroundImage: UIImage(systemName: "globe") ?? UIImage(),
        route: .parisCityLoop,
        routeName: "Paris Arrondissement Tour",
        locationName: "Near Eiffel Tower",
        completedMiles: 11.4,
        lastRunMiles: 3.2
    )
}
