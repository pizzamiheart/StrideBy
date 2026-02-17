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

private struct RouteWaypoint {
    let name: String
    let region: String
    let coordinate: CLLocationCoordinate2D
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
        // City-forward MVP catalog (high probability Look Around density)
        .parisCityLoop,
        .londonCityLoop,
        .newYorkCityLoop,
        .losAngelesCityLoop,
        .sanFranciscoCityLoop,
        .chicagoCityLoop,
        .berlinCityLoop,
        .madridCityLoop,
        .barcelonaCityLoop,
        .milanCityLoop,
        .romeCityLoop,
        .tokyoCityLoop,
        .sydneyCityLoop,
        .torontoCityLoop,
    ]

    /// Look up a route by its string ID.
    static func route(forKey key: String) -> RunRoute? {
        allRoutes.first { $0.id == key }
    }
}

// MARK: - Route Factory

private extension RunRoute {

    static func wp(_ name: String,
                   _ region: String,
                   _ latitude: Double,
                   _ longitude: Double) -> RouteWaypoint {
        RouteWaypoint(
            name: name,
            region: region,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        )
    }

    static func mileMark(index: Int, count: Int, totalMiles: Double) -> Double {
        guard count > 1 else { return 0 }
        let fraction = Double(index) / Double(count - 1)
        return (fraction * totalMiles).rounded()
    }

    static func makeRoute(id: String,
                          name: String,
                          origin: String,
                          destination: String,
                          icon: String,
                          totalDistanceMiles: Double,
                          waypoints: [RouteWaypoint],
                          landmarkIndices: [Int]) -> RunRoute {
        let coordinates = waypoints.map(\.coordinate)

        let pointsOfInterest = waypoints.enumerated().map { index, point in
            Landmark(
                id: "\(id)-poi-\(index)",
                name: point.name,
                state: point.region,
                coordinate: point.coordinate,
                distanceFromStartMiles: mileMark(index: index, count: waypoints.count, totalMiles: totalDistanceMiles)
            )
        }

        let normalizedLandmarkIndices = Array(
            Set(landmarkIndices + [0, max(waypoints.count - 1, 0)])
        )
        .filter { $0 >= 0 && $0 < waypoints.count }
        .sorted()

        let landmarks = normalizedLandmarkIndices.map { index in
            let point = waypoints[index]
            return Landmark(
                id: "\(id)-landmark-\(index)",
                name: point.name,
                state: point.region,
                coordinate: point.coordinate,
                distanceFromStartMiles: mileMark(index: index, count: waypoints.count, totalMiles: totalDistanceMiles)
            )
        }

        return RunRoute(
            id: id,
            name: name,
            origin: origin,
            destination: destination,
            icon: icon,
            coordinates: coordinates,
            totalDistanceMiles: totalDistanceMiles,
            pointsOfInterest: pointsOfInterest,
            landmarks: landmarks
        )
    }
}

// MARK: - Route Definitions

extension RunRoute {

    // MARK: City-First MVP Routes (15)

    static let parisCityLoop = makeRoute(
        id: "paris-city-loop",
        name: "Paris Arrondissement Tour",
        origin: "Montmartre",
        destination: "Bastille",
        icon: "building.2.fill",
        totalDistanceMiles: 28,
        waypoints: [
            wp("Montmartre", "Paris", 48.8867, 2.3431),
            wp("Opera", "Paris", 48.8708, 2.3319),
            wp("Louvre", "Paris", 48.8606, 2.3376),
            wp("Saint-Germain", "Paris", 48.8546, 2.3339),
            wp("Luxembourg", "Paris", 48.8462, 2.3371),
            wp("Eiffel Tower", "Paris", 48.8584, 2.2945),
            wp("Arc de Triomphe", "Paris", 48.8738, 2.2950),
            wp("Bastille", "Paris", 48.8530, 2.3691),
        ],
        landmarkIndices: [2, 5, 7]
    )

    static let londonCityLoop = makeRoute(
        id: "london-city-loop",
        name: "London Borough Spin",
        origin: "Camden",
        destination: "Canary Wharf",
        icon: "building.2.fill",
        totalDistanceMiles: 31,
        waypoints: [
            wp("Camden", "London", 51.5390, -0.1426),
            wp("Marylebone", "London", 51.5227, -0.1628),
            wp("Westminster", "London", 51.4975, -0.1357),
            wp("South Bank", "London", 51.5079, -0.0983),
            wp("Tower Bridge", "London", 51.5055, -0.0754),
            wp("Shoreditch", "London", 51.5245, -0.0776),
            wp("Canary Wharf", "London", 51.5054, -0.0235),
        ],
        landmarkIndices: [2, 4, 6]
    )

