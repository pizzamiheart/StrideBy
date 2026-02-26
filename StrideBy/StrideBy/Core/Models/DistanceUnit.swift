//
//  DistanceUnit.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/25/26.
//

import Foundation

enum DistanceUnit: String, CaseIterable, Identifiable {
    case miles
    case kilometers

    var id: String { rawValue }

    var abbreviation: String {
        switch self {
        case .miles: return "mi"
        case .kilometers: return "km"
        }
    }

    var displayName: String {
        switch self {
        case .miles: return "Miles"
        case .kilometers: return "Kilometers"
        }
    }

    func convert(miles: Double) -> Double {
        switch self {
        case .miles:
            return miles
        case .kilometers:
            return miles * 1.60934
        }
    }
}
