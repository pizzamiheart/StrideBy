//
//  RunRoute.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import Foundation
import CoreLocation

// MARK: - Models

struct RunRoute: Identifiable {
    let id: UUID
    let name: String
    let origin: String
    let destination: String
    let coordinates: [CLLocationCoordinate2D]
    let totalDistanceMiles: Double
    let landmarks: [Landmark]
}

struct Landmark: Identifiable {
    let id: UUID
    let name: String
    let state: String
    let coordinate: CLLocationCoordinate2D
    let distanceFromStartMiles: Double
}

// MARK: - Route Geometry Helpers

extension RunRoute {

    /// Returns the interpolated coordinate at a given distance along the route.
    func coordinateAt(miles: Double) -> CLLocationCoordinate2D {
        let targetMeters = miles * 1609.34
        var accumulated: Double = 0

        for i in 0..<coordinates.count - 1 {
            let from = CLLocation(latitude: coordinates[i].latitude,
                                  longitude: coordinates[i].longitude)
            let to = CLLocation(latitude: coordinates[i + 1].latitude,
                                longitude: coordinates[i + 1].longitude)
            let segmentLength = to.distance(from: from)

            if accumulated + segmentLength >= targetMeters {
                let fraction = (targetMeters - accumulated) / segmentLength
                let lat = coordinates[i].latitude
                    + (coordinates[i + 1].latitude - coordinates[i].latitude) * fraction
                let lon = coordinates[i].longitude
                    + (coordinates[i + 1].longitude - coordinates[i].longitude) * fraction
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            accumulated += segmentLength
        }
        return coordinates.last ?? CLLocationCoordinate2D()
    }

    /// The coordinates for the portion of the route already completed.
    func completedCoordinates(miles: Double) -> [CLLocationCoordinate2D] {
        splitCoordinates(at: miles).completed
    }

    /// The coordinates for the remaining portion of the route.
    func remainingCoordinates(miles: Double) -> [CLLocationCoordinate2D] {
        splitCoordinates(at: miles).remaining
    }

    private func splitCoordinates(at miles: Double) -> (completed: [CLLocationCoordinate2D],
                                                        remaining: [CLLocationCoordinate2D]) {
        let targetMeters = miles * 1609.34
        var accumulated: Double = 0
        var completed: [CLLocationCoordinate2D] = [coordinates[0]]

        for i in 0..<coordinates.count - 1 {
            let from = CLLocation(latitude: coordinates[i].latitude,
                                  longitude: coordinates[i].longitude)
            let to = CLLocation(latitude: coordinates[i + 1].latitude,
                                longitude: coordinates[i + 1].longitude)
            let segmentLength = to.distance(from: from)

            if accumulated + segmentLength >= targetMeters {
                // Interpolate the split point
                let fraction = (targetMeters - accumulated) / segmentLength
                let lat = coordinates[i].latitude
                    + (coordinates[i + 1].latitude - coordinates[i].latitude) * fraction
                let lon = coordinates[i].longitude
                    + (coordinates[i + 1].longitude - coordinates[i].longitude) * fraction
                let splitPoint = CLLocationCoordinate2D(latitude: lat, longitude: lon)

                completed.append(splitPoint)
                var remaining = [splitPoint]
                remaining.append(contentsOf: coordinates[(i + 1)...])
                return (completed, remaining)
            }

            accumulated += segmentLength
            completed.append(coordinates[i + 1])
        }

        return (completed, [coordinates.last ?? CLLocationCoordinate2D()])
    }
}

// MARK: - Sample Data

extension RunRoute {

