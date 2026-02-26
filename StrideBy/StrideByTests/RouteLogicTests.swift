//
//  RouteLogicTests.swift
//  StrideByTests
//
//  Created by Andrew Ginn on 2/25/26.
//

import CoreLocation
import Foundation
import Testing
@testable import StrideBy

@Suite("Route Logic", .serialized)
struct RouteLogicTests {

    @Test("coordinateAt returns endpoints at 0 and total distance")
    func coordinateAtEndpoints() {
        let route = RunRoute.parisCityLoop

        let start = route.coordinateAt(miles: 0)
        let end = route.coordinateAt(miles: route.totalDistanceMiles)

        #expect(start.latitude == route.coordinates.first?.latitude)
        #expect(start.longitude == route.coordinates.first?.longitude)
        #expect(end.latitude == route.coordinates.last?.latitude)
        #expect(end.longitude == route.coordinates.last?.longitude)
    }

    @Test("completed and remaining coordinates preserve route endpoints")
    func splitCoordinatesPreserveEndpoints() {
        let route = RunRoute.parisCityLoop
        let completed = route.completedCoordinates(miles: 5)
        let remaining = route.remainingCoordinates(miles: 5)

        #expect(completed.first?.latitude == route.coordinates.first?.latitude)
        #expect(completed.first?.longitude == route.coordinates.first?.longitude)
        #expect(remaining.last?.latitude == route.coordinates.last?.latitude)
        #expect(remaining.last?.longitude == route.coordinates.last?.longitude)
        #expect(completed.count > 1)
        #expect(remaining.count > 1)
    }

    @Test("nearestLocationName returns origin for first few miles")
    func nearestLocationStartsAtOrigin() {
        let route = RunRoute.parisCityLoop
        #expect(route.nearestLocationName(atMiles: 5) == route.origin)
    }
}

@Suite("Route Manager", .serialized)
struct RouteManagerTests {
    private let defaults = UserDefaults.standard
    private let activeRouteKey = "strideby_active_route"
    private let startingMilesKey = "strideby_starting_miles"
    private let completedRoutesKey = "strideby_completed_routes"

    @Test("defaults to Paris route at zero starting miles")
    func defaultState() {
        clearRouteManagerDefaults()
        let manager = RouteManager()

        #expect(manager.activeRouteKey == "paris-city-loop")
        #expect(manager.startingMiles == 0)
        #expect(manager.completedRouteKeys.isEmpty)
    }

    @Test("progress miles never goes below zero")
    func progressClampsToZero() {
        clearRouteManagerDefaults()
        defaults.set("paris-city-loop", forKey: activeRouteKey)
        defaults.set(300.0, forKey: startingMilesKey)
        let manager = RouteManager()

        #expect(manager.progressMiles(totalMiles: 250) == 0)
    }

    @Test("starting a new route records completed current route when finished")
    func startingRouteMarksCompletion() {
        clearRouteManagerDefaults()
        defaults.set("paris-city-loop", forKey: activeRouteKey)
        defaults.set(0.0, forKey: startingMilesKey)
        let manager = RouteManager()

        manager.startRoute(.londonCityLoop, currentTotalMiles: 80)

        #expect(manager.completedRouteKeys.contains("paris-city-loop"))
        #expect(manager.activeRouteKey == "london-city-loop")
        #expect(manager.startingMiles == 80)
    }

    @Test("isRouteComplete becomes true once threshold is crossed")
    func completionThreshold() {
        clearRouteManagerDefaults()
        defaults.set("tokyo-to-kyoto", forKey: activeRouteKey)
        defaults.set(10.0, forKey: startingMilesKey)
        let manager = RouteManager()
        let targetMiles = 10 + RunRoute.tokyoToKyoto.totalDistanceMiles + 1

        #expect(manager.isRouteComplete(totalMiles: targetMiles))
    }

    private func clearRouteManagerDefaults() {
        defaults.removeObject(forKey: activeRouteKey)
        defaults.removeObject(forKey: startingMilesKey)
        defaults.removeObject(forKey: completedRoutesKey)
    }
}
