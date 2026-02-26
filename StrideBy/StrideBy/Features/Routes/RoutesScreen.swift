//
//  RoutesScreen.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import MapKit
import SwiftUI

struct RoutesScreen: View {
    @Environment(RouteManager.self) private var routeManager
    @Environment(RunProgressManager.self) private var progressManager
    @Environment(AnalyticsService.self) private var analytics

    @State private var routeToConfirm: RunRoute?
    var onRouteStarted: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(RunRoute.allRoutes) { route in
                        RouteExploreCard(
                            route: route,
                            isActive: route.id == routeManager.activeRouteKey,
                            isCompleted: routeManager.isCompleted(routeKey: route.id)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: StrideByTheme.cardCornerRadius))
                        .onTapGesture {
                            if route.id != routeManager.activeRouteKey {
                                routeToConfirm = route
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.secondarySystemBackground).opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $routeToConfirm) { route in
                RouteStartSheet(
                    route: route,
                    onStart: {
                        routeManager.startRoute(route, currentTotalMiles: progressManager.totalMiles)
                        analytics.track("route_started", properties: [
                            "route_id": route.id,
                            "route_name": route.name,
                            "start_miles_total": progressManager.totalMiles.formatted(.number.precision(.fractionLength(2)))
                        ])
                        onRouteStarted?()
                        routeToConfirm = nil
                    },
                    onCancel: {
                        routeToConfirm = nil
                    }
                )
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Route Card

private struct RouteExploreCard: View {
    let route: RunRoute
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        let style = RouteHeroStyle.forRoute(route)

        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                RouteHeroSnapshotView(route: route, coordinate: style.heroCoordinate)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: style.symbol)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                        Text(style.country)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Text(style.heroPOI)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(16)
            }
            .frame(height: 122)

