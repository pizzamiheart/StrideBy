//
//  RouteManager.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/13/26.
//

import Foundation
import Observation

/// Manages which route the user is currently running and tracks starting mileage
/// so that only new miles (after selecting a route) count toward it.
///
/// **First route** starts with `startingMiles = 0` so lifetime miles count.
/// **Subsequent routes** start from the user's current total miles when selected,
/// so only new runs count toward the new route.
@Observable
final class RouteManager {
    private static let defaultRouteID = "paris-city-loop"

    // MARK: - Persisted State

    /// The route ID key for the active route (e.g. "paris-city-loop").
    var activeRouteKey: String {
        didSet { UserDefaults.standard.set(activeRouteKey, forKey: Keys.activeRoute) }
    }

    /// The user's total lifetime miles at the moment they started this route.
    /// Progress on the route = totalMiles - startingMiles.
    var startingMiles: Double {
        didSet { UserDefaults.standard.set(startingMiles, forKey: Keys.startingMiles) }
    }

    /// Keys for routes that have been completed.
    var completedRouteKeys: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(completedRouteKeys), forKey: Keys.completedRoutes)
        }
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        // Default to the first catalog route with startingMiles = 0 on first launch
        if defaults.string(forKey: Keys.activeRoute) == nil {
            defaults.set(Self.defaultRouteID, forKey: Keys.activeRoute)
            defaults.set(0.0, forKey: Keys.startingMiles)
        }

        let persistedRouteKey = defaults.string(forKey: Keys.activeRoute) ?? Self.defaultRouteID
        self.activeRouteKey = RunRoute.route(forKey: persistedRouteKey) != nil
            ? persistedRouteKey
            : Self.defaultRouteID
        self.startingMiles = defaults.double(forKey: Keys.startingMiles)
        self.completedRouteKeys = Set(
            (defaults.stringArray(forKey: Keys.completedRoutes) ?? [])
                .filter { RunRoute.route(forKey: $0) != nil }
        )

        if activeRouteKey != persistedRouteKey {
            defaults.set(activeRouteKey, forKey: Keys.activeRoute)
        }
        defaults.set(Array(completedRouteKeys), forKey: Keys.completedRoutes)
    }

    // MARK: - Computed

    /// The currently active RunRoute, if it exists.
    var activeRoute: RunRoute? {
        RunRoute.route(forKey: activeRouteKey)
    }

    /// How many miles the user has progressed on the current route.
    /// This is always >= 0 and capped at the route's total distance.
    func progressMiles(totalMiles: Double) -> Double {
        max(0, totalMiles - startingMiles)
    }

    /// Whether the current route is complete given the user's total lifetime miles.
    func isRouteComplete(totalMiles: Double) -> Bool {
        guard let route = activeRoute else { return false }
        return progressMiles(totalMiles: totalMiles) >= route.totalDistanceMiles
    }

    // MARK: - Actions

    /// Start a new route. Sets the starting miles to the user's current total
    /// so that only future runs count toward this route.
    func startRoute(_ route: RunRoute, currentTotalMiles: Double) {
        // Mark the current route as complete if it was finished
        if let current = activeRoute, isRouteComplete(totalMiles: currentTotalMiles) {
            completedRouteKeys.insert(current.id)
        }

        activeRouteKey = route.id
        startingMiles = currentTotalMiles
    }

    /// Mark the active route as completed (called when completion is detected).
    func markActiveRouteComplete() {
        completedRouteKeys.insert(activeRouteKey)
    }

    /// Whether a specific route has been completed.
    func isCompleted(routeKey: String) -> Bool {
        completedRouteKeys.contains(routeKey)
    }

    // MARK: - Debug

    #if DEBUG
    /// Resets progress on the active route so you can re-test it from 0 miles.
    /// Clears completed checkmarks but does NOT touch lifetime miles or run count.
    func resetDebugRouteProgress(currentTotalMiles: Double) {
        completedRouteKeys = []
        startingMiles = currentTotalMiles
    }
    #endif

    // MARK: - Keys

    private enum Keys {
        static let activeRoute = "strideby_active_route"
        static let startingMiles = "strideby_starting_miles"
        static let completedRoutes = "strideby_completed_routes"
    }
}