    static let newYorkCityLoop = makeRoute(
        id: "new-york-city-loop",
        name: "NYC Five-Borough Mix",
        origin: "Upper West Side",
        destination: "DUMBO",
        icon: "building.2.fill",
        totalDistanceMiles: 34,
        waypoints: [
            wp("Upper West Side", "New York", 40.7870, -73.9754),
            wp("Times Square", "New York", 40.7580, -73.9855),
            wp("Chelsea", "New York", 40.7465, -74.0014),
            wp("Financial District", "New York", 40.7075, -74.0113),
            wp("Williamsburg", "New York", 40.7081, -73.9571),
            wp("Long Island City", "New York", 40.7447, -73.9485),
            wp("Astoria", "New York", 40.7644, -73.9235),
            wp("DUMBO", "New York", 40.7033, -73.9881),
        ],
        landmarkIndices: [1, 3, 7]
    )

    static let losAngelesCityLoop = makeRoute(
        id: "los-angeles-city-loop",
        name: "LA Studio Circuit",
        origin: "Santa Monica",
        destination: "Downtown LA",
        icon: "building.2.fill",
        totalDistanceMiles: 36,
        waypoints: [
            wp("Santa Monica", "Los Angeles", 34.0195, -118.4912),
            wp("Venice", "Los Angeles", 33.9850, -118.4695),
            wp("Culver City", "Los Angeles", 34.0211, -118.3965),
            wp("Beverly Hills", "Los Angeles", 34.0736, -118.4004),
            wp("West Hollywood", "Los Angeles", 34.0900, -118.3617),
            wp("Hollywood", "Los Angeles", 34.1016, -118.3267),
            wp("Silver Lake", "Los Angeles", 34.0860, -118.2700),
            wp("Downtown LA", "Los Angeles", 34.0407, -118.2468),
        ],
        landmarkIndices: [2, 5, 7]
    )

    static let sanFranciscoCityLoop = makeRoute(
        id: "san-francisco-city-loop",
        name: "San Francisco Hills Tour",
        origin: "Golden Gate Park",
        destination: "Embarcadero",
        icon: "building.2.fill",
        totalDistanceMiles: 24,
        waypoints: [
            wp("Golden Gate Park", "San Francisco", 37.7694, -122.4862),
            wp("Haight-Ashbury", "San Francisco", 37.7691, -122.4481),
            wp("Castro", "San Francisco", 37.7609, -122.4350),
            wp("Mission District", "San Francisco", 37.7599, -122.4148),
            wp("SOMA", "San Francisco", 37.7786, -122.4059),
            wp("North Beach", "San Francisco", 37.8061, -122.4103),
            wp("Marina", "San Francisco", 37.8037, -122.4368),
            wp("Embarcadero", "San Francisco", 37.7955, -122.3937),
        ],
        landmarkIndices: [3, 5, 7]
    )

    static let chicagoCityLoop = makeRoute(
        id: "chicago-city-loop",
        name: "Chicago Lakefront Cruise",
        origin: "Wrigleyville",
        destination: "Museum Campus",
        icon: "building.2.fill",
        totalDistanceMiles: 27,
        waypoints: [
            wp("Wrigleyville", "Chicago", 41.9484, -87.6553),
            wp("Lincoln Park", "Chicago", 41.9214, -87.6513),
            wp("Gold Coast", "Chicago", 41.9058, -87.6315),
            wp("The Loop", "Chicago", 41.8837, -87.6324),
            wp("West Loop", "Chicago", 41.8825, -87.6441),
            wp("South Loop", "Chicago", 41.8675, -87.6243),
            wp("Museum Campus", "Chicago", 41.8663, -87.6170),
        ],
        landmarkIndices: [2, 3, 6]
    )

    static let berlinCityLoop = makeRoute(
        id: "berlin-city-loop",
        name: "Berlin Ring Route",
        origin: "Charlottenburg",
        destination: "East Side Gallery",
        icon: "building.2.fill",
        totalDistanceMiles: 29,
        waypoints: [
            wp("Charlottenburg", "Berlin", 52.5208, 13.3041),
            wp("Tiergarten", "Berlin", 52.5145, 13.3501),
            wp("Brandenburg Gate", "Berlin", 52.5163, 13.3777),
            wp("Mitte", "Berlin", 52.5206, 13.3862),
            wp("Alexanderplatz", "Berlin", 52.5219, 13.4132),
            wp("Prenzlauer Berg", "Berlin", 52.5386, 13.4243),
            wp("Kreuzberg", "Berlin", 52.4986, 13.4030),
            wp("East Side Gallery", "Berlin", 52.5050, 13.4399),
        ],
        landmarkIndices: [2, 4, 7]
    )

