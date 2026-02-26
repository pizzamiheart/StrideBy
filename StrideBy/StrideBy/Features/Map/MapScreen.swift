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
    let completedMiles: Double
    let lastRunMiles: Double
    let routeName: String
    let route: RunRoute?
}

private struct PostRunCelebration: Identifiable {
    let id = UUID()
    let milesAdvanced: Double
    let locationName: String
}

struct MapScreen: View {
    @Environment(StravaAuthService.self) private var stravaAuth
    @Environment(RunProgressManager.self) private var progressManager
    @Environment(RouteManager.self) private var routeManager
    @Environment(RouteGeometryManager.self) private var routeGeometryManager
    @Environment(AnalyticsService.self) private var analytics
    @AppStorage("strideby_distance_unit") private var distanceUnitRawValue = DistanceUnit.miles.rawValue

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var lookAroundTarget: LookAroundTarget?
    @State private var postRunCelebration: PostRunCelebration?
    @State private var celebrationDismissTask: Task<Void, Never>?
    @State private var handledSyncRevision = 0
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var showPortalEffect = false
    @State private var portalPulse = false

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

                    // Route glow — wider halo behind completed segment
                    MapPolyline(coordinates: route.completedCoordinates(
                        miles: completedMiles,
                        using: activeCoordinates(for: route)
                    ))
                        .stroke(
                            StrideByTheme.accentGlow,
                            style: StrokeStyle(
                                lineWidth: 14,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )

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

                    if let postRunCelebration {
                        PostRunCelebrationCard(
                            milesAdvanced: postRunCelebration.milesAdvanced,
                            locationName: postRunCelebration.locationName,
                            onDismiss: dismissCelebration,
                            onShare: {
                                shareCelebration(
                                    postRunCelebration,
                                    route: route
                                )
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    RouteProgressCard(
                        route: route,
                        progress: progress,
                        isSyncing: progressManager.isLoading,
                        isComplete: isRouteComplete,
                        onLookAroundHere: {
                            if let coord = currentCoordinate {
                                let activePath = activeCoordinates(for: route)

                                // Use the nearest curated POI's town center as the
                                // primary search coordinate — Look Around coverage
                                // clusters in town centers, not on highway overpasses.
                                let nearestPOI = route.nearestPOI(atMiles: completedMiles)
                                let primaryCoord = nearestPOI?.coordinate ?? coord

                                // Keep the actual highway pin + nearby road points as seeds
                                let candidateMiles = [-4.0, -2.0, 0, 2.0, 4.0]
                                    .map { completedMiles + $0 }
                                let routeCandidates = candidateMiles.map {
                                    route.coordinateAt(miles: $0, using: activePath)
                                }

                                let primaryName = route.nearestLocationName(atMiles: completedMiles)

                                let target = LookAroundTarget(
                                    name: primaryName,
                                    coordinate: primaryCoord,
                                    seedCoordinates: [coord] + routeCandidates,
                                    searchQueries: [],
                                    completedMiles: completedMiles,
                                    lastRunMiles: progressManager.latestRunMiles,
                                    routeName: route.name,
                                    route: route
                                )
                                launchLookAroundPortal(to: target)
                            }
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .animation(StrideByTheme.defaultSpring, value: postRunCelebration?.id)
            }
        }
        .overlay(alignment: .top) {
            if let route {
                MapRouteHeader(routeName: route.name)
            }
        }
        .overlay {
            if showPortalEffect {
                LookAroundPortalEffectView(isPulsing: portalPulse)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
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
        .onChange(of: progressManager.syncRevision) { _, revision in
            guard revision > handledSyncRevision else { return }
            handledSyncRevision = revision

            guard progressManager.lastSyncGainMiles > 0, let route else { return }
            let locationName = route.nearestLocationName(atMiles: completedMiles)
            showCelebration(
                milesAdvanced: progressManager.lastSyncGainMiles,
                locationName: locationName
            )
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
                searchQueries: target.searchQueries,
                completedMiles: target.completedMiles,
                lastRunMiles: target.lastRunMiles,
                routeName: target.routeName,
                route: target.route
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(
                activityItems: shareItems,
                onComplete: { completed, activityType in
                    if completed {
                        analytics.track("share_completed", properties: [
                            "surface": "post_run_celebration",
                            "activity_type": activityType ?? "unknown"
                        ])
                    } else {
                        analytics.track("share_cancelled", properties: [
                            "surface": "post_run_celebration",
                            "activity_type": activityType ?? "none"
                        ])
                    }
                }
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

    private func launchLookAroundPortal(to target: LookAroundTarget) {
        guard lookAroundTarget == nil else { return }

        portalPulse = false
        withAnimation(.easeIn(duration: 0.12)) {
            showPortalEffect = true
        }

        Task {
            // Brief blackout beat before the warp opens
            try? await Task.sleep(for: .milliseconds(130))
            withAnimation(.easeOut(duration: 0.38)) {
                portalPulse = true
            }

            try? await Task.sleep(for: .milliseconds(340))
            lookAroundTarget = target

            withAnimation(.easeOut(duration: 0.20)) {
                showPortalEffect = false
            }
            portalPulse = false
        }
    }

    private func showCelebration(milesAdvanced: Double, locationName: String) {
        celebrationDismissTask?.cancel()
        postRunCelebration = PostRunCelebration(
            milesAdvanced: milesAdvanced,
            locationName: locationName
        )
        analytics.track("post_run_celebration_shown", properties: [
            "route_id": route?.id ?? "unknown",
            "location_name": locationName,
            "miles_advanced": milesAdvanced.formatted(.number.precision(.fractionLength(2)))
        ])
        celebrationDismissTask = Task {
            try? await Task.sleep(for: .seconds(9))
            if !Task.isCancelled {
                await MainActor.run {
                    dismissCelebration()
                }
            }
        }
    }

    private func dismissCelebration() {
        celebrationDismissTask?.cancel()
        celebrationDismissTask = nil
        postRunCelebration = nil
    }

    @MainActor
    private func shareCelebration(_ celebration: PostRunCelebration, route: RunRoute) {
        analytics.track("share_tap", properties: [
            "surface": "post_run_celebration",
            "route_id": route.id,
            "location_name": celebration.locationName
        ])
        guard let image = PostRunShareCardRenderer.makeStoryImage(
            route: route,
            locationName: celebration.locationName,
            milesAdvanced: celebration.milesAdvanced,
            totalMilesOnRoute: completedMiles
        ) else {
            analytics.track("share_prepare_failed", properties: [
                "surface": "post_run_celebration",
                "route_id": route.id
            ])
            return
        }

        let caption = shareCaption(
            route: route,
            locationName: celebration.locationName,
            milesAdvanced: celebration.milesAdvanced
        )
        shareItems = [caption, image]
        analytics.track("share_sheet_opened", properties: [
            "surface": "post_run_celebration",
            "route_id": route.id
        ])
        showingShareSheet = true
    }

    private func shareCaption(route: RunRoute, locationName: String, milesAdvanced: Double) -> String {
        let unit = DistanceUnit(rawValue: distanceUnitRawValue) ?? .miles
        let distanceText = unit.convert(miles: milesAdvanced).formatted(.number.precision(.fractionLength(1)))
        let unitLabel = unit.abbreviation
        let presets = [
            "Ran in my neighborhood, landed in \(locationName).",
            "Cardio passport stamped: \(locationName).",
            "Moved \(distanceText) \(unitLabel) on \(route.name)."
        ]
        return presets.randomElement() ?? presets[0]
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

// MARK: - Top Branded Header

private struct MapRouteHeader: View {
    let routeName: String

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 0)

            HStack {
                Text(routeName.uppercased())
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.8))
                    .tracking(1.0)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.5), .black.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }
}

private struct LookAroundPortalEffectView: View {
    let isPulsing: Bool

    var body: some View {
        ZStack {
            // Dark "void" moment before entering the portal.
            Color.black.opacity(isPulsing ? 0.38 : 0.92)
                .ignoresSafeArea()

            PortalTunnelRingsView(isPulsing: isPulsing)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            StrideByTheme.accent.opacity(0.9),
                            .blue.opacity(0.75),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 220
                    )
                )
                .frame(width: isPulsing ? 520 : 120, height: isPulsing ? 520 : 120)
                .blur(radius: isPulsing ? 0 : 6)

            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Entering Look Around")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .opacity(isPulsing ? 1 : 0.65)
            .scaleEffect(isPulsing ? 1.0 : 0.85)
        }
    }
}

private struct PortalTunnelRingsView: View {
    let isPulsing: Bool

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .strokeBorder(.white.opacity(0.13 - (Double(index) * 0.02)), lineWidth: 2)
                    .frame(
                        width: (isPulsing ? 560 : 180) + (CGFloat(index) * 90),
                        height: (isPulsing ? 560 : 180) + (CGFloat(index) * 90)
                    )
                    .blur(radius: isPulsing ? 0 : 2)
            }
        }
        .animation(.easeOut(duration: 0.42), value: isPulsing)
    }
}

#Preview {
    MapScreen()
        .environment(StravaAuthService())
        .environment(RunProgressManager())
        .environment(RouteManager())
        .environment(RouteGeometryManager())
        .environment(AnalyticsService())
}
