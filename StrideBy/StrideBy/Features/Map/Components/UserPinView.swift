//
//  UserPinView.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

struct UserPinView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Pulse ring — radiates outward and fades
            Circle()
                .fill(StrideByTheme.accent.opacity(0.25))
                .frame(width: 44, height: 44)
                .scaleEffect(isPulsing ? 1.8 : 1.0)
                .opacity(isPulsing ? 0 : 0.6)

            // Outer circle
            Circle()
                .fill(StrideByTheme.accent)
                .frame(width: 18, height: 18)
                .shadow(color: StrideByTheme.accent.opacity(0.4), radius: 6, y: 2)

            // Inner dot
            Circle()
                .fill(.white)
                .frame(width: 7, height: 7)
        }
        .onAppear {
            withAnimation(
                .easeOut(duration: 1.8)
                .repeatForever(autoreverses: false)
            ) {
                isPulsing = true
            }
        }
    }
}

#Preview {
    UserPinView()
        .frame(width: 100, height: 100)
        .background(.gray.opacity(0.1))
}