    static let madridCityLoop = makeRoute(
        id: "madrid-city-loop",
        name: "Madrid Gran Via Run",
        origin: "Chamartin",
        destination: "Retiro",
        icon: "building.2.fill",
        totalDistanceMiles: 26,
        waypoints: [
            wp("Chamartin", "Madrid", 40.4722, -3.6826),
            wp("Santiago Bernabeu", "Madrid", 40.4531, -3.6883),
            wp("Gran Via", "Madrid", 40.4203, -3.7058),
            wp("Puerta del Sol", "Madrid", 40.4169, -3.7035),
            wp("Lavapies", "Madrid", 40.4087, -3.7003),
            wp("Atocha", "Madrid", 40.4066, -3.6892),
            wp("Retiro", "Madrid", 40.4153, -3.6844),
        ],
        landmarkIndices: [2, 3, 6]
    )

    static let barcelonaCityLoop = makeRoute(
        id: "barcelona-city-loop",
        name: "Barcelona Coast to Hills",
        origin: "Barceloneta",
        destination: "Sants",
        icon: "building.2.fill",
        totalDistanceMiles: 25,
        waypoints: [
            wp("Barceloneta", "Barcelona", 41.3790, 2.1896),
            wp("El Born", "Barcelona", 41.3851, 2.1830),
            wp("Gothic Quarter", "Barcelona", 41.3839, 2.1769),
            wp("Eixample", "Barcelona", 41.3917, 2.1649),
            wp("Sagrada Familia", "Barcelona", 41.4036, 2.1744),
            wp("Gracia", "Barcelona", 41.4033, 2.1561),
            wp("Montjuic", "Barcelona", 41.3636, 2.1585),
            wp("Sants", "Barcelona", 41.3794, 2.1402),
        ],
        landmarkIndices: [3, 4, 7]
    )

    static let milanCityLoop = makeRoute(
        id: "milan-city-loop",
        name: "Milan District Dash",
        origin: "Navigli",
        destination: "Duomo",
        icon: "building.2.fill",
        totalDistanceMiles: 22,
        waypoints: [
            wp("Navigli", "Milan", 45.4501, 9.1739),
            wp("Porta Genova", "Milan", 45.4527, 9.1706),
            wp("Brera", "Milan", 45.4722, 9.1880),
            wp("Porta Nuova", "Milan", 45.4834, 9.1896),
            wp("Citta Studi", "Milan", 45.4765, 9.2276),
            wp("Porta Romana", "Milan", 45.4520, 9.2023),
            wp("Duomo", "Milan", 45.4642, 9.1900),
        ],
        landmarkIndices: [2, 3, 6]
    )

    static let romeCityLoop = makeRoute(
        id: "rome-city-loop",
        name: "Rome Seven Hills Route",
        origin: "Vatican",
        destination: "Colosseum",
        icon: "building.2.fill",
        totalDistanceMiles: 24,
        waypoints: [
            wp("Vatican", "Rome", 41.9022, 12.4539),
            wp("Piazza Navona", "Rome", 41.8992, 12.4731),
            wp("Pantheon", "Rome", 41.8986, 12.4769),
            wp("Trevi Fountain", "Rome", 41.9009, 12.4833),
            wp("Spanish Steps", "Rome", 41.9059, 12.4823),
            wp("Trastevere", "Rome", 41.8897, 12.4708),
            wp("Colosseum", "Rome", 41.8902, 12.4922),
        ],
        landmarkIndices: [2, 4, 6]
    )

    static let tokyoCityLoop = makeRoute(
        id: "tokyo-city-loop",
        name: "Tokyo Ward Explorer",
        origin: "Shinjuku",
        destination: "Asakusa",
        icon: "building.2.fill",
        totalDistanceMiles: 33,
        waypoints: [
            wp("Shinjuku", "Tokyo", 35.6938, 139.7034),
            wp("Harajuku", "Tokyo", 35.6702, 139.7027),
            wp("Shibuya", "Tokyo", 35.6595, 139.7005),
            wp("Roppongi", "Tokyo", 35.6628, 139.7310),
            wp("Tokyo Station", "Tokyo", 35.6812, 139.7671),
            wp("Akihabara", "Tokyo", 35.6984, 139.7730),
            wp("Ueno", "Tokyo", 35.7138, 139.7772),
            wp("Asakusa", "Tokyo", 35.7148, 139.7967),
        ],
        landmarkIndices: [2, 4, 7]
    )

    static let sydneyCityLoop = makeRoute(
        id: "sydney-city-loop",
        name: "Sydney Harbour Circuit",
        origin: "Bondi",
        destination: "Circular Quay",
        icon: "building.2.fill",
        totalDistanceMiles: 30,
        waypoints: [
            wp("Bondi", "Sydney", -33.8915, 151.2767),
            wp("Paddington", "Sydney", -33.8840, 151.2313),
            wp("Surry Hills", "Sydney", -33.8885, 151.2090),
            wp("Darling Harbour", "Sydney", -33.8748, 151.1982),
            wp("Barangaroo", "Sydney", -33.8602, 151.2016),
            wp("The Rocks", "Sydney", -33.8599, 151.2090),
            wp("North Sydney", "Sydney", -33.8390, 151.2070),
            wp("Circular Quay", "Sydney", -33.8610, 151.2127),
        ],
        landmarkIndices: [3, 5, 7]
    )

