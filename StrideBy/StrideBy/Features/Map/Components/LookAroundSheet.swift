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
/// 5. If nothing found, honestly show "No coverage" — never jump to a distant city
@MainActor
struct LookAroundSheet: View {
    @Environment(\.dismiss) private var dismiss

    let locationName: String
    let coordinate: CLLocationCoordinate2D
    let seedCoordinates: [CLLocationCoordinate2D]
    let searchQueries: [String]

    @State private var scene: MKLookAroundScene?
    @State private var isLoading = true
    @State private var resolvedCoordinate: CLLocationCoordinate2D?
    @State private var showInteractionHint = true
    @State private var hintPulse = false
    @State private var hintCanDismiss = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if isLoading {
                    loadingView
                } else if let scene {
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
                } else {
                    noCoverageView
                }
            }
        .task {
            await loadScene()
        }

            closeButton

            VStack {
                Text(locationName)
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 18)

                if isUsingNearbyFallback {
                    Text("Showing nearest available street view nearby.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
                Spacer()
            }
            .padding(.leading, 86)
            .allowsHitTesting(false)

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

    private var noCoverageView: some View {
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

    // MARK: - Data Loading

    private func loadScene() async {
        isLoading = true
        resolvedCoordinate = nil
        let result = await findBestScene(near: coordinate)
        scene = result.scene
        resolvedCoordinate = result.coordinate
        isLoading = false
    }

    private var isUsingNearbyFallback: Bool {
        guard let resolvedCoordinate else { return false }
        return distanceMeters(from: coordinate, to: resolvedCoordinate) > 5
    }

    // MARK: - Search Strategy

    /// Searches for Look Around coverage using a minimal number of requests.
    ///
    /// Apple's MapKit enforces a strict 50 requests/60 seconds limit across ALL request
    /// types (scene requests, POI searches, reverse geocodes). Each MKLookAroundSceneRequest
    /// internally counts as a reverse geocode. So we budget carefully:
    ///
    /// 1. Pin coordinate — 1 request
    /// 2. Up to 3 nearby route points — 3 requests
    /// 3. One POI search + up to 3 scene checks — 4 requests
    /// Total: max 8 requests per tap. Safe for rapid back-to-back usage.
    private func findBestScene(near source: CLLocationCoordinate2D)
        async -> (scene: MKLookAroundScene?, coordinate: CLLocationCoordinate2D?) {

        // 1. Try the exact pin coordinate
        debugLog("Trying exact coordinate...")
        if let scene = await requestSceneSafely(at: source) {
            debugLog("Found at exact coordinate")
            return (scene, source)
        }

        // 2. Try nearby route points (±2-4 miles on the actual road)
        let seeds = uniqueCoordinates(seedCoordinates).prefix(3)
        for seed in seeds {
            debugLog("Trying seed coordinate...")
            if let scene = await requestSceneSafely(at: seed) {
                debugLog("Found at seed coordinate")
                return (scene, seed)
            }
        }

        // 3. Try Apple POIs within 2km — one search, check top 3 results
        debugLog("Trying POI search within 2km...")
        if let poiResult = await findSceneViaNearbyPOIs(near: source) {
            debugLog("Found via nearby POI")
            return poiResult
        }

        debugLog("No coverage found (used max ~8 requests)")
        return (nil, nil)
    }

    // MARK: - Helpers

    /// Searches Apple POIs within 2km, checks the 3 closest for Look Around.
    private func findSceneViaNearbyPOIs(near source: CLLocationCoordinate2D)
        async -> (scene: MKLookAroundScene, coordinate: CLLocationCoordinate2D)? {
        let request = MKLocalPointsOfInterestRequest(
            center: source,
            radius: 2_000
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            let mapItems = response.mapItems
                .sorted {
                    distanceMeters(from: source, to: $0.placemark.coordinate)
                        < distanceMeters(from: source, to: $1.placemark.coordinate)
                }
                .prefix(3)

            for item in mapItems {
                if let scene = await requestSceneSafely(for: item) {
                    return (scene, item.placemark.coordinate)
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    private func requestSceneSafely(at coordinate: CLLocationCoordinate2D) async -> MKLookAroundScene? {
        do {
            let request = MKLookAroundSceneRequest(coordinate: coordinate)
            return try await request.scene
        } catch {
            return nil
        }
    }

    private func requestSceneSafely(for mapItem: MKMapItem) async -> MKLookAroundScene? {
        do {
            let request = MKLookAroundSceneRequest(mapItem: mapItem)
            return try await request.scene
        } catch {
            return nil
        }
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

#Preview("Look Around — NYC") {
    LookAroundSheet(
        locationName: "Times Square, NY",
        coordinate: CLLocationCoordinate2D(latitude: 40.7580, longitude: -73.9855),
        seedCoordinates: [],
        searchQueries: []
    )
}

#Preview("Look Around — Remote") {
    // Middle of the ocean — will show no coverage fallback
    LookAroundSheet(
        locationName: "Atlantic Ocean",
        coordinate: CLLocationCoordinate2D(latitude: 35.0, longitude: -40.0),
        seedCoordinates: [],
        searchQueries: []
    )
}
