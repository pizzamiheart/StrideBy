//
//  StrideByTheme.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

enum StrideByTheme {

    // MARK: - Colors

    /// Primary accent — deep evergreen
    static let accent = Color(red: 0.12, green: 0.48, blue: 0.32)

    /// Soft glow for route line halos and subtle fills
    static let accentGlow = accent.opacity(0.3)

    static let routeRemaining = Color.gray.opacity(0.3)

    // MARK: - Animation

    static let defaultSpring = Animation.spring(response: 0.35, dampingFraction: 0.85)

    // MARK: - Layout

    static let cardCornerRadius: CGFloat = 22
    static let routeLineWidth: CGFloat = 5
}