    static let torontoCityLoop = makeRoute(
        id: "toronto-city-loop",
        name: "Toronto Waterfront Route",
        origin: "High Park",
        destination: "Distillery District",
        icon: "building.2.fill",
        totalDistanceMiles: 27,
        waypoints: [
            wp("High Park", "Toronto", 43.6465, -79.4637),
            wp("Liberty Village", "Toronto", 43.6393, -79.4208),
            wp("Harbourfront", "Toronto", 43.6388, -79.3817),
            wp("St Lawrence", "Toronto", 43.6487, -79.3716),
            wp("Cabbagetown", "Toronto", 43.6674, -79.3678),
            wp("Yorkville", "Toronto", 43.6709, -79.3933),
            wp("Distillery District", "Toronto", 43.6503, -79.3596),
        ],
        landmarkIndices: [2, 5, 6]
    )

    static let seoulCityLoop = makeRoute(
        id: "seoul-city-loop",
        name: "Seoul River and Palace Run",
        origin: "Hongdae",
        destination: "Jamsil",
        icon: "building.2.fill",
        totalDistanceMiles: 32,
        waypoints: [
            wp("Hongdae", "Seoul", 37.5563, 126.9220),
            wp("Yeouido", "Seoul", 37.5219, 126.9245),
            wp("Itaewon", "Seoul", 37.5345, 126.9940),
            wp("Myeongdong", "Seoul", 37.5636, 126.9834),
            wp("Gwanghwamun", "Seoul", 37.5759, 126.9769),
            wp("Dongdaemun", "Seoul", 37.5713, 127.0095),
            wp("Gangnam", "Seoul", 37.4979, 127.0276),
            wp("Jamsil", "Seoul", 37.5133, 127.1002),
        ],
        landmarkIndices: [3, 4, 7]
    )

    // Germany
    static let berlinToMunich = makeRoute(
        id: "berlin-to-munich",
        name: "Autobahn South",
        origin: "Berlin",
        destination: "Munich",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 365,
        waypoints: [
            wp("Berlin", "Germany", 52.5200, 13.4050),
            wp("Leipzig", "Germany", 51.3397, 12.3731),
            wp("Hof", "Germany", 50.3120, 11.9120),
            wp("Nuremberg", "Germany", 49.4521, 11.0767),
            wp("Ingolstadt", "Germany", 48.7665, 11.4258),
            wp("Munich", "Germany", 48.1351, 11.5820),
        ],
        landmarkIndices: [1, 3, 5]
    )

    static let hamburgToMunich = makeRoute(
        id: "hamburg-to-munich",
        name: "North to Bavaria",
        origin: "Hamburg",
        destination: "Munich",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 490,
        waypoints: [
            wp("Hamburg", "Germany", 53.5511, 9.9937),
            wp("Hanover", "Germany", 52.3759, 9.7320),
            wp("Göttingen", "Germany", 51.5413, 9.9158),
            wp("Kassel", "Germany", 51.3127, 9.4797),
            wp("Würzburg", "Germany", 49.7913, 9.9534),
            wp("Nuremberg", "Germany", 49.4521, 11.0767),
            wp("Munich", "Germany", 48.1351, 11.5820),
        ],
        landmarkIndices: [1, 4, 6]
    )

    static let cologneToBerlin = makeRoute(
        id: "cologne-to-berlin",
        name: "Rhine to Capital",
        origin: "Cologne",
        destination: "Berlin",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 360,
        waypoints: [
            wp("Cologne", "Germany", 50.9375, 6.9603),
            wp("Dortmund", "Germany", 51.5136, 7.4653),
            wp("Hannover", "Germany", 52.3759, 9.7320),
            wp("Brunswick", "Germany", 52.2689, 10.5268),
            wp("Magdeburg", "Germany", 52.1205, 11.6276),
            wp("Berlin", "Germany", 52.5200, 13.4050),
        ],
        landmarkIndices: [1, 3, 5]
    )

    // Italy
    static let romeToMilan = makeRoute(
        id: "rome-to-milan",
        name: "Via Italia",
        origin: "Rome",
        destination: "Milan",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 360,
        waypoints: [
            wp("Rome", "Italy", 41.9028, 12.4964),
            wp("Orvieto", "Italy", 42.7185, 12.1118),
            wp("Florence", "Italy", 43.7696, 11.2558),
            wp("Bologna", "Italy", 44.4949, 11.3426),
            wp("Parma", "Italy", 44.8015, 10.3279),
            wp("Milan", "Italy", 45.4642, 9.1900),
        ],
        landmarkIndices: [2, 3, 5]
    )