    /// New York City → Los Angeles (~2,790 miles)
    static let nycToLA = RunRoute(
        id: UUID(),
        name: "Coast to Coast",
        origin: "New York City",
        destination: "Los Angeles",
        coordinates: [
            CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),   // NYC
            CLLocationCoordinate2D(latitude: 40.7357, longitude: -74.1724),   // Newark
            CLLocationCoordinate2D(latitude: 40.6023, longitude: -75.4714),   // Allentown
            CLLocationCoordinate2D(latitude: 40.2732, longitude: -76.8867),   // Harrisburg
            CLLocationCoordinate2D(latitude: 40.4406, longitude: -79.9959),   // Pittsburgh
            CLLocationCoordinate2D(latitude: 41.0814, longitude: -81.5190),   // Akron
            CLLocationCoordinate2D(latitude: 39.9612, longitude: -82.9988),   // Columbus
            CLLocationCoordinate2D(latitude: 39.7589, longitude: -84.1916),   // Dayton
            CLLocationCoordinate2D(latitude: 39.7684, longitude: -86.1581),   // Indianapolis
            CLLocationCoordinate2D(latitude: 39.4667, longitude: -87.4139),   // Terre Haute
            CLLocationCoordinate2D(latitude: 38.6270, longitude: -90.1994),   // St. Louis
            CLLocationCoordinate2D(latitude: 39.0997, longitude: -94.5786),   // Kansas City
            CLLocationCoordinate2D(latitude: 38.8403, longitude: -97.6114),   // Salina
            CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),  // Denver
            CLLocationCoordinate2D(latitude: 39.0639, longitude: -108.5506),  // Grand Junction
            CLLocationCoordinate2D(latitude: 38.5733, longitude: -109.5498),  // Moab
            CLLocationCoordinate2D(latitude: 40.7608, longitude: -111.8910),  // Salt Lake City
            CLLocationCoordinate2D(latitude: 40.8410, longitude: -115.7631),  // Elko
            CLLocationCoordinate2D(latitude: 39.5296, longitude: -119.8138),  // Reno
            CLLocationCoordinate2D(latitude: 38.5816, longitude: -121.4944),  // Sacramento
            CLLocationCoordinate2D(latitude: 36.7783, longitude: -119.4179),  // Fresno
            CLLocationCoordinate2D(latitude: 35.3733, longitude: -119.0187),  // Bakersfield
            CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),  // Los Angeles
        ],
        totalDistanceMiles: 2790,
        landmarks: [
            Landmark(id: UUID(), name: "Pittsburgh", state: "PA",
                     coordinate: CLLocationCoordinate2D(latitude: 40.4406, longitude: -79.9959),
                     distanceFromStartMiles: 370),
            Landmark(id: UUID(), name: "Indianapolis", state: "IN",
                     coordinate: CLLocationCoordinate2D(latitude: 39.7684, longitude: -86.1581),
                     distanceFromStartMiles: 740),
            Landmark(id: UUID(), name: "St. Louis", state: "MO",
                     coordinate: CLLocationCoordinate2D(latitude: 38.6270, longitude: -90.1994),
                     distanceFromStartMiles: 950),
            Landmark(id: UUID(), name: "Kansas City", state: "MO",
                     coordinate: CLLocationCoordinate2D(latitude: 39.0997, longitude: -94.5786),
                     distanceFromStartMiles: 1200),
            Landmark(id: UUID(), name: "Denver", state: "CO",
                     coordinate: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
                     distanceFromStartMiles: 1630),
            Landmark(id: UUID(), name: "Salt Lake City", state: "UT",
                     coordinate: CLLocationCoordinate2D(latitude: 40.7608, longitude: -111.8910),
                     distanceFromStartMiles: 2020),
            Landmark(id: UUID(), name: "Reno", state: "NV",
                     coordinate: CLLocationCoordinate2D(latitude: 39.5296, longitude: -119.8138),
                     distanceFromStartMiles: 2370),
            Landmark(id: UUID(), name: "Los Angeles", state: "CA",
                     coordinate: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
                     distanceFromStartMiles: 2790),
        ]
    )
}

// MARK: - Location Name Helper

extension RunRoute {

    /// Returns the name of the nearest landmark to the given mileage.
    func nearestLocationName(atMiles miles: Double) -> String {
        if miles < 10 { return origin }

        guard let nearest = landmarks.min(by: {
            abs($0.distanceFromStartMiles - miles) < abs($1.distanceFromStartMiles - miles)
        }) else {
            return origin
        }

        return "\(nearest.name), \(nearest.state)"
    }
}

// MARK: - User Progress

struct UserProgress {
    let completedMiles: Double
    let nearestLocationName: String
}
