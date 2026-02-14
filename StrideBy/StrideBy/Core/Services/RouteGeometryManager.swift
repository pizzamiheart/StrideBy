//
//  RouteGeometryManager.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/14/26.
//

import CoreLocation
import Foundation
import MapKit
import Observation

/// Builds and caches road-snapped route geometry for smoother progress movement and
/// better Look Around targeting. Falls back to original route coordinates when needed.
@Observable
final class RouteGeometryManager {
    private(set) var revision: Int = 0
    private var snappedCoordinatesByRoute: [String: [CLLocationCoordinate2D]] = [:]
    private var loadingRouteKeys: Set<String> = []

    private let cacheURL: URL

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheURL = caches.appendingPathComponent("strideby_route_geometry_cache.json")
        loadCache()
    }

    func coordinates(for route: RunRoute) -> [CLLocationCoordinate2D] {
        snappedCoordinatesByRoute[route.id] ?? route.coordinates
    }

    func warmGeometry(for route: RunRoute) async {
        if snappedCoordinatesByRoute[route.id] != nil || loadingRouteKeys.contains(route.id) {
            return
        }

        loadingRouteKeys.insert(route.id)
        defer { loadingRouteKeys.remove(route.id) }

        guard let snapped = await buildSnappedCoordinates(for: route) else { return }
        guard snapped.count > route.coordinates.count else { return }

        snappedCoordinatesByRoute[route.id] = snapped
        revision += 1
        saveCache()
    }

    private func buildSnappedCoordinates(for route: RunRoute) async -> [CLLocationCoordinate2D]? {
        guard route.coordinates.count >= 2 else { return nil }

        var built: [CLLocationCoordinate2D] = []
        for index in 0..<(route.coordinates.count - 1) {
            let start = route.coordinates[index]
            let end = route.coordinates[index + 1]

            let segment = await snappedSegment(from: start, to: end)
                ?? interpolatedSegment(from: start, to: end, steps: 8)

            appendDeduped(segment, into: &built)
        }

        return built.isEmpty ? nil : built
    }

    private func snappedSegment(from start: CLLocationCoordinate2D,
                                to end: CLLocationCoordinate2D) async -> [CLLocationCoordinate2D]? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else { return nil }
            return route.polyline.coordinates
        } catch {
            return nil
        }
    }

    private func interpolatedSegment(from start: CLLocationCoordinate2D,
                                     to end: CLLocationCoordinate2D,
                                     steps: Int) -> [CLLocationCoordinate2D] {
        guard steps > 1 else { return [start, end] }

        var result: [CLLocationCoordinate2D] = []
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let lat = start.latitude + (end.latitude - start.latitude) * t
            let lon = start.longitude + (end.longitude - start.longitude) * t
            result.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        return result
    }

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

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        guard let decoded = try? JSONDecoder().decode([String: [CoordinateDTO]].self, from: data) else { return }

        snappedCoordinatesByRoute = decoded.mapValues { list in
            list.map { $0.coordinate }
        }
    }

    private func saveCache() {
        let encoded = snappedCoordinatesByRoute.mapValues { list in
            list.map { CoordinateDTO(coordinate: $0) }
        }

        guard let data = try? JSONEncoder().encode(encoded) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}

private struct CoordinateDTO: Codable {
    let latitude: Double
    let longitude: Double

    init(coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        let count = pointCount
        var points = [CLLocationCoordinate2D](repeating: .init(), count: count)
        getCoordinates(&points, range: NSRange(location: 0, length: count))
        return points
    }
}
