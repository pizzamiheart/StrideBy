//
//  LookAroundSheet.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/13/26.
//

import Foundation
import MapKit
import SwiftUI

/// A sheet that displays Apple Look Around street-level imagery for a given coordinate.
///
/// Search strategy (intentionally tight — max ~5km):
/// 1. Try the exact pin coordinate and seed coordinates (nearby route points)
/// 2. Try a small grid of offsets around the pin (300m, 600m)
/// 3. Try Apple POIs within 3km
/// 4. Try a reverse-geocode text search within 5km
/// 5. If nothing found, show a rich satellite card with "Explore Nearest Town" options
@MainActor
struct LookAroundSheet: View {
    @Environment(\.dismiss) private var dismiss

    let locationName: String
    let coordinate: CLLocationCoordinate2D
    let seedCoordinates: [CLLocationCoordinate2D]
    let searchQueries: [String]
    let completedMiles: Double
    let routeName: String
    let route: RunRoute?

    @State private var scene: MKLookAroundScene?
    @State private var isLoading = true
    @State private var resolvedCoordinate: CLLocationCoordinate2D?
    @State private var showInteractionHint = true
    @State private var hintPulse = false
    @State private var hintCanDismiss = false

    // POI jump state (Part 2)
    @State private var jumpedPOI: Landmark?
    @State private var activeCoordinate: CLLocationCoordinate2D?

    /// The coordinate currently being searched — either original or a jumped POI.
    private var searchCoordinate: CLLocationCoordinate2D {
        activeCoordinate ?? coordinate
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if isLoading {
                    loadingView
                } else if let scene {
                    lookAroundView(scene: scene)
                } else if let route {
                    LocationCardView(
                        locationName: locationName,
                        coordinate: coordinate,
                        completedMiles: completedMiles,
                        routeName: routeName,
                        route: route,
                        onExplorePOI: { poi in
                            jumpToPOI(poi)
                        }
                    )
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    legacyNoCoverageView
                }
            }
            .task {
                await loadScene()
            }

            closeButton

            VStack {
                // Location name badge + jumped POI banner
                VStack(spacing: 6) {
                    if scene != nil {
                        Text(locationName)
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }

                    if let jumped = jumpedPOI, scene != nil {
                        jumpedBanner(poi: jumped)
                    } else if isUsingNearbyFallback, scene != nil {
                        Text("Showing nearest available street view nearby.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 18)

                Spacer()
            }
            .padding(.leading, 86)
            .allowsHitTesting(jumpedPOI != nil) // allow hit testing only for "back" button

            if showInteractionHint, scene != nil {
                interactionHint
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            showInteractionHint = true
            hintCanDismiss = false
            hintPulse = false
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                hintPulse = true
            }

            Task {
                try? await Task.sleep(for: .milliseconds(900))
                hintCanDismiss = true
            }
        }
    }

    // MARK: - Look Around View

    private func lookAroundView(scene: MKLookAroundScene) -> some View {
        LookAroundPreview(initialScene: scene, allowsNavigation: true)
            .ignoresSafeArea()
            .onTapGesture {
                hideInteractionHint()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in
                        hideInteractionHint()
                    }
            )
    }

    // MARK: - Jumped POI Banner

