//
//  SocialScreen.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

struct SocialScreen: View {
    private var inviteURL: URL {
        var components = URLComponents()
        components.scheme = "strideby"
        components.host = "join"
        return components.url ?? URL(string: "strideby://join")!
    }

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("No Friends Yet", systemImage: "person.2")
            } description: {
                Text("Invite friends to join StrideBy and start your own route.")
            } actions: {
                ShareLink(
                    item: inviteURL,
                    message: Text("Join me on StrideBy and start your own route.")
                ) {
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
