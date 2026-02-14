//
//  RoutesScreen.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

struct RoutesScreen: View {
    @Environment(RouteManager.self) private var routeManager
    @Environment(RunProgressManager.self) private var progressManager

    @State private var routeToConfirm: RunRoute?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(RunRoute.allRoutes) { route in
                        RouteRow(
                            route: route,
                            isActive: route.id == routeManager.activeRouteKey,
                            isCompleted: routeManager.isCompleted(routeKey: route.id)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Don't re-select the already active route
                            if route.id != routeManager.activeRouteKey {
                                routeToConfirm = route
                            }
                        }
                    }
                } header: {
                    Text("Available Routes")
                }
            }
            .navigationTitle("Explore")
            .confirmationDialog(
                "Start \(routeToConfirm?.name ?? "route")?",
                isPresented: Binding(
                    get: { routeToConfirm != nil },
                    set: { if !$0 { routeToConfirm = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let route = routeToConfirm {
                    Button("Start \(route.origin) → \(route.destination)") {
                        routeManager.startRoute(route, currentTotalMiles: progressManager.totalMiles)
                        routeToConfirm = nil
                    }
                    Button("Cancel", role: .cancel) {
                        routeToConfirm = nil
                    }
                }
            } message: {
                if let route = routeToConfirm {
                    Text("You'll run \(Int(route.totalDistanceMiles)) miles on this route. Only new runs will count toward your progress.")
                }
            }
        }
    }
}

// MARK: - Route Row

private struct RouteRow: View {
    let route: RunRoute
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: route.icon)
                .font(.title3)
                .foregroundStyle(isActive ? StrideByTheme.accent : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(route.origin) → \(route.destination)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text("\(Int(route.totalDistanceMiles)) mi")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isActive {
                        Text("Active")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(StrideByTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(StrideByTheme.accent.opacity(0.12), in: Capsule())
                    }
                }
            }

            Spacer()

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(StrideByTheme.accent)
            } else if isActive {
                Image(systemName: "figure.run")
                    .foregroundStyle(StrideByTheme.accent)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RoutesScreen()
        .environment(RouteManager())
        .environment(RunProgressManager())
}