    private func jumpedBanner(poi: Landmark) -> some View {
        let milesAway = abs(Int(poi.distanceFromStartMiles - completedMiles))
        return HStack(spacing: 6) {
            Text("Showing \(poi.name), \(poi.state)")
                .font(.caption)
                .fontWeight(.medium)
            Text("(\(milesAway) mi from your position)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                returnToOriginal()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading street view…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Legacy fallback when no route data is available (e.g. from old call sites).
    private var legacyNoCoverageView: some View {
        VStack(spacing: 16) {
            Image(systemName: "binoculars")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No street view here")
                .font(.headline)
            Text("Street-level imagery is available in cities and along major highways. Keep running — you'll hit coverage soon!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - POI Jump (Part 2)

    private func jumpToPOI(_ poi: Landmark) {
        jumpedPOI = poi
        activeCoordinate = poi.coordinate
        scene = nil
        Task {
            await loadScene()
        }
    }

    private func returnToOriginal() {
        jumpedPOI = nil
        activeCoordinate = nil
        scene = nil
        Task {
            await loadScene()
        }
    }

    // MARK: - Data Loading

    private func loadScene() async {
        isLoading = true
        resolvedCoordinate = nil
        let result = await findBestScene(near: searchCoordinate)
        scene = result.scene
        resolvedCoordinate = result.coordinate
        isLoading = false
    }

    private var isUsingNearbyFallback: Bool {
        guard let resolvedCoordinate else { return false }
        return distanceMeters(from: searchCoordinate, to: resolvedCoordinate) > 5
    }

    // MARK: - Search Strategy

    /// Searches for Look Around coverage using a minimal number of requests.
    ///
    /// Apple's MapKit enforces a strict 50 requests/60 seconds limit across ALL request
    /// types (scene requests, POI searches, reverse geocodes). So we budget carefully:
    ///
    /// 1. Pin coordinate — 1 request
    /// 2. Filtered POI search (restaurants, gas stations, etc.) — 1 search + up to 5 scene checks
    /// 3. Text search for "restaurant" — 1 search + up to 3 scene checks
    /// 4. Up to 2 nearby route seed points — 2 requests
    /// Total: max 14 requests per tap. Safe for normal usage (50/min limit).
    private func findBestScene(near source: CLLocationCoordinate2D)
        async -> (scene: MKLookAroundScene?, coordinate: CLLocationCoordinate2D?) {

        // 1. Try the exact pin coordinate
        debugLog("Trying exact coordinate (\(fmt(source)))...")
        if let scene = await requestSceneSafely(at: source) {
            debugLog("Found at exact coordinate")
            return (scene, source)
        }

        // 2. Try Apple POIs within 5km — MKMapItem-based requests are more
        //    reliable than raw coordinates (especially in the simulator)
        debugLog("Trying POI search within 5km...")
        if let poiResult = await findSceneViaNearbyPOIs(near: source) {
            debugLog("Found via nearby POI")
            return poiResult
        }

        // 3. Try nearby route seed points (±2-4 miles on the actual road)
        //    Skip seeds when we've jumped to a POI — they're from the original location
        if jumpedPOI == nil {
            let seeds = uniqueCoordinates(seedCoordinates).prefix(2)
            for seed in seeds {
                debugLog("Trying seed (\(fmt(seed)))...")
                if let scene = await requestSceneSafely(at: seed) {
                    debugLog("Found at seed coordinate")
                    return (scene, seed)
                }
            }
        }

        debugLog("No coverage found (used max ~14 requests)")
        return (nil, nil)
    }

    // MARK: - Helpers

    /// Searches consumer-facing Apple POIs within 5km (restaurants, gas stations, etc.),
    /// then falls back to a text search for "restaurant" if needed.
    /// These are far more likely to be on public roads with Look Around coverage
    /// than industrial/commercial POIs like "Rinaldi Excavating".
    private func findSceneViaNearbyPOIs(near source: CLLocationCoordinate2D)
        async -> (scene: MKLookAroundScene, coordinate: CLLocationCoordinate2D)? {

        // Phase A: Filtered POI search — only consumer-facing categories on public roads
        let request = MKLocalPointsOfInterestRequest(
            center: source,
            radius: 5_000
        )
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .gasStation, .hotel, .parking,
            .store, .pharmacy, .bank, .postOffice, .foodMarket
        ])

        do {
            let response = try await MKLocalSearch(request: request).start()
            let mapItems = response.mapItems
                .sorted {
                    distanceMeters(from: source, to: $0.placemark.coordinate)
                        < distanceMeters(from: source, to: $1.placemark.coordinate)
                }
                .prefix(5)

            debugLog("  POI search: \(response.mapItems.count) consumer POIs, checking top \(min(response.mapItems.count, 5))...")
            for item in mapItems {
                let name = item.name ?? "unknown"
                if let scene = await requestSceneSafely(for: item) {
                    debugLog("  → Hit: \(name)")
                    return (scene, item.placemark.coordinate)
                } else {
                    debugLog("  → Miss: \(name)")
                }
            }
        } catch {
            debugLog("  POI search error: \(error.localizedDescription)")
        }

        // Phase B: Text search for "restaurant" — catches towns the POI filter might miss
        debugLog("  Trying text search for 'restaurant' within 5km...")
        let textRequest = MKLocalSearch.Request()
        textRequest.naturalLanguageQuery = "restaurant"
        textRequest.region = MKCoordinateRegion(
            center: source,
            latitudinalMeters: 10_000,
            longitudinalMeters: 10_000
        )

        do {
            let response = try await MKLocalSearch(request: textRequest).start()
            let nearby = response.mapItems
                .filter { distanceMeters(from: source, to: $0.placemark.coordinate) <= 5_000 }
                .sorted {
                    distanceMeters(from: source, to: $0.placemark.coordinate)
                        < distanceMeters(from: source, to: $1.placemark.coordinate)
                }
                .prefix(3)

            debugLog("  Text search: \(response.mapItems.count) results, \(nearby.count) within 5km...")
            for item in nearby {
                let name = item.name ?? "unknown"
                if let scene = await requestSceneSafely(for: item) {
                    debugLog("  → Hit: \(name)")
                    return (scene, item.placemark.coordinate)
                } else {
                    debugLog("  → Miss: \(name)")
                }
            }
        } catch {
            debugLog("  Text search error: \(error.localizedDescription)")
        }

        return nil
    }

    private func requestSceneSafely(at coordinate: CLLocationCoordinate2D) async -> MKLookAroundScene? {
        do {
            let request = MKLookAroundSceneRequest(coordinate: coordinate)
            let scene = try await request.scene
            if scene == nil {
                debugLog("  → nil at (\(fmt(coordinate)))")
            }
            return scene
        } catch {
            debugLog("  → error at (\(fmt(coordinate))): \(error.localizedDescription)")
            return nil
        }
    }

    private func requestSceneSafely(for mapItem: MKMapItem) async -> MKLookAroundScene? {
        do {
            let request = MKLookAroundSceneRequest(mapItem: mapItem)
            let scene = try await request.scene
            return scene
        } catch {
            return nil
        }
    }

    private func fmt(_ c: CLLocationCoordinate2D) -> String {
        "\(String(format: "%.4f", c.latitude)), \(String(format: "%.4f", c.longitude))"
    }

    private func uniqueCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        var seen = Set<String>()
        var result: [CLLocationCoordinate2D] = []

        for coordinate in coordinates {
            let key = "\(String(format: "%.4f", coordinate.latitude)),\(String(format: "%.4f", coordinate.longitude))"
            if seen.insert(key).inserted {
                result.append(coordinate)
            }
        }
        return result
    }

    private func distanceMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }

    // MARK: - UI Components

    private var closeButton: some View {
        Button("Close") {
            dismiss()
        }
        .buttonStyle(.borderedProminent)
        .tint(.black.opacity(0.65))
        .padding(.top, 18)
        .padding(.leading, 16)
    }

    private var interactionHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.title2)
            Text("Tap or drag to look around")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.5), in: Capsule())
        .scaleEffect(hintPulse ? 1.05 : 0.95)
        .opacity(hintPulse ? 1.0 : 0.7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func hideInteractionHint() {
        guard showInteractionHint, hintCanDismiss else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            showInteractionHint = false
        }
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("LookAroundSheet[\(locationName)]: \(message)")
        #endif
    }
}

