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
    case invalidResponse
    case unauthorized
    case rateLimited
    case apiError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not connected to Strava."
        case .noAuthorizationCode:
            return "Strava authorization was cancelled."
        case .tokenExchangeFailed:
            return "Could not connect to Strava. Please try again."
        case .invalidResponse:
            return "Received an invalid response from Strava."
        case .unauthorized:
            return "Your Strava session expired. Please reconnect."
        case .rateLimited:
            return "Strava rate limit reached. Try again in a few minutes."
        case .apiError(let message):
            return message
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - API Error Response

struct StravaAPIErrorResponse: Decodable {
    let message: String?
}
