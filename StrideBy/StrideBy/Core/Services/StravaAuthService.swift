//
//  StravaAuthService.swift
//  StrideBy
//
//  Created by Andrew Ginn on 2/12/26.
//

import AuthenticationServices
import Foundation
import Observation

@Observable
final class StravaAuthService {

    // MARK: - Public State

    var isAuthenticated = false
    var athleteName: String?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Private

    private let callbackURLScheme = "strideby"
    private let redirectURI = "strideby://strideby"

    // MARK: - Init

    init() {
        // Check if we already have tokens from a previous session
        isAuthenticated = KeychainHelper.load(key: "strava_access_token") != nil
        athleteName = KeychainHelper.load(key: "strava_athlete_name")
    }

    // MARK: - Authorize

    /// Kicks off the Strava OAuth flow in a secure browser sheet.
    @MainActor
    func authorize() async {
        isLoading = true
        errorMessage = nil

        do {
            let code = try await requestAuthorizationCode()
            try await exchangeCodeForTokens(code)
        } catch is CancellationError {
            // User cancelled — no error message needed
        } catch let error as ASWebAuthenticationSessionError
                    where error.code == .canceledLogin {
            // User tapped "Cancel" on the browser sheet
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Disconnect

    func disconnect() {
        KeychainHelper.delete(key: "strava_access_token")
        KeychainHelper.delete(key: "strava_refresh_token")
        KeychainHelper.delete(key: "strava_expires_at")
        KeychainHelper.delete(key: "strava_athlete_name")
        isAuthenticated = false
        athleteName = nil
    }

    // MARK: - Token Access

    /// Returns a valid access token, refreshing if expired.
    func validAccessToken() async throws -> String {
        guard let expiresAtStr = KeychainHelper.load(key: "strava_expires_at"),
              let expiresAt = Int(expiresAtStr)
        else {
            throw StravaError.notAuthenticated
        }

        // Refresh if token expires within the next 5 minutes
        if Int(Date().timeIntervalSince1970) >= expiresAt - 300 {
            try await refreshTokens()
        }

        guard let token = KeychainHelper.load(key: "strava_access_token") else {
            throw StravaError.notAuthenticated
        }
        return token
    }

    // MARK: - Private Helpers

    @MainActor
    private func requestAuthorizationCode() async throws -> String {
        var components = URLComponents(string: "https://www.strava.com/oauth/mobile/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Secrets.stravaClientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "read,activity:read_all"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
        ]

        let authURL = components.url!

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackURLScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let url = callbackURL,
                      let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value
                else {
                    continuation.resume(throwing: StravaError.noAuthorizationCode)
                    return
                }

                continuation.resume(returning: code)
            }

            // Present from the current window
            session.presentationContextProvider = PresentationContext.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func exchangeCodeForTokens(_ code: String) async throws {
        let body: [String: Any] = [
            "client_id": Secrets.stravaClientID,
            "client_secret": Secrets.stravaClientSecret,
            "code": code,
            "grant_type": "authorization_code",
        ]

        var request = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(StravaTokenResponse.self, from: data)

        saveTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: response.expiresAt
        )

        let name = "\(response.athlete.firstname) \(response.athlete.lastname)"
        KeychainHelper.save(key: "strava_athlete_name", value: name)

        isAuthenticated = true
        athleteName = name
    }

    private func refreshTokens() async throws {
        guard let refreshToken = KeychainHelper.load(key: "strava_refresh_token") else {
            throw StravaError.notAuthenticated
        }

        let body: [String: Any] = [
            "client_id": Secrets.stravaClientID,
            "client_secret": Secrets.stravaClientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ]

        var request = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(StravaRefreshResponse.self, from: data)

        saveTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: response.expiresAt
        )
    }

    private func saveTokens(accessToken: String, refreshToken: String, expiresAt: Int) {
        KeychainHelper.save(key: "strava_access_token", value: accessToken)
        KeychainHelper.save(key: "strava_refresh_token", value: refreshToken)
        KeychainHelper.save(key: "strava_expires_at", value: String(expiresAt))
    }
}

// MARK: - Presentation Context

/// Provides a window anchor for ASWebAuthenticationSession.
private final class PresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = PresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first
        else {
            return ASPresentationAnchor()
        }
        return window
    }
}
