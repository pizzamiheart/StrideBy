//
//  StrideByApp.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

@main
struct StrideByApp: App {
    @State private var stravaAuth = StravaAuthService()
    @State private var progressManager = RunProgressManager()
    @State private var routeManager = RouteManager()
    @State private var routeGeometryManager = RouteGeometryManager()
    @State private var analytics = AnalyticsService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(stravaAuth)
                .environment(progressManager)
                .environment(routeManager)
                .environment(routeGeometryManager)
                .environment(analytics)
                .onOpenURL { url in
                    analytics.track("link_opened", properties: [
                        "url": url.absoluteString
                    ])
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "strideby", url.host == "join" else { return }

        analytics.track("join_link_opened", properties: [:])
    }
}
