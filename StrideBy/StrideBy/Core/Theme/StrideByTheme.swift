//
//  StrideByTheme.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import SwiftUI

enum StrideByTheme {

    // MARK: - Colors

    static let accent = Color.accentColor
    static let routeRemaining = Color.gray.opacity(0.3)

    // MARK: - Animation

    static let defaultSpring = Animation.spring(response: 0.35, dampingFraction: 0.85)

    // MARK: - Layout

    static let cardCornerRadius: CGFloat = 20
    static let routeLineWidth: CGFloat = 5
}
