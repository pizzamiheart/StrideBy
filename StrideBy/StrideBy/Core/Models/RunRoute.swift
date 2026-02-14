//
//  RunRoute.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Models

struct RunRoute: Identifiable {
    let id: String
    let name: String
    let origin: String
    let destination: String
    let icon: String
    let coordinates: [CLLocationCoordinate2D]
    let totalDistanceMiles: Double
    let pointsOfInterest: [Landmark]
    let landmarks: [Landmark]
}

struct Landmark: Identifiable {
    let id: String
    let name: String
    let state: String
    let coordinate: CLLocationCoordinate2D
    let distanceFromStartMiles: Double
}

// MARK: - Route Geometry Helpers

extension RunRoute {

    private func coordinatePathLengthMeters(for coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 0..<coordinates.count - 1 {
            let from = CLLocation(latitude: coordinates[i].latitude,
                                  longitude: coordinates[i].longitude)
            let to = CLLocation(latitude: coordinates[i + 1].latitude,
                                longitude: coordinates[i + 1].longitude)
            total += to.distance(from: from)
        }
        return total
    }

    /// Converts road miles to a target distance along the coordinate path.
    /// This ensures that 0 miles maps to the start, and totalDistanceMiles
    /// maps to the end, regardless of the geometric path length.
    private func targetMetersAlongPath(forMiles miles: Double,
                                       in coordinates: [CLLocationCoordinate2D]) -> Double {
        let pathLength = coordinatePathLengthMeters(for: coordinates)
        guard pathLength > 0 else { return 0 }
        let fraction = min(max(miles / totalDistanceMiles, 0), 1.0)
        return fraction * pathLength
    }

    /// Returns the interpolated coordinate at a given distance (in road miles) along the route.
    func coordinateAt(miles: Double) -> CLLocationCoordinate2D {
        coordinateAt(miles: miles, using: coordinates)
    }

    /// Returns the interpolated coordinate at a given distance (in road miles)
    /// using a provided coordinate path.
    func coordinateAt(miles: Double, using activeCoordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard activeCoordinates.count >= 2 else {
            return activeCoordinates.first ?? CLLocationCoordinate2D()
        }

        let targetMeters = targetMetersAlongPath(forMiles: miles, in: activeCoordinates)
        var accumulated: Double = 0

        for i in 0..<activeCoordinates.count - 1 {
            let from = CLLocation(latitude: activeCoordinates[i].latitude,
                                  longitude: activeCoordinates[i].longitude)
            let to = CLLocation(latitude: activeCoordinates[i + 1].latitude,
                                longitude: activeCoordinates[i + 1].longitude)
            let segmentLength = to.distance(from: from)

            if accumulated + segmentLength >= targetMeters {
                let fraction = (targetMeters - accumulated) / segmentLength
                let lat = activeCoordinates[i].latitude
                    + (activeCoordinates[i + 1].latitude - activeCoordinates[i].latitude) * fraction
                let lon = activeCoordinates[i].longitude
                    + (activeCoordinates[i + 1].longitude - activeCoordinates[i].longitude) * fraction
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            accumulated += segmentLength
        }
        return activeCoordinates.last ?? CLLocationCoordinate2D()
    }

    /// The coordinates for the portion of the route already completed.
    func completedCoordinates(miles: Double) -> [CLLocationCoordinate2D] {
        completedCoordinates(miles: miles, using: coordinates)
    }

    func completedCoordinates(miles: Double, using activeCoordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        splitCoordinates(at: miles, using: activeCoordinates).completed
    }

    /// The coordinates for the remaining portion of the route.
    func remainingCoordinates(miles: Double) -> [CLLocationCoordinate2D] {
        remainingCoordinates(miles: miles, using: coordinates)
    }

    func remainingCoordinates(miles: Double, using activeCoordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        splitCoordinates(at: miles, using: activeCoordinates).remaining
    }

    private func splitCoordinates(at miles: Double,
                                  using activeCoordinates: [CLLocationCoordinate2D]) -> (completed: [CLLocationCoordinate2D],
                                                                                            remaining: [CLLocationCoordinate2D]) {
        guard activeCoordinates.count >= 2 else {
            let fallback = activeCoordinates.first ?? CLLocationCoordinate2D()
            return ([fallback], [fallback])
        }

        let targetMeters = targetMetersAlongPath(forMiles: miles, in: activeCoordinates)
        var accumulated: Double = 0
        var completed: [CLLocationCoordinate2D] = [activeCoordinates[0]]

        for i in 0..<activeCoordinates.count - 1 {
            let from = CLLocation(latitude: activeCoordinates[i].latitude,
                                  longitude: activeCoordinates[i].longitude)
            let to = CLLocation(latitude: activeCoordinates[i + 1].latitude,
                                longitude: activeCoordinates[i + 1].longitude)
            let segmentLength = to.distance(from: from)

            if accumulated + segmentLength >= targetMeters {
                // Interpolate the split point
                let fraction = (targetMeters - accumulated) / segmentLength
                let lat = activeCoordinates[i].latitude
                    + (activeCoordinates[i + 1].latitude - activeCoordinates[i].latitude) * fraction
                let lon = activeCoordinates[i].longitude
                    + (activeCoordinates[i + 1].longitude - activeCoordinates[i].longitude) * fraction
                let splitPoint = CLLocationCoordinate2D(latitude: lat, longitude: lon)

                completed.append(splitPoint)
                var remaining = [splitPoint]
                remaining.append(contentsOf: activeCoordinates[(i + 1)...])
                return (completed, remaining)
            }

            accumulated += segmentLength
            completed.append(activeCoordinates[i + 1])
        }

        return (completed, [activeCoordinates.last ?? CLLocationCoordinate2D()])
    }
}

// MARK: - Bounding Region

extension RunRoute {