            VStack(alignment: .leading, spacing: 10) {
                Text(route.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text("\(route.origin) → \(route.destination)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(Int(route.totalDistanceMiles)) mi", systemImage: "figure.run")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isActive {
                        routeStatusPill(text: "Active", color: StrideByTheme.accent)
                    } else if isCompleted {
                        routeStatusPill(text: "Completed", color: .green)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: StrideByTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: StrideByTheme.cardCornerRadius)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
        .padding(2.5)
        .overlay(
            RoundedRectangle(cornerRadius: StrideByTheme.cardCornerRadius + 2.5)
                .strokeBorder(Color(red: 0.85, green: 0.75, blue: 0.22).opacity(0.45), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 18, y: 6)
    }

    private func routeStatusPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Start Sheet

private struct RouteStartSheet: View {
    let route: RunRoute
    let onStart: () -> Void
    let onCancel: () -> Void

    var body: some View {
        let style = RouteHeroStyle.forRoute(route)

        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: style.colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(style.country.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(route.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .padding(18)
            }
            .frame(height: 150)

            VStack(alignment: .leading, spacing: 14) {
                Label("\(route.origin) → \(route.destination)", systemImage: "arrow.right")
                    .font(.subheadline)
                Label("\(Int(route.totalDistanceMiles)) miles", systemImage: "figure.run")
                    .font(.subheadline)

                Text("Only new runs will count toward this route after you start.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                HStack(spacing: 10) {
                    Button("Not now") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)

                    Button("Start Route") {
                        onStart()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(StrideByTheme.accent)
                }
                .padding(.top, 4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Visual Style

private struct RouteHeroStyle {
    let country: String
    let heroPOI: String
    let heroCoordinate: CLLocationCoordinate2D
    let symbol: String
    let colors: [Color]

    static func forRoute(_ route: RunRoute) -> RouteHeroStyle {
        switch route.id {
        case "paris-city-loop":
            return .init(country: "France", heroPOI: "Eiffel Tower", heroCoordinate: .init(latitude: 48.8584, longitude: 2.2945), symbol: "sparkles", colors: [.blue.opacity(0.9), .cyan.opacity(0.75)])
        case "london-city-loop":
            return .init(country: "United Kingdom", heroPOI: "Tower Bridge", heroCoordinate: .init(latitude: 51.5055, longitude: -0.0754), symbol: "crown.fill", colors: [.indigo.opacity(0.85), .blue.opacity(0.7)])
        case "new-york-city-loop":
            return .init(country: "United States", heroPOI: "Times Square", heroCoordinate: .init(latitude: 40.7580, longitude: -73.9855), symbol: "building.2.crop.circle.fill", colors: [.purple.opacity(0.8), .pink.opacity(0.7)])
        case "los-angeles-city-loop":
            return .init(country: "United States", heroPOI: "Hollywood", heroCoordinate: .init(latitude: 34.1016, longitude: -118.3267), symbol: "sun.max.fill", colors: [.orange.opacity(0.85), .pink.opacity(0.65)])
        case "san-francisco-city-loop":
            return .init(country: "United States", heroPOI: "Golden Gate Park", heroCoordinate: .init(latitude: 37.7694, longitude: -122.4862), symbol: "building.columns.fill", colors: [.red.opacity(0.85), .orange.opacity(0.7)])
        case "chicago-city-loop":
            return .init(country: "United States", heroPOI: "Lakefront Trail", heroCoordinate: .init(latitude: 41.8837, longitude: -87.6324), symbol: "wind", colors: [.teal.opacity(0.85), .blue.opacity(0.65)])
        case "berlin-city-loop":
            return .init(country: "Germany", heroPOI: "Brandenburg Gate", heroCoordinate: .init(latitude: 52.5163, longitude: 13.3777), symbol: "tram.fill", colors: [.gray.opacity(0.8), .black.opacity(0.65)])
        case "madrid-city-loop":
            return .init(country: "Spain", heroPOI: "Puerta del Sol", heroCoordinate: .init(latitude: 40.4169, longitude: -3.7035), symbol: "sun.haze.fill", colors: [.yellow.opacity(0.8), .orange.opacity(0.8)])
        case "barcelona-city-loop":
            return .init(country: "Spain", heroPOI: "Sagrada Familia", heroCoordinate: .init(latitude: 41.4036, longitude: 2.1744), symbol: "building.columns.fill", colors: [.mint.opacity(0.8), .green.opacity(0.65)])
        case "milan-city-loop":
            return .init(country: "Italy", heroPOI: "Duomo di Milano", heroCoordinate: .init(latitude: 45.4642, longitude: 9.1900), symbol: "camera.aperture", colors: [.gray.opacity(0.8), .blue.opacity(0.6)])
        case "rome-city-loop":
            return .init(country: "Italy", heroPOI: "Colosseum", heroCoordinate: .init(latitude: 41.8902, longitude: 12.4922), symbol: "laurel.leading", colors: [.brown.opacity(0.8), .orange.opacity(0.65)])
        case "tokyo-city-loop":
            return .init(country: "Japan", heroPOI: "Shibuya Crossing", heroCoordinate: .init(latitude: 35.6595, longitude: 139.7005), symbol: "tram.circle.fill", colors: [.pink.opacity(0.8), .red.opacity(0.65)])
        case "sydney-city-loop":
            return .init(country: "Australia", heroPOI: "Sydney Harbour", heroCoordinate: .init(latitude: -33.8610, longitude: 151.2127), symbol: "ferry.fill", colors: [.cyan.opacity(0.85), .blue.opacity(0.7)])
        case "toronto-city-loop":
            return .init(country: "Canada", heroPOI: "Distillery District", heroCoordinate: .init(latitude: 43.6503, longitude: -79.3596), symbol: "leaf.fill", colors: [.red.opacity(0.8), .pink.opacity(0.65)])
        default:
            return .init(
                country: route.destination,
                heroPOI: route.landmarks.first?.name ?? route.destination,
                heroCoordinate: route.landmarks.first?.coordinate ?? route.coordinates.first ?? .init(),
                symbol: route.icon,
                colors: [.blue.opacity(0.8), .indigo.opacity(0.7)]
            )
        }
    }
}

private struct RouteHeroSnapshotView: View {
    let route: RunRoute
    let coordinate: CLLocationCoordinate2D

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                ProgressView()
            }
        }
        .task(id: route.id) {
            if let cached = RouteHeroSnapshotCache.shared.image(forKey: route.id) {
                image = cached
                return
            }
            image = await renderSnapshot()
            if let image {
                RouteHeroSnapshotCache.shared.set(image, forKey: route.id)
            }
        }
    }

    private func renderSnapshot() async -> UIImage? {
        let flyover = MKMapSnapshotter.Options()
        flyover.mapType = .hybridFlyover
        flyover.camera = MKMapCamera(
            lookingAtCenter: coordinate,
            fromDistance: 420,
            pitch: 68,
            heading: 20
        )
        flyover.size = CGSize(width: 1000, height: 500)
        flyover.scale = displayScale

        do {
            let snapshot = try await MKMapSnapshotter(options: flyover).start()
            return snapshot.image
        } catch {
            // Fallback where flyover isn't available.
            let fallback = MKMapSnapshotter.Options()
            fallback.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 650,
                longitudinalMeters: 650
            )
            fallback.mapType = .hybrid
            fallback.size = CGSize(width: 1000, height: 500)
            fallback.scale = displayScale

            do {
                let snapshot = try await MKMapSnapshotter(options: fallback).start()
                return snapshot.image
            } catch {
                return nil
            }
        }
    }
}

private final class RouteHeroSnapshotCache {
    static let shared = RouteHeroSnapshotCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {}

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

#Preview {
    RoutesScreen()
        .environment(RouteManager())
        .environment(RunProgressManager())
}
