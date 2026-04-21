//
//  View+Extensions.swift
//  ChefOS — DesignSystem
//
//  Handy SwiftUI View extensions.
//

import SwiftUI

extension View {
    // MARK: - Press animation
    func pressAnimation() -> some View {
        self.buttonStyle(PressButtonStyle())
    }

    // MARK: - Hidden but occupying space
    func hiddenKeepingSpace(_ hidden: Bool) -> some View {
        self.opacity(hidden ? 0 : 1)
    }

    // MARK: - Read size
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: SizePreferenceKey.self, value: geo.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Animation Standards

extension Animation {
    static var premiumSpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
    }
}

// MARK: - Press Button Style

struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.premiumSpring, value: configuration.isPressed)
    }
}

// MARK: - Conditional modifier

extension View {
    /// Applies a transform only when condition is true.
    ///
    /// Usage:
    /// ```swift
    /// view.if(isLoading) { $0.shimmering() }
    /// ```
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
