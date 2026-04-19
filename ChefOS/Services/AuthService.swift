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

    // MARK: - Keychain Keys

    private let accessTokenKey = "com.chefos.access_token"
    private let refreshTokenKey = "com.chefos.refresh_token"
    private let userIdKey = "com.chefos.user_id"

    // Legacy key for migration
    private let legacyTokenKey = "com.chefos.auth_token"

    var hasToken: Bool {
        readKeychain(accessTokenKey) != nil
    }

    // MARK: - Keychain Helpers

    private func saveKeychain(_ key: String, value: String) {
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

    private func readKeychain(_ key: String) -> String? {
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

    private func deleteKeychain(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // Legacy compat
    func saveToken(_ token: String) { saveKeychain(accessTokenKey, value: token) }
    func readToken() -> String? { readKeychain(accessTokenKey) }
    func deleteToken() {
        deleteKeychain(accessTokenKey)
        deleteKeychain(refreshTokenKey)
        deleteKeychain(userIdKey)
        deleteKeychain(legacyTokenKey)
    }

    // MARK: - Store JWT Tokens from API

    private func storeAuthTokens(access: String, refresh: String, userId: String) {
        saveKeychain(accessTokenKey, value: access)
        saveKeychain(refreshTokenKey, value: refresh)
        saveKeychain(userIdKey, value: userId)
        // Wire into APIClient
        APIClient.shared.setTokens(access: access, refresh: refresh)
    }

    /// Restore tokens into APIClient on app launch
    func restoreSession() {
        if let access = readKeychain(accessTokenKey),
           let refresh = readKeychain(refreshTokenKey) {
            APIClient.shared.setTokens(access: access, refresh: refresh)
        }
    }

    // MARK: - Backend Auth

    func registerWithBackend(email: String, password: String, name: String) async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let response = try await APIClient.shared.register(email: email, password: password, name: name)
            await MainActor.run {
                storeAuthTokens(access: response.accessToken, refresh: response.refreshToken, userId: response.userId)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    func loginWithBackend(email: String, password: String) async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let response = try await APIClient.shared.login(email: email, password: password)
            await MainActor.run {
                storeAuthTokens(access: response.accessToken, refresh: response.refreshToken, userId: response.userId)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Biometrics

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
                    self?.restoreSession()
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

        if !hasCompletedOnboarding || !hasRealSession {
            // No onboarding completed or no real JWT → must authenticate
            state = .onboarding
        } else if biometricType != .none && UserDefaults.standard.bool(forKey: "chefos_biometrics_enabled") {
            state = .locked
        } else {
            restoreSession()
            state = .authenticated
            isAuthenticated = true
        }
    }

    func completeOnboarding(enableBiometrics: Bool) {
        UserDefaults.standard.set(true, forKey: "chefos_onboarded")

        if enableBiometrics {
            UserDefaults.standard.set(true, forKey: "chefos_biometrics_enabled")
        }

        restoreSession()

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            state = .authenticated
            isAuthenticated = true
        }
    }

    func skipBiometrics() {
        UserDefaults.standard.set(true, forKey: "chefos_onboarded")

        restoreSession()

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            state = .authenticated
            isAuthenticated = true
        }
    }

    /// Whether we have real backend tokens (not just "pending")
    var hasRealSession: Bool {
        guard let token = readKeychain(accessTokenKey) else { return false }
        return token != "pending" && token.count > 50 // JWTs are long
    }

    func logout() {
        deleteToken()
        APIClient.shared.clearTokens()
        UserDefaults.standard.set(false, forKey: "chefos_onboarded")
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            state = .onboarding
            isAuthenticated = false
        }
    }
}