    static let naplesToVenice = makeRoute(
        id: "naples-to-venice",
        name: "Tyrrhenian to Adriatic",
        origin: "Naples",
        destination: "Venice",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 470,
        waypoints: [
            wp("Naples", "Italy", 40.8518, 14.2681),
            wp("Rome", "Italy", 41.9028, 12.4964),
            wp("Orvieto", "Italy", 42.7185, 12.1118),
            wp("Florence", "Italy", 43.7696, 11.2558),
            wp("Bologna", "Italy", 44.4949, 11.3426),
            wp("Padua", "Italy", 45.4064, 11.8768),
            wp("Venice", "Italy", 45.4408, 12.3155),
        ],
        landmarkIndices: [1, 3, 5, 6]
    )

    static let romeAmalfiToPalermo = makeRoute(
        id: "rome-amalfi-to-palermo",
        name: "Mediterranean Arc",
        origin: "Rome",
        destination: "Palermo",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 390,
        waypoints: [
            wp("Rome", "Italy", 41.9028, 12.4964),
            wp("Naples", "Italy", 40.8518, 14.2681),
            wp("Amalfi", "Italy", 40.6340, 14.6020),
            wp("Salerno", "Italy", 40.6824, 14.7681),
            wp("Reggio Calabria", "Italy", 38.1112, 15.6477),
            wp("Messina", "Italy", 38.1938, 15.5540),
            wp("Palermo", "Italy", 38.1157, 13.3615),
        ],
        landmarkIndices: [2, 4, 6]
    )

    // Spain
    static let madridToBarcelona = makeRoute(
        id: "madrid-to-barcelona",
        name: "Central Sprint",
        origin: "Madrid",
        destination: "Barcelona",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 385,
        waypoints: [
            wp("Madrid", "Spain", 40.4168, -3.7038),
            wp("Guadalajara", "Spain", 40.6333, -3.1667),
            wp("Zaragoza", "Spain", 41.6488, -0.8891),
            wp("Lleida", "Spain", 41.6176, 0.6200),
            wp("Barcelona", "Spain", 41.3874, 2.1686),
        ],
        landmarkIndices: [2, 4]
    )

    static let sevilleToBarcelona = makeRoute(
        id: "seville-to-barcelona",
        name: "Iberian Spine",
        origin: "Seville",
        destination: "Barcelona",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 620,
        waypoints: [
            wp("Seville", "Spain", 37.3891, -5.9845),
            wp("Cordoba", "Spain", 37.8882, -4.7794),
            wp("Madrid", "Spain", 40.4168, -3.7038),
            wp("Zaragoza", "Spain", 41.6488, -0.8891),
            wp("Tarragona", "Spain", 41.1189, 1.2445),
            wp("Barcelona", "Spain", 41.3874, 2.1686),
        ],
        landmarkIndices: [1, 2, 4, 5]
    )

    static let madridToSeville = makeRoute(
        id: "madrid-to-seville",
        name: "Andalusian Run",
        origin: "Madrid",
        destination: "Seville",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 330,
        waypoints: [
            wp("Madrid", "Spain", 40.4168, -3.7038),
            wp("Toledo", "Spain", 39.8628, -4.0273),
            wp("Ciudad Real", "Spain", 38.9861, -3.9273),
            wp("Cordoba", "Spain", 37.8882, -4.7794),
            wp("Seville", "Spain", 37.3891, -5.9845),
        ],
        landmarkIndices: [1, 3, 4]
    )

    // Portugal + Cross-Iberian
    static let lisbonToPorto = makeRoute(
        id: "lisbon-to-porto",
        name: "Portuguese Classic",
        origin: "Lisbon",
        destination: "Porto",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 195,
        waypoints: [
            wp("Lisbon", "Portugal", 38.7223, -9.1393),
            wp("Leiria", "Portugal", 39.7436, -8.8071),
            wp("Coimbra", "Portugal", 40.2033, -8.4103),
            wp("Aveiro", "Portugal", 40.6405, -8.6538),
            wp("Porto", "Portugal", 41.1579, -8.6291),
        ],
        landmarkIndices: [2, 4]
    )

    static let lisbonToMadrid = makeRoute(
        id: "lisbon-to-madrid",
        name: "Atlantic to Castile",
        origin: "Lisbon",
        destination: "Madrid",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 390,
        waypoints: [
            wp("Lisbon", "Portugal", 38.7223, -9.1393),
            wp("Evora", "Portugal", 38.5714, -7.9135),
            wp("Badajoz", "Spain", 38.8794, -6.9707),
            wp("Merida", "Spain", 38.9161, -6.3437),
            wp("Talavera de la Reina", "Spain", 39.9636, -4.8305),
            wp("Madrid", "Spain", 40.4168, -3.7038),
        ],
        landmarkIndices: [2, 4, 5]
    )

