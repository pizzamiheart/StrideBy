//
//  RoutesScreen.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

struct RoutesScreen: View {
    private let comingSoonRoutes = [
        ("New York → Los Angeles", "2,790 mi", "flag.fill"),
        ("London → Istanbul", "1,770 mi", "globe.europe.africa.fill"),
        ("Tokyo → Kyoto", "300 mi", "globe.asia.australia.fill"),
        ("Reykjavik → Vik", "110 mi", "snowflake"),
        ("Sydney → Melbourne", "545 mi", "globe.americas.fill"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(comingSoonRoutes, id: \.0) { route in
                        HStack(spacing: 14) {
                            Image(systemName: route.2)
                                .font(.title3)
                                .foregroundStyle(StrideByTheme.accent)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(route.0)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text(route.1)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.quaternary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Available Routes")
                }
            }
            .navigationTitle("Explore")
        }
    }
}

#Preview {
    RoutesScreen()
}
