//
//  MapScreen.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import MapKit
import SwiftUI
#if canImport(Lottie)
import Lottie
import UIKit
#endif

/// An identifiable target for the Look Around sheet.
private struct LookAroundTarget: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let seedCoordinates: [CLLocationCoordinate2D]
    let searchQueries: [String]
    let completedMiles: Double
    let routeName: String
    let route: RunRoute?
}

struct MapScreen: View {
    @Environment(StravaAuthService.self) private var stravaAuth
    @Environment(RunProgressManager.self) private var progressManager
    @Environment(RouteManager.self) private var routeManager
    @Environment(RouteGeometryManager.self) private var routeGeometryManager

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var lookAroundTarget: LookAroundTarget?
    @State private var showPortalEffect = false
    @State private var portalPulse = false
    #if DEBUG
    @State private var showingRouteGenerator = false
    @State private var showingCoverageAudit = false
    #endif

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
            }
        }
        .overlay(alignment: .topTrailing) {
            #if DEBUG
            DebugMilesOverlay(progressManager: progressManager, routeManager: routeManager, showingRouteGenerator: $showingRouteGenerator, showingCoverageAudit: $showingCoverageAudit)
            #endif
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
                routeName: target.routeName,
                route: target.route
            )
        }
        #if DEBUG
        .sheet(isPresented: $showingRouteGenerator) {
            RouteGeneratorSheet()
        }
        .sheet(isPresented: $showingCoverageAudit) {
            CoverageAuditSheet()
        }
        #endif
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
    let routeManager: RouteManager
    @Binding var showingRouteGenerator: Bool
    @Binding var showingCoverageAudit: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text("DEBUG")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 4) {
                Button("+1") {
                    progressManager.addDebugMiles(1)
                }
                Button("+5") {
                    progressManager.addDebugMiles(5)
                }
                Button("+20") {
                    progressManager.addDebugMiles(20)
                }
            }

            HStack(spacing: 4) {
                Button("+50") {
                    progressManager.addDebugMiles(50)
                }
                Button("+200") {
                    progressManager.addDebugMiles(200)
                }
            }

            Button("Reset Route") {
                routeManager.resetDebugRouteProgress(currentTotalMiles: progressManager.totalMiles)
            }

            Divider()
                .frame(width: 40)
                .background(.white.opacity(0.3))

            Button("Gen Routes") {
                showingRouteGenerator = true
            }

            Button("Coverage") {
                showingCoverageAudit = true
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

private struct LookAroundPortalEffectView: View {
    let isPulsing: Bool

    var body: some View {
        ZStack {
            // Dark "void" moment before entering the portal.
            Color.black.opacity(isPulsing ? 0.38 : 0.92)
                .ignoresSafeArea()

            PortalTunnelRingsView(isPulsing: isPulsing)

            #if canImport(Lottie)
            LottiePortalWarpLayer(isPulsing: isPulsing)
            #else
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
            #endif

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

#if canImport(Lottie)
private struct LottiePortalWarpLayer: View {
    let isPulsing: Bool
    private let hasAnimation = LottieAnimation.named("portal_warp") != nil

    var body: some View {
        Group {
            if hasAnimation {
                LottiePortalAnimationView(animationName: "portal_warp", play: isPulsing)
                    .opacity(isPulsing ? 1.0 : 0.4)
                    .scaleEffect(isPulsing ? 1.45 : 0.85)
                    .blendMode(.screen)
            } else {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.35),
                                .blue.opacity(0.45),
                                .black.opacity(0.9),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 12,
                            endRadius: 260
                        )
                    )
                    .frame(width: isPulsing ? 620 : 160, height: isPulsing ? 620 : 160)
            }
        }
        .blur(radius: isPulsing ? 0 : 2)
        .animation(.easeOut(duration: 0.42), value: isPulsing)
    }
}

private struct LottiePortalAnimationView: UIViewRepresentable {
    let animationName: String
    let play: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .clear

        let animationView = LottieAnimationView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFill
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.loopMode = .playOnce
        animationView.animation = LottieAnimation.named(animationName)

        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.animationView = animationView
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let animationView = context.coordinator.animationView else { return }

        if play, context.coordinator.lastPlayState == false {
            animationView.currentProgress = 0
            animationView.play()
        }

        context.coordinator.lastPlayState = play
    }

    final class Coordinator {
        var animationView: LottieAnimationView?
        var lastPlayState = false
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