    static let lisbonToBarcelona = makeRoute(
        id: "lisbon-to-barcelona",
        name: "Iberian Traverse",
        origin: "Lisbon",
        destination: "Barcelona",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 745,
        waypoints: [
            wp("Lisbon", "Portugal", 38.7223, -9.1393),
            wp("Badajoz", "Spain", 38.8794, -6.9707),
            wp("Madrid", "Spain", 40.4168, -3.7038),
            wp("Zaragoza", "Spain", 41.6488, -0.8891),
            wp("Lleida", "Spain", 41.6176, 0.6200),
            wp("Barcelona", "Spain", 41.3874, 2.1686),
        ],
        landmarkIndices: [1, 2, 3, 5]
    )

    // Cross-country Europe
    static let amsterdamToBerlin = makeRoute(
        id: "amsterdam-to-berlin",
        name: "Lowlands to Capital",
        origin: "Amsterdam",
        destination: "Berlin",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 410,
        waypoints: [
            wp("Amsterdam", "Netherlands", 52.3676, 4.9041),
            wp("Amersfoort", "Netherlands", 52.1561, 5.3878),
            wp("Apeldoorn", "Netherlands", 52.2112, 5.9699),
            wp("Osnabruck", "Germany", 52.2799, 8.0472),
            wp("Hanover", "Germany", 52.3759, 9.7320),
            wp("Magdeburg", "Germany", 52.1205, 11.6276),
            wp("Berlin", "Germany", 52.5200, 13.4050),
        ],
        landmarkIndices: [3, 4, 6]
    )

    static let amsterdamToMunich = makeRoute(
        id: "amsterdam-to-munich",
        name: "Canals to Alps",
        origin: "Amsterdam",
        destination: "Munich",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 520,
        waypoints: [
            wp("Amsterdam", "Netherlands", 52.3676, 4.9041),
            wp("Utrecht", "Netherlands", 52.0907, 5.1214),
            wp("Eindhoven", "Netherlands", 51.4416, 5.4697),
            wp("Cologne", "Germany", 50.9375, 6.9603),
            wp("Frankfurt", "Germany", 50.1109, 8.6821),
            wp("Nuremberg", "Germany", 49.4521, 11.0767),
            wp("Munich", "Germany", 48.1351, 11.5820),
        ],
        landmarkIndices: [3, 4, 6]
    )

    static let londonToIstanbul = makeRoute(
        id: "london-to-istanbul",
        name: "European Crossing",
        origin: "London",
        destination: "Istanbul",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 1770,
        waypoints: [
            wp("London", "United Kingdom", 51.5074, -0.1278),
            wp("Calais", "France", 50.9513, 1.8587),
            wp("Paris", "France", 48.8566, 2.3522),
            wp("Strasbourg", "France", 48.5734, 7.7521),
            wp("Munich", "Germany", 48.1351, 11.5820),
            wp("Vienna", "Austria", 48.2082, 16.3738),
            wp("Budapest", "Hungary", 47.4979, 19.0402),
            wp("Belgrade", "Serbia", 44.7866, 20.4489),
            wp("Sofia", "Bulgaria", 42.6977, 23.3219),
            wp("Istanbul", "Turkey", 41.0082, 28.9784),
        ],
        landmarkIndices: [2, 4, 6, 8, 9]
    )

    // Scandinavia
    static let osloToStockholm = makeRoute(
        id: "oslo-to-stockholm",
        name: "Nordic Link",
        origin: "Oslo",
        destination: "Stockholm",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 325,
        waypoints: [
            wp("Oslo", "Norway", 59.9139, 10.7522),
            wp("Kongsvinger", "Norway", 60.1917, 11.9963),
            wp("Karlstad", "Sweden", 59.3793, 13.5036),
            wp("Orebro", "Sweden", 59.2753, 15.2134),
            wp("Stockholm", "Sweden", 59.3293, 18.0686),
        ],
        landmarkIndices: [2, 3, 4]
    )

    static let copenhagenToStockholm = makeRoute(
        id: "copenhagen-to-stockholm",
        name: "Scandi Coastline",
        origin: "Copenhagen",
        destination: "Stockholm",
        icon: "globe.europe.africa.fill",
        totalDistanceMiles: 405,
        waypoints: [
            wp("Copenhagen", "Denmark", 55.6761, 12.5683),
            wp("Malmo", "Sweden", 55.6050, 13.0038),
            wp("Helsingborg", "Sweden", 56.0465, 12.6945),
            wp("Jonkoping", "Sweden", 57.7826, 14.1618),
            wp("Linkoping", "Sweden", 58.4108, 15.6214),
            wp("Stockholm", "Sweden", 59.3293, 18.0686),
        ],
        landmarkIndices: [1, 3, 5]
    )

    // Japan
    static let tokyoToKyoto = makeRoute(
        id: "tokyo-to-kyoto",
        name: "The Tokaido",
        origin: "Tokyo",
        destination: "Kyoto",
        icon: "globe.asia.australia.fill",
        totalDistanceMiles: 300,
        waypoints: [
            wp("Tokyo", "Japan", 35.6762, 139.6503),
            wp("Yokohama", "Japan", 35.4437, 139.6380),
            wp("Odawara", "Japan", 35.2564, 139.1550),
            wp("Shizuoka", "Japan", 34.9756, 138.3827),
            wp("Hamamatsu", "Japan", 34.7108, 137.7261),
            wp("Nagoya", "Japan", 35.1815, 136.9066),
            wp("Kyoto", "Japan", 35.0116, 135.7681),
        ],
        landmarkIndices: [3, 5, 6]
    )

