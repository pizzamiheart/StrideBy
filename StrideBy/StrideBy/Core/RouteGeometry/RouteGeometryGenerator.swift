//
//  RouteGeometryGenerator.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/14/26.
//

#if DEBUG

import CoreLocation
import Foundation
import MapKit
import Observation

// MARK: - Generator State

enum GeneratorState: Equatable {
    case idle
    case generating(routeId: String, segment: Int, totalSegments: Int)
    case retrying(routeId: String, segment: Int, attempt: Int)
    case finished(routeId: String, coordinateCount: Int)
    case failed(routeId: String, message: String)

    var isRunning: Bool {
        switch self {
        case .generating, .retrying: return true
        default: return false
        }
    }
}

// MARK: - Generator

/// DEBUG-only tool that calls MKDirections between each pair of consecutive waypoints
/// in a route, stitches the polylines together, and writes the result as a bundled JSON file.
///
/// Usage: Run in the simulator, tap "Gen Routes", wait for completion, then rebuild.
/// The JSON files land in Core/RouteGeometry/ and are auto-bundled on next build.
@Observable
final class RouteGeometryGenerator {
    private(set) var state: GeneratorState = .idle
    private(set) var log: [String] = []

    /// How long to wait between MKDirections requests (seconds).
    private let interRequestDelay: TimeInterval = 2.5
    /// Max retries per segment before giving up.
    private let maxRetries = 3
    /// Backoff delay on retry (seconds).
    private let retryDelay: TimeInterval = 10.0

    // MARK: - Generate All

    func generateAll() async {
        for route in RunRoute.allRoutes {
            await generateSingle(route)
            if case .failed = state { return }
        }
        appendLog("All routes generated successfully.")
    }

    // MARK: - Generate Single Route

    func generateSingle(_ route: RunRoute) async {
        let waypoints = route.coordinates
        guard waypoints.count >= 2 else {
            state = .failed(routeId: route.id, message: "Route has fewer than 2 waypoints")
            return
        }

        let totalSegments = waypoints.count - 1
        appendLog("Starting \(route.id): \(totalSegments) segments")

        var allCoordinates: [CLLocationCoordinate2D] = []

        for index in 0..<totalSegments {
            let start = waypoints[index]
            let end = waypoints[index + 1]

            state = .generating(routeId: route.id, segment: index + 1, totalSegments: totalSegments)
            appendLog("  Segment \(index + 1)/\(totalSegments): requesting directions...")

            var segmentCoords: [CLLocationCoordinate2D]?
            var lastError: String = ""

            for attempt in 1...maxRetries {
                if attempt > 1 {
                    state = .retrying(routeId: route.id, segment: index + 1, attempt: attempt)
                    appendLog("    Retry \(attempt)/\(maxRetries) after \(Int(retryDelay))s...")
                    try? await Task.sleep(for: .seconds(retryDelay))
                }

                do {
                    segmentCoords = try await fetchDirections(from: start, to: end)
                    break
                } catch {
                    lastError = error.localizedDescription
                    appendLog("    Failed: \(lastError)")
                }
            }

            guard let coords = segmentCoords else {
                state = .failed(routeId: route.id, message: "Segment \(index + 1) failed after \(maxRetries) retries: \(lastError)")
                appendLog("  FAILED on segment \(index + 1). Aborting route.")
                return
            }

            appendLog("    Got \(coords.count) points")
            appendDeduped(coords, into: &allCoordinates)

            // Delay between requests to avoid rate limits (skip after last segment)
            if index < totalSegments - 1 {
                try? await Task.sleep(for: .seconds(interRequestDelay))
            }
        }

        appendLog("  Total coordinates for \(route.id): \(allCoordinates.count)")

        // Write JSON to the project directory
        do {
            try writeJSON(routeId: route.id, coordinates: allCoordinates)
            state = .finished(routeId: route.id, coordinateCount: allCoordinates.count)
            appendLog("  Wrote \(route.id).geometry.json (\(allCoordinates.count) coords)")
        } catch {
            state = .failed(routeId: route.id, message: "Write failed: \(error.localizedDescription)")
            appendLog("  FAILED to write JSON: \(error.localizedDescription)")
        }
    }

    // MARK: - MKDirections

    private func fetchDirections(from start: CLLocationCoordinate2D,
                                 to end: CLLocationCoordinate2D) async throws -> [CLLocationCoordinate2D] {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else {
            throw GeneratorError.noRoute
        }
        return route.polyline.allCoordinates
    }

    // MARK: - Deduplication

    private func appendDeduped(_ coordinates: [CLLocationCoordinate2D],
                               into result: inout [CLLocationCoordinate2D]) {
        for coordinate in coordinates {
            guard let last = result.last else {
                result.append(coordinate)
                continue
            }
            let isSame = abs(last.latitude - coordinate.latitude) < 0.000001
                && abs(last.longitude - coordinate.longitude) < 0.000001
            if !isSame {
                result.append(coordinate)
            }
        }
    }

    // MARK: - JSON Output

    private func writeJSON(routeId: String, coordinates: [CLLocationCoordinate2D]) throws {
        let dto = BundledRouteGeometry(
            routeId: routeId,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            coordinates: coordinates.map { BundledCoordinateDTO(lat: $0.latitude, lng: $0.longitude) }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(dto)

        // Use #filePath to find the project source directory at compile time.
        // This file lives at: .../StrideBy/Core/RouteGeometry/RouteGeometryGenerator.swift
        // JSON goes to:       .../StrideBy/Core/RouteGeometry/<routeId>.geometry.json
        let thisFile = URL(fileURLWithPath: #filePath)
        let geometryDir = thisFile.deletingLastPathComponent()
        let outputURL = geometryDir.appendingPathComponent("\(routeId).geometry.json")

        try data.write(to: outputURL, options: .atomic)
        appendLog("    Written to: \(outputURL.path)")
    }

    // MARK: - Logging

    private func appendLog(_ message: String) {
        log.append("[\(timeStamp)] \(message)")
    }

    private var timeStamp: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}

// MARK: - Error

private enum GeneratorError: LocalizedError {
    case noRoute

    var errorDescription: String? {
        switch self {
        case .noRoute: return "MKDirections returned no routes"
        }
    }
}

// MARK: - MKPolyline Extension

private extension MKPolyline {
    var allCoordinates: [CLLocationCoordinate2D] {
        let count = pointCount
        var coords = [CLLocationCoordinate2D](repeating: .init(), count: count)
        getCoordinates(&coords, range: NSRange(location: 0, length: count))
        return coords
    }
}

#endif
