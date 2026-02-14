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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(stravaAuth)
                .environment(progressManager)
                .environment(routeManager)
                .environment(routeGeometryManager)
        }
    }
}
