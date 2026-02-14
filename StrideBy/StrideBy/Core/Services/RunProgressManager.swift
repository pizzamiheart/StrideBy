//
//  RunProgressManager.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/13/26.
//

import Foundation
import Observation

/// Fetches running activities from Strava and tracks cumulative mileage.
@Observable
final class RunProgressManager {

    // MARK: - Public State

    var totalMiles: Double = 0
    var runCount: Int = 0
    var isLoading = false
    var hasSynced = false

    // MARK: - Init

    init() {
        // Load cached values so the UI has data immediately
        totalMiles = UserDefaults.standard.double(forKey: "strideby_total_miles")
        runCount = UserDefaults.standard.integer(forKey: "strideby_run_count")
        hasSynced = UserDefaults.standard.bool(forKey: "strideby_has_synced")
    }

    // MARK: - Sync

    /// Fetches all running activities from Strava and updates the total miles.
    func sync(using auth: StravaAuthService) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await auth.validAccessToken()
            var allMiles: Double = 0
            var count = 0
            var page = 1

            // Paginate through all activities (200 per page max)
            while true {
                let activities = try await fetchPage(token: token, page: page)
                if activities.isEmpty { break }

                // Only count runs (outdoor + treadmill)
                let runs = activities.filter {
                    $0.type == "Run" || $0.type == "VirtualRun"
                }
                allMiles += runs.reduce(0) { $0 + $1.distanceMiles }
                count += runs.count

                // If we got fewer than 200, we've hit the last page
                if activities.count < 200 { break }
                page += 1

                // Small delay between pages to respect Strava rate limits
                try await Task.sleep(for: .milliseconds(300))
            }

            totalMiles = allMiles
            runCount = count
            hasSynced = true

            // Cache locally
            UserDefaults.standard.set(totalMiles, forKey: "strideby_total_miles")
            UserDefaults.standard.set(runCount, forKey: "strideby_run_count")
            UserDefaults.standard.set(true, forKey: "strideby_has_synced")
        } catch {
            // If sync fails, cached data remains visible
        }
    }

    // MARK: - Debug

    #if DEBUG
    /// Adds simulated miles for testing. Only available in debug builds.
    func addDebugMiles(_ miles: Double) {
        totalMiles += miles
        runCount += 1
        UserDefaults.standard.set(totalMiles, forKey: "strideby_total_miles")
        UserDefaults.standard.set(runCount, forKey: "strideby_run_count")
    }

    /// Resets all progress to zero. Only available in debug builds.
    func resetDebugProgress() {
        totalMiles = 0
        runCount = 0
        hasSynced = false
        UserDefaults.standard.set(0.0, forKey: "strideby_total_miles")
        UserDefaults.standard.set(0, forKey: "strideby_run_count")
        UserDefaults.standard.set(false, forKey: "strideby_has_synced")
    }
    #endif

    // MARK: - Private

    private func fetchPage(token: String, page: Int) async throws -> [StravaActivity] {
        var components = URLComponents(string: "https://www.strava.com/api/v3/athlete/activities")!
        components.queryItems = [
            URLQueryItem(name: "per_page", value: "200"),
            URLQueryItem(name: "page", value: String(page)),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([StravaActivity].self, from: data)
    }
}
