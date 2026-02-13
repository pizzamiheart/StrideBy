//
//  SocialScreen.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

struct SocialScreen: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("No Friends Yet", systemImage: "person.2")
            } description: {
                Text("Invite friends to join your route and watch each other's progress in real time.")
            } actions: {
                Button {
                    // TODO: Share invite link
                } label: {
                    Text("Invite Friends")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .tint(StrideByTheme.accent)
            }
            .navigationTitle("Friends")
        }
    }
}

#Preview {
    SocialScreen()
}
