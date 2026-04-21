//
//  AuthService.swift
//  ChefOS
//

import Foundation
import LocalAuthentication
import Security
import SwiftUI
import Combine

// MARK: - Services/Auth

final class AuthService: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var biometricType: BiometricType = .none
    @Published var error: String? = nil

    enum BiometricType {
        case none, faceID, touchID
    }

    enum AuthState {
        case onboarding    // first launch
        case locked        // has token but needs biometric
        case authenticated // ready
    }

    @Published var state: AuthState = .onboarding

    // MARK: - Keychain

    private let tokenKey = "com.chefos.auth_token"
    private let refreshKey = "com.chefos.refresh_token"

    var hasToken: Bool {
        readToken() != nil
    }

    func saveToken(_ token: String) {
        writeKeychain(key: tokenKey, value: token)
    }

    /// Store refresh token separately so we can re-hydrate APIClient on
    /// relaunch without making the user re-login every time the short-lived
    /// access token expires.
    func saveRefreshToken(_ token: String) {
        writeKeychain(key: refreshKey, value: token)
    }

    private func writeKeychain(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func readToken() -> String? { readKeychain(key: tokenKey) }
    func readRefreshToken() -> String? { readKeychain(key: refreshKey) }

    private func readKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    var hasRealSession: Bool {
        guard let token = readToken() else { return false }
        return !token.isEmpty
    }

    func deleteToken() {
        for key in [tokenKey, refreshKey] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]
            SecItemDelete(query as CFDictionary)
        }
    }

    /// Push cached tokens (if any) into APIClient — called on app launch so
    /// relaunches don't force the user through onboarding again. If the
    /// access token turned out to be expired, the first 401 will trigger
    /// refresh-via-refresh_token; if THAT fails, onSessionExpired kicks in.
    func rehydrateAPIClient() {
        if let access = readToken(), !access.isEmpty {
            let refresh = readRefreshToken() ?? ""
            APIClient.shared.setTokens(access: access, refresh: refresh)
        }
        // Also wire persistence for future refreshes — so when APIClient
        // rotates the access token mid-session, we keep Keychain in sync.
        APIClient.shared.onTokensRefreshed = { [weak self] access, refresh in
            self?.saveToken(access)
            self?.saveRefreshToken(refresh)
        }
    }

    // MARK: - Biometrics

    @MainActor
    func loginWithBackend(email: String, password: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard !email.isEmpty, !password.isEmpty else {
            error = "Email and password are required."
            return
        }

        // Hit the real backend — /api/auth/login — and persist the JWT so
        // every subsequent private request (inventory, plan, …) carries a
        // valid Authorization header.
        do {
            let response = try await APIClient.shared.login(email: email, password: password)
            // Keychain stores the access token for biometric-unlock flow;
            // APIClient.login() has already cached access + refresh in RAM.
            saveToken(response.accessToken)
            saveRefreshToken(response.refreshToken)
        } catch let e as APIError {
            switch e {
            case .validation(let msg):  error = msg
            case .unauthorized:         error = "Invalid email or password"
            case .rateLimited:          error = "Too many attempts. Try again later."
            case .networkError:         error = "Network error. Check your connection."
            case .serverError(_, let m):error = m
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func registerWithBackend(email: String, password: String, name: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Name is required."
            return
        }

        guard !email.isEmpty, !password.isEmpty else {
            error = "Email and password are required."
            return
        }

        do {
            let response = try await APIClient.shared.register(email: email, password: password, name: name)
            saveToken(response.accessToken)
            saveRefreshToken(response.refreshToken)
        } catch let e as APIError {
            switch e {
            case .validation(let msg):  error = msg
            case .unauthorized:         error = "Authentication failed"
            case .rateLimited:          error = "Too many attempts. Try again later."
            case .networkError:         error = "Network error. Check your connection."
            case .serverError(_, let m):error = m
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func checkBiometricType() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID: biometricType = .faceID
            case .touchID: biometricType = .touchID
            default: biometricType = .none
            }
        } else {
            biometricType = .none
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .none: return "lock.fill"
        }
    }

    var biometricLabel: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .none: return "Passcode"
        }
    }

    func authenticateWithBiometrics() {
        let context = LAContext()
        context.localizedCancelTitle = "Use passcode"

        isLoading = true
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock ChefOS"
        ) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if success {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        self?.state = .authenticated
                        self?.isAuthenticated = true
                    }
                } else {
                    self?.error = error?.localizedDescription
                }
            }
        }
    }

    // MARK: - Startup

    func determineInitialState() {
        checkBiometricType()

        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "chefos_onboarded")

        if !hasCompletedOnboarding {
            state = .onboarding
        } else if hasToken && biometricType != .none {
            state = .locked
        } else {
            // No biometric or no token — skip to app
            state = .authenticated
            isAuthenticated = true
        }
    }

    func completeOnboarding(enableBiometrics: Bool) {
        // Generate a local session token
        let token = UUID().uuidString
        saveToken(token)
        UserDefaults.standard.set(true, forKey: "chefos_onboarded")

        if enableBiometrics {
            UserDefaults.standard.set(true, forKey: "chefos_biometrics_enabled")
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            state = .authenticated
            isAuthenticated = true
        }
    }

    func skipBiometrics() {
        let token = UUID().uuidString
        saveToken(token)
        UserDefaults.standard.set(true, forKey: "chefos_onboarded")

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            state = .authenticated
            isAuthenticated = true
        }
    }

    func logout() {
        deleteToken()
        UserDefaults.standard.set(false, forKey: "chefos_onboarded")
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            state = .onboarding
            isAuthenticated = false
        }
    }
}
