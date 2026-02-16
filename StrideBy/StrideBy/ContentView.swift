//
//  ContentView.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab: MainTab = .map

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
        TabView(selection: $selectedTab) {
            MapScreen()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(MainTab.map)

            RoutesScreen(onRouteStarted: {
                withAnimation(StrideByTheme.defaultSpring) {
                    selectedTab = .map
                }
            })
            .tabItem {
                Label("Explore", systemImage: "globe.americas.fill")
            }
            .tag(MainTab.explore)

            SocialScreen()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
                .tag(MainTab.friends)

            ProfileScreen()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
                .tag(MainTab.profile)
        }
        .tint(StrideByTheme.accent)
    }
}

private enum MainTab: Hashable {
    case map
    case explore
    case friends
    case profile
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
