//
//  StravaModels.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import Foundation

// MARK: - OAuth Token Response

struct StravaTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int
    let athlete: StravaAthlete

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case athlete
    }
}

// MARK: - Token Refresh Response (no athlete field)

struct StravaRefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }
}

// MARK: - Athlete

struct StravaAthlete: Codable {
    let id: Int
    let firstname: String
    let lastname: String
    let profile: String
}

// MARK: - Activity (for future use pulling runs)

struct StravaActivity: Codable {
    let id: Int
    let name: String
    let distance: Double        // meters
    let movingTime: Int         // seconds
    let type: String
    let startDate: String

    enum CodingKeys: String, CodingKey {
        case id, name, distance, type
        case movingTime = "moving_time"
        case startDate = "start_date"
    }

    /// Distance converted to miles.
    var distanceMiles: Double {
        distance / 1609.34
    }
}

// MARK: - Errors

enum StravaError: LocalizedError {
    case notAuthenticated
    case noAuthorizationCode
    case tokenExchangeFailed
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not connected to Strava."
        case .noAuthorizationCode:
            return "Strava authorization was cancelled."
        case .tokenExchangeFailed:
            return "Could not connect to Strava. Please try again."
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}
