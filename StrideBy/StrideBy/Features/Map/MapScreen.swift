//
//  MapScreen.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import MapKit
import SwiftUI

/// An identifiable target for the Look Around sheet.
private struct LookAroundTarget: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let seedCoordinates: [CLLocationCoordinate2D]
    let searchQueries: [String]
}

struct MapScreen: View {
    @Environment(StravaAuthService.self) private var stravaAuth
    @Environment(RunProgressManager.self) private var progressManager
    @Environment(RouteManager.self) private var routeManager
    @Environment(RouteGeometryManager.self) private var routeGeometryManager

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var lookAroundTarget: LookAroundTarget?

    private var route: RunRoute? {
        routeManager.activeRoute
    }

    private var routeProgressMiles: Double {
        routeManager.progressMiles(totalMiles: progressManager.totalMiles)
    }

    private var completedMiles: Double {
        guard let route else { return 0 }
        return min(routeProgressMiles, route.totalDistanceMiles)
    }

    private var isRouteComplete: Bool {
        routeManager.isRouteComplete(totalMiles: progressManager.totalMiles)
    }

    private var progress: UserProgress {
        guard let route else {
            return UserProgress(completedMiles: 0, nearestLocationName: "")
        }
        return UserProgress(
            completedMiles: completedMiles,
            nearestLocationName: route.nearestLocationName(atMiles: completedMiles)
        )
    }

