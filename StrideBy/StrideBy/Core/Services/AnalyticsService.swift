//
//  AnalyticsService.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/17/26.
//

import Foundation
import Observation

struct AnalyticsEvent: Codable, Identifiable {
    let id: UUID
    let name: String
    let timestamp: Date
    let properties: [String: String]
}

@Observable
final class AnalyticsService {
    private enum Keys {
        static let events = "strideby_analytics_events"
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let maxEvents = 500

    var recentEvents: [AnalyticsEvent] = []

    init() {
        loadPersistedEvents()
    }

    func track(_ name: String, properties: [String: String] = [:]) {
        let event = AnalyticsEvent(
            id: UUID(),
            name: name,
            timestamp: Date(),
            properties: properties
        )

        recentEvents.append(event)
        if recentEvents.count > maxEvents {
            recentEvents = Array(recentEvents.suffix(maxEvents))
        }
        persistEvents()

        #if DEBUG
        print("Analytics[\(name)] \(properties)")
        #endif
    }

    private func loadPersistedEvents() {
        guard let data = UserDefaults.standard.data(forKey: Keys.events) else { return }
        guard let decoded = try? decoder.decode([AnalyticsEvent].self, from: data) else { return }
        recentEvents = decoded
    }

    private func persistEvents() {
        guard let data = try? encoder.encode(recentEvents) else { return }
        UserDefaults.standard.set(data, forKey: Keys.events)
    }
}
