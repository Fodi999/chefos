//
//  DesignSystemConfig.swift
//  ChefOS — DesignSystem
//
//  The central control unit for the app's visual identity.
//

import SwiftUI
import Observation

/// dynamic source of truth for the app's visual identity.
@Observable
final class DesignSystem {
    static let shared = DesignSystem()
    
    /// The current vibe is locked to the professional product style.
    var vibe: DesignVibe = .mobile
    
    private init() {}
}

/// Simplified design categories for the app.
enum DesignVibe: String, CaseIterable, Identifiable {
    case mobile     // "Apple Health" style - minimalist, zero noise
    var id: String { self.rawValue }
    var name: String { "Product" }
}
