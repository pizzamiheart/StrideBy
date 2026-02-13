//
//  MapScreen.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import MapKit
import SwiftUI

struct MapScreen: View {
    @Environment(StravaAuthService.self) private var stravaAuth
    @Environment(RunProgressManager.self) private var progressManager

    let route: RunRoute = .nycToLA

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 38.5, longitude: -96.0),
            span: MKCoordinateSpan(latitudeDelta: 28, longitudeDelta: 40)
        )
    )

    private var completedMiles: Double {
        min(progressManager.totalMiles, route.totalDistanceMiles)
    }

    private var progress: UserProgress {
        UserProgress(
            completedMiles: completedMiles,
            nearestLocationName: route.nearestLocationName(atMiles: completedMiles)
        )
    }

    private var currentCoordinate: CLLocationCoordinate2D {
        route.coordinateAt(miles: completedMiles)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed map
            Map(position: $cameraPosition) {

                // Completed route — accent color
                MapPolyline(coordinates: route.completedCoordinates(miles: completedMiles))
                    .stroke(
                        StrideByTheme.accent,
                        style: StrokeStyle(
                            lineWidth: StrideByTheme.routeLineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                // Remaining route — faded gray
                MapPolyline(coordinates: route.remainingCoordinates(miles: completedMiles))
                    .stroke(
                        StrideByTheme.routeRemaining,
                        style: StrokeStyle(
                            lineWidth: StrideByTheme.routeLineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                // Origin marker
                Annotation("", coordinate: route.coordinates.first!) {
                    RouteDotView(label: route.origin, isFilled: true)
                }

                // Destination marker
                Annotation("", coordinate: route.coordinates.last!) {
                    RouteDotView(label: route.destination, isFilled: false)
                }

                // Current position pin
                Annotation("", coordinate: currentCoordinate) {
                    UserPinView()
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
                    isSyncing: progressManager.isLoading
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .task {
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

#Preview {
    MapScreen()
        .environment(StravaAuthService())
        .environment(RunProgressManager())
}
