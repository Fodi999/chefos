//
//  Spacing.swift
//  ChefOS — DesignSystem
//
//  All layout spacing values in one place.
//  Usage: Spacing.sm, Spacing.md
//

import CoreGraphics

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 16
    static let md:  CGFloat = 24
    static let lg:  CGFloat = 32
    static let xl:  CGFloat = 48
    static let xxl: CGFloat = 64
}

// MARK: - Legacy CGFloat Extensions (keeps .spacingXS etc. compiling)

extension CGFloat {
    static let spacingXS: CGFloat = Spacing.xxs
    static let spacingS:  CGFloat = Spacing.xs
    static let spacingM:  CGFloat = Spacing.sm
    static let spacingL:  CGFloat = Spacing.md
    static let spacingXL: CGFloat = Spacing.lg
}