    static let tokyoToHiroshima = makeRoute(
        id: "tokyo-to-hiroshima",
        name: "Shinkansen Long Haul",
        origin: "Tokyo",
        destination: "Hiroshima",
        icon: "globe.asia.australia.fill",
        totalDistanceMiles: 530,
        waypoints: [
            wp("Tokyo", "Japan", 35.6762, 139.6503),
            wp("Shizuoka", "Japan", 34.9756, 138.3827),
            wp("Nagoya", "Japan", 35.1815, 136.9066),
            wp("Kyoto", "Japan", 35.0116, 135.7681),
            wp("Osaka", "Japan", 34.6937, 135.5023),
            wp("Okayama", "Japan", 34.6551, 133.9195),
            wp("Hiroshima", "Japan", 34.3853, 132.4553),
        ],
        landmarkIndices: [2, 4, 6]
    )

    static let osakaToFukuoka = makeRoute(
        id: "osaka-to-fukuoka",
        name: "Western Japan Arc",
        origin: "Osaka",
        destination: "Fukuoka",
        icon: "globe.asia.australia.fill",
        totalDistanceMiles: 380,
        waypoints: [
            wp("Osaka", "Japan", 34.6937, 135.5023),
            wp("Kobe", "Japan", 34.6901, 135.1955),
            wp("Okayama", "Japan", 34.6551, 133.9195),
            wp("Hiroshima", "Japan", 34.3853, 132.4553),
            wp("Yamaguchi", "Japan", 34.1785, 131.4737),
            wp("Kitakyushu", "Japan", 33.8833, 130.8752),
            wp("Fukuoka", "Japan", 33.5902, 130.4017),
        ],
        landmarkIndices: [2, 3, 6]
    )

    // Australia
    static let sydneyToMelbourne = makeRoute(
        id: "sydney-to-melbourne",
        name: "The Hume",
        origin: "Sydney",
        destination: "Melbourne",
        icon: "globe.asia.australia.fill",
        totalDistanceMiles: 545,
        waypoints: [
            wp("Sydney", "Australia", -33.8688, 151.2093),
            wp("Goulburn", "Australia", -34.7515, 149.7185),
            wp("Canberra", "Australia", -35.2809, 149.1300),
            wp("Albury", "Australia", -36.0805, 146.9161),
            wp("Wangaratta", "Australia", -36.3584, 146.3120),
            wp("Seymour", "Australia", -37.0260, 145.1330),
            wp("Melbourne", "Australia", -37.8136, 144.9631),
        ],
        landmarkIndices: [2, 3, 6]
    )

    static let sydneyToBrisbane = makeRoute(
        id: "sydney-to-brisbane",
        name: "Pacific Highway",
        origin: "Sydney",
        destination: "Brisbane",
        icon: "globe.asia.australia.fill",
        totalDistanceMiles: 570,
        waypoints: [
            wp("Sydney", "Australia", -33.8688, 151.2093),
            wp("Newcastle", "Australia", -32.9283, 151.7817),
            wp("Port Macquarie", "Australia", -31.4308, 152.9089),
            wp("Coffs Harbour", "Australia", -30.2963, 153.1135),
            wp("Byron Bay", "Australia", -28.6474, 153.6020),
            wp("Gold Coast", "Australia", -28.0167, 153.4000),
            wp("Brisbane", "Australia", -27.4698, 153.0251),
        ],
        landmarkIndices: [2, 4, 6]
    )

    // Canada
    static let torontoToMontreal = makeRoute(
        id: "toronto-to-montreal",
        name: "Maple Corridor",
        origin: "Toronto",
        destination: "Montreal",
        icon: "globe.americas.fill",
        totalDistanceMiles: 335,
        waypoints: [
            wp("Toronto", "Canada", 43.6532, -79.3832),
            wp("Kingston", "Canada", 44.2312, -76.4860),
            wp("Brockville", "Canada", 44.5895, -75.6843),
            wp("Cornwall", "Canada", 45.0213, -74.7303),
            wp("Montreal", "Canada", 45.5017, -73.5673),
        ],
        landmarkIndices: [1, 3, 4]
    )

    static let torontoToOttawa = makeRoute(
        id: "toronto-to-ottawa",
        name: "Capital Connect",
        origin: "Toronto",
        destination: "Ottawa",
        icon: "globe.americas.fill",
        totalDistanceMiles: 280,
        waypoints: [
            wp("Toronto", "Canada", 43.6532, -79.3832),
            wp("Peterborough", "Canada", 44.3091, -78.3197),
            wp("Bancroft", "Canada", 45.0544, -77.8570),
            wp("Arnprior", "Canada", 45.4342, -76.3566),
            wp("Ottawa", "Canada", 45.4215, -75.6972),
        ],
        landmarkIndices: [1, 3, 4]
    )

