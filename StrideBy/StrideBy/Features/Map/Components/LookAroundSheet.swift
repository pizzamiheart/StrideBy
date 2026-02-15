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
/// Shows three states:
/// - **Loading:** A spinner while the Look Around scene is fetched.
/// - **Success:** An interactive `LookAroundPreview` the user can pan around.
/// - **No coverage:** A friendly fallback when Apple doesn't have imagery at that location.
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
            Image(systemName: "eye.slash")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No Look Around coverage here")
                .font(.headline)
            Text("Apple doesn't have street-level imagery at this location yet.")
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

    /// Tries the tapped coordinate first, then nearby fallback points.
    private func findBestScene(near source: CLLocationCoordinate2D)
        async -> (scene: MKLookAroundScene?, coordinate: CLLocationCoordinate2D?) {
        if let poiResult = await findSceneViaNearbyPOIs(near: source) {
            debugLog("Resolved via nearby POI strategy")
            return poiResult
        }

        if let queryResult = await findSceneViaSearchQueries(near: source) {
            debugLog("Resolved via search query strategy")
            return queryResult
        }

        let seeds = uniqueCoordinates([source] + seedCoordinates)
        let candidates = seeds.flatMap { nearbyCandidates(around: $0) }

        for candidate in candidates {
            if let scene = await requestSceneSafely(at: candidate) {
                debugLog("Resolved via coordinate candidate")
                return (scene, candidate)
            }
        }

        if let searchFallback = await findSceneViaLocalSearch(near: source) {
            debugLog("Resolved via local search fallback")
            return searchFallback
        }

        debugLog("No coverage found after all fallback strategies")
        return (nil, nil)
    }

    private func findSceneViaSearchQueries(near source: CLLocationCoordinate2D)
        async -> (scene: MKLookAroundScene, coordinate: CLLocationCoordinate2D)? {
        let extraQueries = await reverseGeocodeQueryCandidates(near: source)
        let queries = uniqueStrings(searchQueries + [locationName] + extraQueries)
        let radiiMeters: [CLLocationDistance] = [3_000, 8_000, 20_000, 45_000]

        for radius in radiiMeters {
            for query in queries {
                if let result = await findSceneViaLocalSearch(
                    near: source,
                    radiusMeters: radius,
                    query: query,
                    maxItems: 8
                ) {
                    debugLog("Resolved map item query '\(query)'")
                    return result
                }
            }
        }

        return nil
    }

    private func findSceneViaNearbyPOIs(near source: CLLocationCoordinate2D)
        async -> (scene: MKLookAroundScene, coordinate: CLLocationCoordinate2D)? {
        let radiiMeters: [CLLocationDistance] = [1_500, 5_000, 12_000, 25_000]

        for radius in radiiMeters {
            if let result = await findSceneViaNearbyPOIs(
                near: source,
                radiusMeters: radius,
                maxItems: 25
            ) {
                return result
            }
        }
        return nil
    }

    private func findSceneViaNearbyPOIs(near source: CLLocationCoordinate2D,
                                        radiusMeters: CLLocationDistance,
                                        maxItems: Int)
        async -> (scene: MKLookAroundScene, coordinate: CLLocationCoordinate2D)? {
        let request = MKLocalPointsOfInterestRequest(
            center: source,
            radius: radiusMeters
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            let mapItems = response.mapItems
                .sorted {
                    distanceMeters(from: source, to: $0.placemark.coordinate)
                        < distanceMeters(from: source, to: $1.placemark.coordinate)
                }
                .prefix(maxItems)

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

    private func nearbyCandidates(around source: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        let radiiMeters: [CLLocationDistance] = [0, 180, 450, 900]
        let bearings: [CLLocationDirection] = [0, 45, 90, 135, 180, 225, 270, 315]

        var candidates: [CLLocationCoordinate2D] = [source]
        let origin = CLLocation(latitude: source.latitude, longitude: source.longitude)

        for radius in radiiMeters where radius > 0 {
            for bearing in bearings {
                let destination = origin.coordinateByMoving(distanceMeters: radius, bearingDegrees: bearing)
                candidates.append(destination)
            }
        }

        return candidates
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

    private func findSceneViaLocalSearch(near source: CLLocationCoordinate2D)
        async -> (scene: MKLookAroundScene, coordinate: CLLocationCoordinate2D)? {
        let reverseGeocodeQueries = await reverseGeocodeQueryCandidates(near: source)
        let queries = [locationName]
            + reverseGeocodeQueries
            + [
                "landmark near \(locationName)",
                "historic site near \(locationName)",
                "museum near \(locationName)",
                "downtown \(locationName)",
                "city center \(locationName)",
                "park near \(locationName)",
            ]
        let radiiMeters: [CLLocationDistance] = [8_000, 20_000, 45_000, 80_000, 140_000]

        for radius in radiiMeters {
            for query in queries {
                if let result = await findSceneViaLocalSearch(near: source, radiusMeters: radius, query: query) {
                    return result
                }
            }
        }
        return nil
    }

    private func reverseGeocodeQueryCandidates(near source: CLLocationCoordinate2D) async -> [String] {
        let location = CLLocation(latitude: source.latitude, longitude: source.longitude)
        let geocoder = CLGeocoder()

        do {
            guard let placemark = try await geocoder.reverseGeocodeLocation(location).first else {
                return []
            }

            var queries: [String] = []

            if let thoroughfare = placemark.thoroughfare, !thoroughfare.isEmpty {
                if let locality = placemark.locality, !locality.isEmpty {
                    queries.append("\(thoroughfare), \(locality)")
                }
                queries.append(thoroughfare)
            }

            if let locality = placemark.locality, !locality.isEmpty {
                if let admin = placemark.administrativeArea, !admin.isEmpty {
                    queries.append("\(locality), \(admin)")
                } else {
                    queries.append(locality)
                }
            }

            if let country = placemark.country, !country.isEmpty {
                queries.append(country)
            }

            return Array(Set(queries))
        } catch {
            return []
        }
    }

    private func findSceneViaLocalSearch(near source: CLLocationCoordinate2D,
                                         radiusMeters: CLLocationDistance,
                                         query: String,
                                         maxItems: Int = 10)
        async -> (scene: MKLookAroundScene, coordinate: CLLocationCoordinate2D)? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: source,
            latitudinalMeters: radiusMeters,
            longitudinalMeters: radiusMeters
        )
        request.resultTypes = [.pointOfInterest, .address]

        do {
            let response = try await MKLocalSearch(request: request).start()
            let candidates = response.mapItems
                .sorted {
                    distanceMeters(from: source, to: $0.placemark.coordinate)
                        < distanceMeters(from: source, to: $1.placemark.coordinate)
                }
                .prefix(maxItems)
            for item in candidates {
                if let scene = await requestSceneSafely(for: item) {
                    return (scene, item.placemark.coordinate)
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in values {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            let key = value.lowercased()
            if seen.insert(key).inserted {
                result.append(value)
            }
        }
        return result
    }

    private func distanceMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }

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