    /// A map region that frames the entire route with padding.
    var boundingRegion: MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        // Add 20% padding so the route doesn't touch the edges
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.4,
            longitudeDelta: (maxLon - minLon) * 1.4
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - All Routes

extension RunRoute {

    static let allRoutes: [RunRoute] = [
        .nycToLA,
        .londonToIstanbul,
        .tokyoToKyoto,
        .reykjavikToVik,
        .sydneyToMelbourne,
    ]

    /// Look up a route by its string ID.
    static func route(forKey key: String) -> RunRoute? {
        allRoutes.first { $0.id == key }
    }
}

// MARK: - Route Definitions

extension RunRoute {

    // ───────────────────────────────────────────────
    // 1. New York City → Los Angeles (~2,790 miles)
    //    Follows I-80/I-76/I-70 → I-15 → I-80 → I-5/CA-99
    // ───────────────────────────────────────────────

    static let nycToLA = RunRoute(
        id: "nyc-to-la",
        name: "Coast to Coast",
        origin: "New York City",
        destination: "Los Angeles",
        icon: "flag.fill",
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
            CLLocationCoordinate2D(latitude: 38.6819, longitude: -100.4398),  // Dodge City area
            CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),  // Denver
            CLLocationCoordinate2D(latitude: 39.6403, longitude: -106.3742),  // Vail
            CLLocationCoordinate2D(latitude: 39.0639, longitude: -108.5506),  // Grand Junction
            CLLocationCoordinate2D(latitude: 38.9933, longitude: -110.1530),  // Green River, UT
            CLLocationCoordinate2D(latitude: 39.6640, longitude: -111.5854),  // Price/Helper, UT
            CLLocationCoordinate2D(latitude: 40.2338, longitude: -111.6585),  // Provo
            CLLocationCoordinate2D(latitude: 40.7608, longitude: -111.8910),  // Salt Lake City
            CLLocationCoordinate2D(latitude: 40.7440, longitude: -113.0861),  // Wendover area
            CLLocationCoordinate2D(latitude: 40.8410, longitude: -115.7631),  // Elko
            CLLocationCoordinate2D(latitude: 40.6847, longitude: -117.4168),  // Winnemucca
            CLLocationCoordinate2D(latitude: 39.5296, longitude: -119.8138),  // Reno
            CLLocationCoordinate2D(latitude: 38.5816, longitude: -121.4944),  // Sacramento
            CLLocationCoordinate2D(latitude: 37.9577, longitude: -121.2908),  // Stockton
            CLLocationCoordinate2D(latitude: 37.3022, longitude: -120.4830),  // Merced
            CLLocationCoordinate2D(latitude: 36.7783, longitude: -119.7871),  // Fresno
            CLLocationCoordinate2D(latitude: 36.3302, longitude: -119.2921),  // Visalia
            CLLocationCoordinate2D(latitude: 35.3733, longitude: -119.0187),  // Bakersfield
            CLLocationCoordinate2D(latitude: 34.8680, longitude: -118.7098),  // Tehachapi/Lancaster
            CLLocationCoordinate2D(latitude: 34.3917, longitude: -118.5426),  // Santa Clarita
            CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),  // Los Angeles
        ],
        totalDistanceMiles: 2790,
        pointsOfInterest: nycToLAPOIs,
        landmarks: [
            Landmark(id: "nyc-pittsburgh", name: "Pittsburgh", state: "PA",
                     coordinate: CLLocationCoordinate2D(latitude: 40.4406, longitude: -79.9959),
                     distanceFromStartMiles: 370),
            Landmark(id: "nyc-indianapolis", name: "Indianapolis", state: "IN",
                     coordinate: CLLocationCoordinate2D(latitude: 39.7684, longitude: -86.1581),
                     distanceFromStartMiles: 740),
            Landmark(id: "nyc-stlouis", name: "St. Louis", state: "MO",
                     coordinate: CLLocationCoordinate2D(latitude: 38.6270, longitude: -90.1994),
                     distanceFromStartMiles: 950),
            Landmark(id: "nyc-kansascity", name: "Kansas City", state: "MO",
                     coordinate: CLLocationCoordinate2D(latitude: 39.0997, longitude: -94.5786),
                     distanceFromStartMiles: 1200),
            Landmark(id: "nyc-denver", name: "Denver", state: "CO",
                     coordinate: CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903),
                     distanceFromStartMiles: 1630),
            Landmark(id: "nyc-saltlakecity", name: "Salt Lake City", state: "UT",
                     coordinate: CLLocationCoordinate2D(latitude: 40.7608, longitude: -111.8910),
                     distanceFromStartMiles: 2020),
            Landmark(id: "nyc-reno", name: "Reno", state: "NV",
                     coordinate: CLLocationCoordinate2D(latitude: 39.5296, longitude: -119.8138),
                     distanceFromStartMiles: 2370),
            Landmark(id: "nyc-losangeles", name: "Los Angeles", state: "CA",
                     coordinate: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
                     distanceFromStartMiles: 2790),
        ]
    )

    // ───────────────────────────────────────────────
    // 2. London → Istanbul (~1,770 miles)
    //    Follows E40/E5 corridor through western/central Europe
    // ───────────────────────────────────────────────

    static let londonToIstanbul = RunRoute(
        id: "london-to-istanbul",
        name: "European Crossing",
        origin: "London",
        destination: "Istanbul",
        icon: "globe.europe.africa.fill",
        coordinates: [
            CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),    // London
            CLLocationCoordinate2D(latitude: 51.1279, longitude:  1.3134),    // Dover
            CLLocationCoordinate2D(latitude: 50.9513, longitude:  1.8587),    // Calais
            CLLocationCoordinate2D(latitude: 49.8988, longitude:  2.2957),    // Amiens
            CLLocationCoordinate2D(latitude: 48.8566, longitude:  2.3522),    // Paris
            CLLocationCoordinate2D(latitude: 48.9845, longitude:  3.4057),    // Château-Thierry
            CLLocationCoordinate2D(latitude: 48.5734, longitude:  7.7521),    // Strasbourg
            CLLocationCoordinate2D(latitude: 48.4011, longitude:  9.9876),    // Ulm
            CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),    // Munich
            CLLocationCoordinate2D(latitude: 48.3064, longitude: 14.2858),    // Linz
            CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),    // Vienna
            CLLocationCoordinate2D(latitude: 47.6849, longitude: 17.6351),    // Győr
            CLLocationCoordinate2D(latitude: 47.4979, longitude: 19.0402),    // Budapest
            CLLocationCoordinate2D(latitude: 46.2530, longitude: 20.1414),    // Szeged
            CLLocationCoordinate2D(latitude: 44.7866, longitude: 20.4489),    // Belgrade
            CLLocationCoordinate2D(latitude: 43.3209, longitude: 21.8958),    // Niš
            CLLocationCoordinate2D(latitude: 42.6977, longitude: 23.3219),    // Sofia
            CLLocationCoordinate2D(latitude: 42.1497, longitude: 24.7500),    // Plovdiv
            CLLocationCoordinate2D(latitude: 41.6772, longitude: 26.5557),    // Edirne
            CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),    // Istanbul
        ],
        totalDistanceMiles: 1770,
        pointsOfInterest: londonToIstanbulPOIs,
        landmarks: [
            Landmark(id: "eur-paris", name: "Paris", state: "France",
                     coordinate: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
                     distanceFromStartMiles: 280),
            Landmark(id: "eur-strasbourg", name: "Strasbourg", state: "France",
                     coordinate: CLLocationCoordinate2D(latitude: 48.5734, longitude: 7.7521),
                     distanceFromStartMiles: 490),
            Landmark(id: "eur-munich", name: "Munich", state: "Germany",
                     coordinate: CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),
                     distanceFromStartMiles: 680),
            Landmark(id: "eur-vienna", name: "Vienna", state: "Austria",
                     coordinate: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
                     distanceFromStartMiles: 910),
            Landmark(id: "eur-budapest", name: "Budapest", state: "Hungary",
                     coordinate: CLLocationCoordinate2D(latitude: 47.4979, longitude: 19.0402),
                     distanceFromStartMiles: 1080),
            Landmark(id: "eur-belgrade", name: "Belgrade", state: "Serbia",
                     coordinate: CLLocationCoordinate2D(latitude: 44.7866, longitude: 20.4489),
                     distanceFromStartMiles: 1270),
            Landmark(id: "eur-sofia", name: "Sofia", state: "Bulgaria",
                     coordinate: CLLocationCoordinate2D(latitude: 42.6977, longitude: 23.3219),
                     distanceFromStartMiles: 1490),
            Landmark(id: "eur-istanbul", name: "Istanbul", state: "Turkey",
                     coordinate: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
                     distanceFromStartMiles: 1770),
        ]
    )

    // ───────────────────────────────────────────────
    // 3. Tokyo → Kyoto (~300 miles)
    //    Follows the historic Tōkaidō route / Shinkansen corridor
    // ───────────────────────────────────────────────

    static let tokyoToKyoto = RunRoute(
        id: "tokyo-to-kyoto",
        name: "The Tōkaidō",
        origin: "Tokyo",
        destination: "Kyoto",
        icon: "globe.asia.australia.fill",
        coordinates: [
            CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),   // Tokyo
            CLLocationCoordinate2D(latitude: 35.4437, longitude: 139.6380),   // Yokohama
            CLLocationCoordinate2D(latitude: 35.3293, longitude: 139.4803),   // Kamakura
            CLLocationCoordinate2D(latitude: 35.2564, longitude: 139.1550),   // Odawara
            CLLocationCoordinate2D(latitude: 35.1006, longitude: 138.8606),   // Hakone/Mishima
            CLLocationCoordinate2D(latitude: 34.9756, longitude: 138.3827),   // Shizuoka
            CLLocationCoordinate2D(latitude: 34.7108, longitude: 137.7261),   // Hamamatsu
            CLLocationCoordinate2D(latitude: 34.7303, longitude: 137.3948),   // Toyohashi
            CLLocationCoordinate2D(latitude: 35.1815, longitude: 136.9066),   // Nagoya
            CLLocationCoordinate2D(latitude: 34.9672, longitude: 136.6245),   // Suzuka
            CLLocationCoordinate2D(latitude: 34.9300, longitude: 136.1828),   // Iga area
            CLLocationCoordinate2D(latitude: 35.0116, longitude: 135.7681),   // Kyoto
        ],
        totalDistanceMiles: 300,
        pointsOfInterest: tokyoToKyotoPOIs,
        landmarks: [
            Landmark(id: "jpn-kamakura", name: "Kamakura", state: "Kanagawa",
                     coordinate: CLLocationCoordinate2D(latitude: 35.3293, longitude: 139.4803),
                     distanceFromStartMiles: 30),
            Landmark(id: "jpn-hakone", name: "Hakone", state: "Shizuoka",
                     coordinate: CLLocationCoordinate2D(latitude: 35.1006, longitude: 138.8606),
                     distanceFromStartMiles: 60),
            Landmark(id: "jpn-shizuoka", name: "Shizuoka", state: "Shizuoka",
                     coordinate: CLLocationCoordinate2D(latitude: 34.9756, longitude: 138.3827),
                     distanceFromStartMiles: 110),
            Landmark(id: "jpn-hamamatsu", name: "Hamamatsu", state: "Shizuoka",
                     coordinate: CLLocationCoordinate2D(latitude: 34.7108, longitude: 137.7261),
                     distanceFromStartMiles: 165),
            Landmark(id: "jpn-nagoya", name: "Nagoya", state: "Aichi",
                     coordinate: CLLocationCoordinate2D(latitude: 35.1815, longitude: 136.9066),
                     distanceFromStartMiles: 220),
            Landmark(id: "jpn-kyoto", name: "Kyoto", state: "Kyoto",
                     coordinate: CLLocationCoordinate2D(latitude: 35.0116, longitude: 135.7681),
                     distanceFromStartMiles: 300),
        ]
    )

    // ───────────────────────────────────────────────
    // 4. Reykjavik → Vik (~110 miles)
    //    Follows Route 1 (Ring Road) along the south coast
    // ───────────────────────────────────────────────

    static let reykjavikToVik = RunRoute(
        id: "reykjavik-to-vik",
        name: "Ring Road South",
        origin: "Reykjavik",
        destination: "Vik",
        icon: "snowflake",
        coordinates: [
            CLLocationCoordinate2D(latitude: 64.1466, longitude: -21.9426),   // Reykjavik
            CLLocationCoordinate2D(latitude: 64.0753, longitude: -21.6874),   // Mosfellsbær
            CLLocationCoordinate2D(latitude: 64.0153, longitude: -21.1874),   // Hveragerdi
            CLLocationCoordinate2D(latitude: 63.9461, longitude: -20.6600),   // Selfoss
            CLLocationCoordinate2D(latitude: 63.7626, longitude: -20.2290),   // Hella
            CLLocationCoordinate2D(latitude: 63.6335, longitude: -19.8262),   // Hvolsvöllur
            CLLocationCoordinate2D(latitude: 63.5320, longitude: -19.5112),   // Skógafoss area
            CLLocationCoordinate2D(latitude: 63.4186, longitude: -19.0060),   // Vik
        ],
        totalDistanceMiles: 110,
        pointsOfInterest: reykjavikToVikPOIs,
        landmarks: [
            Landmark(id: "ice-hveragerdi", name: "Hveragerdi", state: "South Iceland",
                     coordinate: CLLocationCoordinate2D(latitude: 64.0153, longitude: -21.1874),
                     distanceFromStartMiles: 25),
            Landmark(id: "ice-selfoss", name: "Selfoss", state: "South Iceland",
                     coordinate: CLLocationCoordinate2D(latitude: 63.9461, longitude: -20.6600),
                     distanceFromStartMiles: 37),
            Landmark(id: "ice-skogafoss", name: "Skógafoss", state: "South Iceland",
                     coordinate: CLLocationCoordinate2D(latitude: 63.5320, longitude: -19.5112),
                     distanceFromStartMiles: 85),
            Landmark(id: "ice-vik", name: "Vik", state: "South Iceland",
                     coordinate: CLLocationCoordinate2D(latitude: 63.4186, longitude: -19.0060),
                     distanceFromStartMiles: 110),
        ]
    )

    // ───────────────────────────────────────────────
    // 5. Sydney → Melbourne (~545 miles)
    //    Follows the Hume Highway (M31/M1)
    // ───────────────────────────────────────────────

    static let sydneyToMelbourne = RunRoute(
        id: "sydney-to-melbourne",
        name: "The Hume",
        origin: "Sydney",
        destination: "Melbourne",
        icon: "globe.americas.fill",
        coordinates: [
            CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093),  // Sydney
            CLLocationCoordinate2D(latitude: -34.0588, longitude: 150.8052),  // Campbelltown
            CLLocationCoordinate2D(latitude: -34.2890, longitude: 150.4541),  // Mittagong
            CLLocationCoordinate2D(latitude: -34.7515, longitude: 149.7185),  // Goulburn
            CLLocationCoordinate2D(latitude: -34.8580, longitude: 149.3575),  // Yass
            CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300),  // Canberra
            CLLocationCoordinate2D(latitude: -35.5920, longitude: 148.4600),  // Tumbarumba area
            CLLocationCoordinate2D(latitude: -35.9344, longitude: 147.9535),  // Holbrook
            CLLocationCoordinate2D(latitude: -36.3690, longitude: 146.9235),  // Albury/Wodonga
            CLLocationCoordinate2D(latitude: -36.5400, longitude: 146.4268),  // Wangaratta
            CLLocationCoordinate2D(latitude: -36.7570, longitude: 145.9600),  // Benalla/Shepparton
            CLLocationCoordinate2D(latitude: -37.0465, longitude: 145.5780),  // Euroa
            CLLocationCoordinate2D(latitude: -37.5622, longitude: 145.4709),  // Seymour
            CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631),  // Melbourne
        ],
        totalDistanceMiles: 545,
        pointsOfInterest: sydneyToMelbournePOIs,
        landmarks: [
            Landmark(id: "aus-goulburn", name: "Goulburn", state: "NSW",
                     coordinate: CLLocationCoordinate2D(latitude: -34.7515, longitude: 149.7185),
                     distanceFromStartMiles: 120),
            Landmark(id: "aus-canberra", name: "Canberra", state: "ACT",
                     coordinate: CLLocationCoordinate2D(latitude: -35.2809, longitude: 149.1300),
                     distanceFromStartMiles: 180),
            Landmark(id: "aus-albury", name: "Albury", state: "NSW",
                     coordinate: CLLocationCoordinate2D(latitude: -36.3690, longitude: 146.9235),
                     distanceFromStartMiles: 355),
            Landmark(id: "aus-wangaratta", name: "Wangaratta", state: "VIC",
                     coordinate: CLLocationCoordinate2D(latitude: -36.5400, longitude: 146.4268),
                     distanceFromStartMiles: 420),
            Landmark(id: "aus-melbourne", name: "Melbourne", state: "VIC",
                     coordinate: CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631),
                     distanceFromStartMiles: 545),
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

    /// Returns the closest point of interest to the user's current position.
    func nearestPOI(atMiles miles: Double) -> Landmark? {
        pointsOfInterest.min(by: {
            abs($0.distanceFromStartMiles - miles) < abs($1.distanceFromStartMiles - miles)
        })
    }

    /// Returns the nearest points of interest sorted by route-distance difference.
    func nearestPOIs(atMiles miles: Double, limit: Int) -> [Landmark] {
        pointsOfInterest
            .sorted {
                abs($0.distanceFromStartMiles - miles) < abs($1.distanceFromStartMiles - miles)
            }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - User Progress

struct UserProgress {
    let completedMiles: Double
    let nearestLocationName: String
}
