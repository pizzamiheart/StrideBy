//
//  CoverageAuditTool.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/15/26.
//

#if DEBUG

import CoreLocation
import Foundation
import MapKit
import Observation

// MARK: - Audit Result

struct CoverageAuditResult: Identifiable {
    let id = UUID()
    let mile: Double
    let coordinate: CLLocationCoordinate2D
    let hasCoverage: Bool
    let nearestPOIName: String
}

// MARK: - Audit State

enum AuditState: Equatable {
    case idle
    case running(routeId: String, current: Int, total: Int)
    case finished(routeId: String, covered: Int, total: Int)
    case cancelled

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

// MARK: - Coverage Audit Tool

/// DEBUG-only tool that walks a route at N-mile intervals, testing each point
/// for Look Around coverage with a single `MKLookAroundSceneRequest`.
///
/// Uses a 2-second delay between requests to stay well under the 50/min MapKit limit.
/// NYC→LA at 50mi intervals = ~56 points × 1 request × 2s = ~2 minutes.
@Observable
final class CoverageAuditTool {
    private(set) var state: AuditState = .idle
    private(set) var results: [CoverageAuditResult] = []
    private(set) var log: [String] = []

    private var isCancelled = false

    /// Delay between requests to respect the 50/min MapKit limit.
    private let interRequestDelay: TimeInterval = 2.0

    // MARK: - Audit

    @MainActor
    func audit(route: RunRoute, coordinates: [CLLocationCoordinate2D], intervalMiles: Double) async {
        isCancelled = false
        results = []
        log = []

        let totalMiles = route.totalDistanceMiles
        var milesToTest: [Double] = []
        var mile: Double = 0
        while mile <= totalMiles {
            milesToTest.append(mile)
            mile += intervalMiles
        }
        // Always include the final mile
        if let last = milesToTest.last, last < totalMiles {
            milesToTest.append(totalMiles)
        }

        let total = milesToTest.count
        appendLog("Starting audit: \(route.name) (\(route.id))")
        appendLog("  \(total) points at \(Int(intervalMiles))mi intervals")
        appendLog("  Estimated time: ~\(total * Int(interRequestDelay))s")

        for (index, testMile) in milesToTest.enumerated() {
            guard !isCancelled else {
                state = .cancelled
                appendLog("Audit cancelled at point \(index + 1)/\(total)")
                return
            }

            state = .running(routeId: route.id, current: index + 1, total: total)

            let coord = route.coordinateAt(miles: testMile, using: coordinates)
            let nearestPOI = route.nearestPOI(atMiles: testMile)
            let poiName = nearestPOI.map { "\($0.name), \($0.state)" } ?? "—"

            let hasCoverage = await checkCoverage(at: coord)

            let result = CoverageAuditResult(
                mile: testMile,
                coordinate: coord,
                hasCoverage: hasCoverage,
                nearestPOIName: poiName
            )
            results.append(result)

            let status = hasCoverage ? "YES" : "NO"
            appendLog("  Mile \(Int(testMile)): \(status) — near \(poiName)")

            // Delay between requests (skip after last)
            if index < total - 1 {
                try? await Task.sleep(for: .seconds(interRequestDelay))
            }
        }

        let covered = results.filter(\.hasCoverage).count
        state = .finished(routeId: route.id, covered: covered, total: total)
        appendLog("Done: \(covered)/\(total) positions have coverage (\(percentString(covered, total)))")
    }

    func cancel() {
        isCancelled = true
    }

    // MARK: - Helpers

    private func checkCoverage(at coordinate: CLLocationCoordinate2D) async -> Bool {
        do {
            let request = MKLookAroundSceneRequest(coordinate: coordinate)
            let scene = try await request.scene
            return scene != nil
        } catch {
            return false
        }
    }

    private func percentString(_ covered: Int, _ total: Int) -> String {
        guard total > 0 else { return "0%" }
        let pct = Int(Double(covered) / Double(total) * 100)
        return "\(pct)%"
    }

    private func appendLog(_ message: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        log.append("[\(f.string(from: Date()))] \(message)")
    }
}

#endif
