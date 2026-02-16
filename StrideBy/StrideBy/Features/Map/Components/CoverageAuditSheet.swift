//
//  CoverageAuditSheet.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/15/26.
//

#if DEBUG

import SwiftUI

/// Debug sheet for testing Look Around coverage across an entire route at once.
///
/// Walks the route at configurable mile intervals, tests a single
/// `MKLookAroundSceneRequest` at each point, and shows color-coded results.
struct CoverageAuditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RouteGeometryManager.self) private var geometryManager

    @State private var auditor = CoverageAuditTool()
    @State private var selectedRoute: RunRoute = .parisCityLoop
    @State private var intervalMiles: Double = 50

    private let intervalOptions: [Double] = [25, 50, 100]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status banner
                statusBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                List {
                    // Configuration
                    Section("Configuration") {
                        Picker("Route", selection: $selectedRoute) {
                            ForEach(RunRoute.allRoutes) { route in
                                Text(route.name).tag(route)
                            }
                        }

                        Picker("Interval", selection: $intervalMiles) {
                            ForEach(intervalOptions, id: \.self) { miles in
                                Text("\(Int(miles)) mi").tag(miles)
                            }
                        }
                        .pickerStyle(.segmented)

                        let pointCount = Int(selectedRoute.totalDistanceMiles / intervalMiles) + 1
                        let estimatedSeconds = pointCount * 2
                        Text("\(pointCount) test points — ~\(estimatedSeconds)s estimated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Actions
                    Section {
                        Button {
                            let route = selectedRoute
                            let coords = geometryManager.coordinates(for: route)
                            Task {
                                await auditor.audit(
                                    route: route,
                                    coordinates: coords,
                                    intervalMiles: intervalMiles
                                )
                            }
                        } label: {
                            Label("Start Audit", systemImage: "play.fill")
                        }
                        .disabled(auditor.state.isRunning)

                        if auditor.state.isRunning {
                            Button(role: .destructive) {
                                auditor.cancel()
                            } label: {
                                Label("Cancel", systemImage: "stop.fill")
                            }
                        }
                    }

                    // Results
                    if !auditor.results.isEmpty {
                        Section("Results") {
                            ForEach(auditor.results) { result in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(result.hasCoverage ? .green : .red)
                                        .frame(width: 10, height: 10)

                                    Text("Mile \(Int(result.mile))")
                                        .font(.system(.caption, design: .monospaced))
                                        .frame(width: 70, alignment: .leading)

                                    Text(result.nearestPOIName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)

                                    Spacer()

                                    Text(result.hasCoverage ? "YES" : "NO")
                                        .font(.system(.caption2, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundStyle(result.hasCoverage ? .green : .red)
                                }
                            }
                        }
                    }

                    // Log
                    Section("Log") {
                        if auditor.log.isEmpty {
                            Text("No activity yet. Configure and tap Start.")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        } else {
                            ForEach(Array(auditor.log.enumerated()), id: \.offset) { _, entry in
                                Text(entry)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Coverage Audit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Status Banner

    @ViewBuilder
    private var statusBanner: some View {
        switch auditor.state {
        case .idle:
            EmptyView()

        case .running(let routeId, let current, let total):
            HStack(spacing: 8) {
                ProgressView(value: Double(current), total: Double(total))
                    .frame(width: 60)
                Text("\(routeId): \(current)/\(total)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

        case .finished(let routeId, let covered, let total):
            let pct = total > 0 ? Int(Double(covered) / Double(total) * 100) : 0
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(routeId): \(covered)/\(total) have coverage (\(pct)%)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

        case .cancelled:
            HStack(spacing: 8) {
                Image(systemName: "stop.circle.fill")
                    .foregroundStyle(.orange)
                Text("Audit cancelled")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - RunRoute + Hashable (for Picker)

extension RunRoute: Hashable {
    static func == (lhs: RunRoute, rhs: RunRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    CoverageAuditSheet()
        .environment(RouteGeometryManager())
}

#endif
