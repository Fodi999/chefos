//
//  PaywallView.swift
//  ChefOS
//

import SwiftUI

// MARK: - Features/Paywall

struct PaywallView: View {
    @EnvironmentObject var usageService: UsageService
    @Environment(\.dismiss) var dismiss
    @State private var appeared = false
    @State private var selectedPackage: StorePackage? = nil
    @State private var purchasing = false

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    header
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    // What you get
                    benefitsCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    // Packages
                    VStack(spacing: 12) {
                        ForEach(Array(StorePackage.packages.enumerated()), id: \.element.id) { index, pkg in
                            PackageCard(
                                package: pkg,
                                isSelected: selectedPackage?.id == pkg.id,
                                onSelect: { selectedPackage = pkg }
                            )
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(0.2 + Double(index) * 0.08), value: appeared)
                        }
                    }

                    // Purchase button
                    purchaseButton
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    // Continue free
                    Button {
                        dismiss()
                    } label: {
                        Text("Continue free in \(usageService.timeUntilReset)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    // Usage info
                    usageInfo
                        .opacity(appeared ? 1 : 0)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            // Close
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(20)
                }
                Spacer()
            }
        }
        .onAppear {
            selectedPackage = StorePackage.packages.first { $0.badge != nil } ?? StorePackage.packages.first
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: 72, height: 72)
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Cook smarter, not harder")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            if !usageService.blockedAction.isEmpty {
                Text("You've reached your daily limit for \(usageService.blockedAction)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Free actions reset in \(usageService.timeUntilReset)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange.opacity(0.8))
            } else {
                Text("Unlock unlimited AI-powered cooking")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 30)
    }

    // MARK: - Benefits

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefitRow(icon: "sparkles", text: "Generate meal plans instantly", color: .orange)
            benefitRow(icon: "basket.fill", text: "Use your real ingredients", color: .green)
            benefitRow(icon: "banknote.fill", text: "Stay on budget automatically", color: .cyan)
            benefitRow(icon: "bolt.fill", text: "Hit your protein & calorie goals", color: .purple)
        }
        .padding(18)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
    }

    private func benefitRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button {
            guard let pkg = selectedPackage else { return }
            purchasing = true
            // Simulate purchase (replace with StoreKit later)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                usageService.addPurchasedActions(pkg.actions)
                purchasing = false
                dismiss()
            }
        } label: {
            HStack(spacing: 8) {
                if purchasing {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                } else {
                    Text("Get \(selectedPackage?.actions ?? 0) actions")
                        .font(.headline.weight(.bold))
                    Text("— \(selectedPackage?.price ?? "")")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(purchasing || selectedPackage == nil)
    }

    // MARK: - Usage Info

    private var usageInfo: some View {
        VStack(spacing: 6) {
            Text("Your free daily usage resets at midnight")
                .font(.caption)
                .foregroundStyle(.tertiary)
            HStack(spacing: 16) {
                usagePill("Plans", remaining: max(0, UsageService.DailyLimits.plans - usageService.dailyPlansUsed))
                usagePill("Recipes", remaining: max(0, UsageService.DailyLimits.recipes - usageService.dailyRecipesUsed))
                usagePill("Scans", remaining: max(0, UsageService.DailyLimits.scans - usageService.dailyScansUsed))
            }
        }
    }

    private func usagePill(_ label: String, remaining: Int) -> some View {
        VStack(spacing: 3) {
            Text("\(remaining)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(remaining > 0 ? .green : .red)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Package Card

struct PackageCard: View {
    let package: StorePackage
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(package.color.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(package.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(package.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        if let badge = package.badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(package.color, in: Capsule())
                        }
                    }
                    Text("\(package.actions) AI actions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(package.price)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isSelected ? package.color : .white)
            }
            .padding(12)
            .background(AppColors.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(package.color.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PressButtonStyle())
    }
}

#Preview {
    PaywallView()
        .environmentObject(UsageService())
        .preferredColorScheme(.dark)
}
