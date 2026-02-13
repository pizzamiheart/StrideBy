//
//  ContentView.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            mainApp
        } else {
            OnboardingView {
                withAnimation(StrideByTheme.defaultSpring) {
                    hasCompletedOnboarding = true
                }
            }
        }
    }

    private var mainApp: some View {
        TabView {
            Tab("Map", systemImage: "map.fill") {
                MapScreen()
            }

            Tab("Explore", systemImage: "globe.americas.fill") {
                RoutesScreen()
            }

            Tab("Friends", systemImage: "person.2.fill") {
                SocialScreen()
            }

            Tab("Profile", systemImage: "person.circle.fill") {
                ProfileScreen()
            }
        }
        .tint(StrideByTheme.accent)
    }
}

#Preview("Onboarding") {
    ContentView()
}

#Preview("Main App") {
    ContentView()
        .onAppear {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
}
