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

    var hasToken: Bool {
        readToken() != nil
    }

    func saveToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        // Delete old
        SecItemDelete(query as CFDictionary)
        // Add new
        SecItemAdd(query as CFDictionary, nil)
    }

    func readToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
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
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey
        ]
        SecItemDelete(query as CFDictionary)
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

        saveToken(UUID().uuidString)
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

        saveToken(UUID().uuidString)
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
