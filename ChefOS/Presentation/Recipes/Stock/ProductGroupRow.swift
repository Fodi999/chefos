// MARK: - Presentation/Recipes/Stock/ProductGroupRow.swift
// Extracted from RecipesView.swift as part of DDD refactoring

import SwiftUI

struct ProductGroupRow: View {
    let group: StockViewModel.ProductGroup
    let currency: String
    let isExpanded: Bool
    let onTap: () -> Void
    let onDelete: (StockItem) -> Void
    @EnvironmentObject var l10n: LocalizationService

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    if let url = group.entries.first?.imageUrl, let imgURL = URL(string: url) {
                        AsyncImage(url: imgURL) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            default:
                                Image(systemName: stockCategoryIcon(group.entries.first?.category ?? ""))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(iconColor)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: stockCategoryIcon(group.entries.first?.category ?? ""))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(iconColor)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(group.name)
                            .font(.subheadline.weight(.semibold))
                        if group.isExpiringSoon {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    HStack(spacing: 4) {
                        Text(fmt(group.totalQuantity))
                            .font(.caption.weight(.medium))
                        Text(group.entries.first?.unit.displayName ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if group.entryCount > 1 {
                            Text("·").foregroundStyle(.tertiary)
                            Text("\(group.entryCount) entries")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(format: "%.2f %@", group.totalValue, currency))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.green)
                    if let days = group.soonestExpiry {
                        HStack(spacing: 5) {
                            ExpiryProgressBar(days: days, maxDays: group.longestShelfLife)
                                .frame(width: 32, height: 5)
                            Text(days <= 1 ? l10n.t("recipes.expirestoday") : "\(days)d")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(expiryColor(days))
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            if isExpanded {
                VStack(spacing: 6) {
                    Divider().overlay(Color.white.opacity(0.06))
                    HStack(spacing: 16) {
                        detailItem(icon: "tag.fill", label: l10n.t("recipes.categoryLabel"), value: group.entries.first?.category ?? "—")
                        detailItem(icon: "banknote", label: l10n.t("recipes.pricePerUnit") + " ⌀", value: String(format: "%.2f %@", group.avgPricePerUnit, currency))
                    }
                    ForEach(group.entries) { entry in
                        entryRow(entry)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .productCard(cornerRadius: 16)
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        .overlay {
            if group.isExpiringSoon {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
            }
        }
        .animation(.snappy(duration: 0.3), value: isExpanded)
    }

    @ViewBuilder
    private func entryRow(_ item: StockItem) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text(fmt(item.quantity))
                        .font(.caption.weight(.bold))
                    Text(" " + item.unit.displayName + " × ")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(String(format: "%.2f %@", item.pricePerUnit, currency))
                        .font(.caption.weight(.medium))
                    Text(" = ").font(.caption2).foregroundStyle(.tertiary)
                    Text(String(format: "%.2f %@", item.totalPrice, currency))
                        .font(.caption.weight(.bold)).foregroundStyle(.green)
                }
                if let exp = item.expiresIn {
                    HStack(spacing: 6) {
                        ExpiryProgressBar(days: exp, maxDays: 14).frame(width: 40, height: 5)
                        Text(expiryHumanText(exp))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(expiryColor(exp))
                    }
                }
            }
            Spacer()
            Button { onDelete(item) } label: {
                Image(systemName: "trash").font(.caption2).foregroundStyle(.red.opacity(0.7))
                    .padding(6).background(Color.red.opacity(0.08), in: Circle())
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }

    private func expiryHumanText(_ days: Int) -> String {
        if days <= 0 { return "⚠️ " + l10n.t("recipes.insightExpired") }
        if days == 1 { return "🔴 " + l10n.t("recipes.useToday") }
        if days <= 3 { return "🟠 \(days) " + l10n.t("recipes.daysUseFirst") }
        if days <= 7 { return "🟡 \(days) " + l10n.t("recipes.daysLeft") }
        return "🟢 \(days) " + l10n.t("recipes.days")
    }

    private func detailItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.caption2).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption2).foregroundStyle(.tertiary)
                Text(value).font(.caption.weight(.semibold))
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }

    private var iconColor: Color {
        if group.isExpiringSoon { return .red }
        if group.isLow { return .orange }
        return .green
    }

    private func expiryColor(_ days: Int) -> Color {
        if days <= 1 { return .red }
        if days <= 3 { return .orange }
        if days <= 7 { return .yellow }
        return .green
    }
}