    private var currentCoordinate: CLLocationCoordinate2D? {
        guard let route else { return nil }
        return route.coordinateAt(miles: completedMiles, using: activeCoordinates(for: route))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let route {
                // Full-bleed map
                Map(position: $cameraPosition) {

                    // Completed route — accent color
                    MapPolyline(coordinates: route.completedCoordinates(
                        miles: completedMiles,
                        using: activeCoordinates(for: route)
                    ))
                        .stroke(
                            StrideByTheme.accent,
                            style: StrokeStyle(
                                lineWidth: StrideByTheme.routeLineWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )

                    // Remaining route — faded gray
                    MapPolyline(coordinates: route.remainingCoordinates(
                        miles: completedMiles,
                        using: activeCoordinates(for: route)
                    ))
                        .stroke(
                            StrideByTheme.routeRemaining,
                            style: StrokeStyle(
                                lineWidth: StrideByTheme.routeLineWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )

                    // Origin marker
                    Annotation("", coordinate: activeCoordinates(for: route).first ?? route.coordinates.first!) {
                        RouteDotView(label: route.origin, isFilled: true)
                    }

                    // Destination marker
                    Annotation("", coordinate: activeCoordinates(for: route).last ?? route.coordinates.last!) {
                        RouteDotView(label: route.destination, isFilled: isRouteComplete)
                    }

                    // Current position pin
                    if let currentCoordinate {
                        Annotation("", coordinate: currentCoordinate) {
                            UserPinView()
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea(edges: .top)

                // Bottom cards
                VStack(spacing: 10) {
                    if !stravaAuth.isAuthenticated {
                        ConnectStravaCard()
                    }

                    RouteProgressCard(
                        route: route,
                        progress: progress,
                        isSyncing: progressManager.isLoading,
                        isComplete: isRouteComplete,
                        onLookAroundHere: {
                            if let coord = currentCoordinate {
                                let nearbyPOIs = route.nearestPOIs(atMiles: completedMiles, limit: 10)
                                let candidateMiles = [-8.0, -4.0, -2.0, 0, 2.0, 4.0, 8.0]
                                    .map { completedMiles + $0 }
                                let activePath = activeCoordinates(for: route)
                                let routeCandidates = candidateMiles.map {
                                    route.coordinateAt(miles: $0, using: activePath)
                                }

                                let primaryName = route.nearestLocationName(atMiles: completedMiles)
                                let seeds = [coord]
                                    + routeCandidates
                                    + nearbyPOIs.map(\.coordinate)
                                let queries = [primaryName] + nearbyPOIs.map { "\($0.name), \($0.state)" }

                                lookAroundTarget = LookAroundTarget(
                                    name: primaryName,
                                    coordinate: coord,
                                    seedCoordinates: seeds,
                                    searchQueries: queries
                                )
                            }
                        },
                        onLookAroundNearestPOI: {
                            let nearbyPOIs = route.nearestPOIs(atMiles: completedMiles, limit: 14)
                            if let poi = nearbyPOIs.first {
                                let queries = ["\(poi.name), \(poi.state)"]
                                    + nearbyPOIs.map { "\($0.name), \($0.state)" }
                                lookAroundTarget = LookAroundTarget(
                                    name: "\(poi.name), \(poi.state)",
                                    coordinate: poi.coordinate,
                                    seedCoordinates: nearbyPOIs.map(\.coordinate),
                                    searchQueries: queries
                                )
                            }
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .overlay(alignment: .topTrailing) {
            #if DEBUG
            DebugMilesOverlay(progressManager: progressManager)
            #endif
        }
        .task {
            // Set initial camera to the active route's bounding region
            if let route {
                cameraPosition = .region(region(for: activeCoordinates(for: route)))
                await routeGeometryManager.warmGeometry(for: route)
            }

            // Auto-sync on appear if authenticated
            if stravaAuth.isAuthenticated {
                await progressManager.sync(using: stravaAuth)
            }
        }
        .onChange(of: stravaAuth.isAuthenticated) { _, isAuth in
            // Sync immediately after connecting Strava
            if isAuth {
                Task { await progressManager.sync(using: stravaAuth) }
            }
        }
        .onChange(of: routeManager.activeRouteKey) {
            // Pan camera when the user switches routes
            if let route {
                withAnimation(StrideByTheme.defaultSpring) {
                    cameraPosition = .region(region(for: activeCoordinates(for: route)))
                }
                Task {
                    await routeGeometryManager.warmGeometry(for: route)
                }
            }
        }
        .onChange(of: routeGeometryManager.revision) {
            if let route {
                withAnimation(StrideByTheme.defaultSpring) {
                    cameraPosition = .region(region(for: activeCoordinates(for: route)))
                }
            }
        }
        .onChange(of: isRouteComplete) { _, complete in
            // Auto-mark route complete when threshold is crossed
            if complete {
                routeManager.markActiveRouteComplete()
            }
        }
        .fullScreenCover(item: $lookAroundTarget) { target in
            LookAroundSheet(
                locationName: target.name,
                coordinate: target.coordinate,
                seedCoordinates: target.seedCoordinates,
                searchQueries: target.searchQueries
            )
        }
    }

    private func activeCoordinates(for route: RunRoute) -> [CLLocationCoordinate2D] {
        routeGeometryManager.coordinates(for: route)
    }

    private func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else { return MKCoordinateRegion() }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.35, 0.8),
                longitudeDelta: max((maxLon - minLon) * 1.35, 0.8)
            )
        )
    }
}

// MARK: - Route Endpoint Dots

private struct RouteDotView: View {
    let label: String
    let isFilled: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())

            Circle()
                .fill(isFilled ? AnyShapeStyle(StrideByTheme.accent) : AnyShapeStyle(.gray.opacity(0.5)))
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
        }
    }
}

// MARK: - Debug Overlay

#if DEBUG
private struct DebugMilesOverlay: View {
    let progressManager: RunProgressManager

    var body: some View {
        VStack(spacing: 6) {
            Text("DEBUG")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.7))

            Button("+50 mi") {
                progressManager.addDebugMiles(50)
            }

            Button("+200 mi") {
                progressManager.addDebugMiles(200)
            }

            Button("Reset") {
                progressManager.resetDebugProgress()
            }
        }
        .font(.caption)
        .fontWeight(.medium)
        .buttonStyle(.borderedProminent)
        .tint(.black.opacity(0.5))
        .controlSize(.mini)
        .padding(.top, 60)
        .padding(.trailing, 12)
    }
}
#endif

#Preview {
    MapScreen()
        .environment(StravaAuthService())
        .environment(RunProgressManager())
        .environment(RouteManager())
        .environment(RouteGeometryManager())
}
