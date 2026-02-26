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
    var lastSyncGainMiles: Double = 0
    var latestRunMiles: Double = 0
    var syncRevision: Int = 0
    var errorMessage: String?

    // MARK: - Private State

    private var knownRunIDs: Set<Int> = []
    private var lastSyncedAtEpochSeconds: Int = 0

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        totalMiles = defaults.double(forKey: Keys.totalMiles)
        runCount = defaults.integer(forKey: Keys.runCount)
        hasSynced = defaults.bool(forKey: Keys.hasSynced)
        latestRunMiles = defaults.double(forKey: Keys.latestRunMiles)
        lastSyncedAtEpochSeconds = defaults.integer(forKey: Keys.lastSyncedAt)
        knownRunIDs = Set(defaults.array(forKey: Keys.knownRunIDs) as? [Int] ?? [])
    }

    // MARK: - Sync

    /// Syncs Strava activities into cached totals.
    ///
    /// First sync does a full backfill.
    /// Subsequent syncs use an incremental `after` cursor plus activity-ID dedupe.
    func sync(using auth: StravaAuthService) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let totalBeforeSync = totalMiles
            let hadSyncedBefore = hasSynced
            let token = try await auth.validAccessToken()

            if hasSynced, !knownRunIDs.isEmpty {
                try await performIncrementalSync(token: token)
            } else {
                try await performFullSync(token: token)
            }

            // Keep "Last Run" accurate even when no brand-new runs are found in the
            // incremental window (e.g. after app updates or stale local cache state).
            if let recentMiles = await safeMostRecentRunMiles(token: token) {
                latestRunMiles = recentMiles
            }

            hasSynced = true
            lastSyncedAtEpochSeconds = Int(Date().timeIntervalSince1970)
            lastSyncGainMiles = hadSyncedBefore
                ? max(0, totalMiles - totalBeforeSync)
                : 0
            syncRevision += 1
            persist()
        } catch {
            lastSyncGainMiles = 0
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Debug

    #if DEBUG
    /// Adds simulated miles for testing. Only available in debug builds.
    func addDebugMiles(_ miles: Double) {
        totalMiles += miles
        runCount += 1
        latestRunMiles = max(0, miles)
        persist()
    }

    /// Simulates a new sync result with additional miles and emits a sync revision
    /// so post-sync UI (celebrations, etc.) can be tested instantly.
    func simulateDebugSyncGain(_ miles: Double) {
        let gain = max(0, miles)
        totalMiles += gain
        runCount += 1
        hasSynced = true
        lastSyncGainMiles = gain
        latestRunMiles = gain
        syncRevision += 1
        persist()
    }

    /// Resets all progress to zero. Only available in debug builds.
    func resetDebugProgress() {
        totalMiles = 0
        runCount = 0
        hasSynced = false
        lastSyncGainMiles = 0
        latestRunMiles = 0
        lastSyncedAtEpochSeconds = 0
        knownRunIDs = []
        persist()
    }
    #endif

    // MARK: - Private

    private func performFullSync(token: String) async throws {
        var allMiles: Double = 0
        var allRuns: [StravaActivity] = []
        var page = 1

        while true {
            let activities = try await fetchPage(token: token, page: page, afterEpochSeconds: nil)
            if activities.isEmpty { break }

            let runs = runActivities(from: activities)
            allMiles += runs.reduce(0) { $0 + $1.distanceMiles }
            allRuns.append(contentsOf: runs)

            if activities.count < 200 { break }
            page += 1
            try await Task.sleep(for: .milliseconds(300))
        }

        totalMiles = allMiles
        runCount = allRuns.count
        latestRunMiles = mostRecentRunMiles(in: allRuns) ?? 0
        knownRunIDs = Set(allRuns.map(\.id))
    }

    private func performIncrementalSync(token: String) async throws {
        let cursor = max(0, lastSyncedAtEpochSeconds - 7200)
        var page = 1
        var newRuns: [StravaActivity] = []

        while true {
            let activities = try await fetchPage(token: token, page: page, afterEpochSeconds: cursor)
            if activities.isEmpty { break }

            let runs = runActivities(from: activities).filter { !knownRunIDs.contains($0.id) }
            newRuns.append(contentsOf: runs)

            if activities.count < 200 { break }
            page += 1
            try await Task.sleep(for: .milliseconds(300))
        }

        if !newRuns.isEmpty {
            totalMiles += newRuns.reduce(0) { $0 + $1.distanceMiles }
            runCount += newRuns.count
            latestRunMiles = mostRecentRunMiles(in: newRuns) ?? latestRunMiles
            for run in newRuns {
                knownRunIDs.insert(run.id)
            }
        }
    }

    private func fetchMostRecentRunMiles(token: String) async throws -> Double? {
        let activities = try await fetchPage(token: token, page: 1, afterEpochSeconds: nil)
        return runActivities(from: activities).first?.distanceMiles
    }

    private func safeMostRecentRunMiles(token: String) async -> Double? {
        do {
            return try await fetchMostRecentRunMiles(token: token)
        } catch {
            return nil
        }
    }

    private func mostRecentRunMiles(in runs: [StravaActivity]) -> Double? {
        runs.max(by: { $0.startDate < $1.startDate })?.distanceMiles
    }

    private func runActivities(from activities: [StravaActivity]) -> [StravaActivity] {
        activities.filter { $0.type == "Run" || $0.type == "VirtualRun" }
    }

    private func fetchPage(
        token: String,
        page: Int,
        afterEpochSeconds: Int?
    ) async throws -> [StravaActivity] {
        var components = URLComponents(string: "https://www.strava.com/api/v3/athlete/activities")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "per_page", value: "200"),
            URLQueryItem(name: "page", value: String(page)),
        ]
        if let afterEpochSeconds {
            queryItems.append(URLQueryItem(name: "after", value: String(afterEpochSeconds)))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return try await performRequest(request)
    }

    private func performRequest(_ request: URLRequest) async throws -> [StravaActivity] {
        do {
            let (data, rawResponse) = try await URLSession.shared.data(for: request)
            guard let response = rawResponse as? HTTPURLResponse else {
                throw StravaError.invalidResponse
            }

            switch response.statusCode {
            case 200...299:
                return try JSONDecoder().decode([StravaActivity].self, from: data)
            case 400...499:
                if response.statusCode == 401 {
                    throw StravaError.unauthorized
                }
                if response.statusCode == 429 {
                    throw StravaError.rateLimited
                }
                let payload = try? JSONDecoder().decode(StravaAPIErrorResponse.self, from: data)
                throw StravaError.apiError(payload?.message ?? "Could not sync Strava activities.")
            default:
                throw StravaError.apiError("Strava is unavailable right now. Please try again.")
            }
        } catch let error as StravaError {
            throw error
        } catch {
            throw StravaError.networkError(error)
        }
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(totalMiles, forKey: Keys.totalMiles)
        defaults.set(runCount, forKey: Keys.runCount)
        defaults.set(hasSynced, forKey: Keys.hasSynced)
        defaults.set(latestRunMiles, forKey: Keys.latestRunMiles)
        defaults.set(lastSyncedAtEpochSeconds, forKey: Keys.lastSyncedAt)
        defaults.set(Array(knownRunIDs), forKey: Keys.knownRunIDs)
    }

    private enum Keys {
        static let totalMiles = "strideby_total_miles"
        static let runCount = "strideby_run_count"
        static let hasSynced = "strideby_has_synced"
        static let latestRunMiles = "strideby_latest_run_miles"
        static let lastSyncedAt = "strideby_last_synced_at"
        static let knownRunIDs = "strideby_known_run_ids"
    }
}