    static let vancouverToBanff = makeRoute(
        id: "vancouver-to-banff",
        name: "Rocky Mountain Run",
        origin: "Vancouver",
        destination: "Banff",
        icon: "globe.americas.fill",
        totalDistanceMiles: 500,
        waypoints: [
            wp("Vancouver", "Canada", 49.2827, -123.1207),
            wp("Hope", "Canada", 49.3794, -121.4417),
            wp("Kamloops", "Canada", 50.6745, -120.3273),
            wp("Salmon Arm", "Canada", 50.6998, -119.2824),
            wp("Revelstoke", "Canada", 50.9981, -118.1957),
            wp("Golden", "Canada", 51.2986, -116.9689),
            wp("Banff", "Canada", 51.1784, -115.5708),
        ],
        landmarkIndices: [2, 4, 6]
    )

    // US short routes where metro Look Around is typically reliable
    static let sanFranciscoToSanJose = makeRoute(
        id: "san-francisco-to-san-jose",
        name: "Bay Sprint",
        origin: "San Francisco",
        destination: "San Jose",
        icon: "mappin.and.ellipse",
        totalDistanceMiles: 48,
        waypoints: [
            wp("San Francisco", "CA", 37.7749, -122.4194),
            wp("Daly City", "CA", 37.6879, -122.4702),
            wp("San Mateo", "CA", 37.5630, -122.3255),
            wp("Palo Alto", "CA", 37.4419, -122.1430),
            wp("Sunnyvale", "CA", 37.3688, -122.0363),
            wp("San Jose", "CA", 37.3382, -121.8863),
        ],
        landmarkIndices: [2, 4, 5]
    )

    static let losAngelesToIrvine = makeRoute(
        id: "los-angeles-to-irvine",
        name: "SoCal Coastline",
        origin: "Los Angeles",
        destination: "Irvine",
        icon: "mappin.and.ellipse",
        totalDistanceMiles: 42,
        waypoints: [
            wp("Los Angeles", "CA", 34.0522, -118.2437),
            wp("Long Beach", "CA", 33.7701, -118.1937),
            wp("Seal Beach", "CA", 33.7414, -118.1048),
            wp("Huntington Beach", "CA", 33.6603, -117.9992),
            wp("Costa Mesa", "CA", 33.6411, -117.9187),
            wp("Irvine", "CA", 33.6846, -117.8265),
        ],
        landmarkIndices: [1, 3, 5]
    )

    static let bostonToProvidence = makeRoute(
        id: "boston-to-providence",
        name: "New England Link",
        origin: "Boston",
        destination: "Providence",
        icon: "mappin.and.ellipse",
        totalDistanceMiles: 50,
        waypoints: [
            wp("Boston", "MA", 42.3601, -71.0589),
            wp("Quincy", "MA", 42.2529, -71.0023),
            wp("Norwood", "MA", 42.1945, -71.1995),
            wp("Foxborough", "MA", 42.0654, -71.2478),
            wp("Attleboro", "MA", 41.9445, -71.2856),
            wp("Providence", "RI", 41.8240, -71.4128),
        ],
        landmarkIndices: [2, 4, 5]
    )

    static let seattleToTacoma = makeRoute(
        id: "seattle-to-tacoma",
        name: "Puget Sound Dash",
        origin: "Seattle",
        destination: "Tacoma",
        icon: "mappin.and.ellipse",
        totalDistanceMiles: 34,
        waypoints: [
            wp("Seattle", "WA", 47.6062, -122.3321),
            wp("Tukwila", "WA", 47.4730, -122.2600),
            wp("Kent", "WA", 47.3809, -122.2348),
            wp("Federal Way", "WA", 47.3223, -122.3126),
            wp("Fife", "WA", 47.2393, -122.3571),
            wp("Tacoma", "WA", 47.2529, -122.4443),
        ],
        landmarkIndices: [2, 4, 5]
    )

    static let washingtonToBaltimore = makeRoute(
        id: "washington-to-baltimore",
        name: "Capital to Harbor",
        origin: "Washington",
        destination: "Baltimore",
        icon: "mappin.and.ellipse",
        totalDistanceMiles: 40,
        waypoints: [
            wp("Washington", "DC", 38.9072, -77.0369),
            wp("College Park", "MD", 38.9897, -76.9378),
            wp("Laurel", "MD", 39.0993, -76.8483),
            wp("Columbia", "MD", 39.2037, -76.8610),
            wp("Elkridge", "MD", 39.2126, -76.7130),
            wp("Baltimore", "MD", 39.2904, -76.6122),
        ],
        landmarkIndices: [2, 4, 5]
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