private extension CLLocation {
    /// Computes destination coordinate from distance+bearing on a spherical Earth.
    func coordinateByMoving(distanceMeters: CLLocationDistance,
                            bearingDegrees: CLLocationDirection) -> CLLocationCoordinate2D {
        let earthRadius = 6_371_000.0
        let bearing = bearingDegrees * .pi / 180

        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180
        let angularDistance = distanceMeters / earthRadius

        let lat2 = asin(
            sin(lat1) * cos(angularDistance)
                + cos(lat1) * sin(angularDistance) * cos(bearing)
        )
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
}

#Preview("Look Around — Paris") {
    LookAroundSheet(
        locationName: "Louvre, Paris",
        coordinate: CLLocationCoordinate2D(latitude: 48.8606, longitude: 2.3376),
        seedCoordinates: [],
        searchQueries: [],
        completedMiles: 0,
        routeName: "Paris Arrondissement Tour",
        route: .parisCityLoop
    )
}

#Preview("Look Around — No Coverage") {
    LookAroundSheet(
        locationName: "Near Luxembourg Gardens",
        coordinate: CLLocationCoordinate2D(latitude: 48.8462, longitude: 2.3371),
        seedCoordinates: [],
        searchQueries: [],
        completedMiles: 12,
        routeName: "Paris Arrondissement Tour",
        route: .parisCityLoop
    )
}
