import SwiftUI

struct ShoppingListSheet: View {
    @ObservedObject var vm: ShoppingListViewModel
    @EnvironmentObject var l10n: LocalizationService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.screenBackground
                    .ignoresSafeArea()

                if vm.items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Summary
                            HStack(spacing: 16) {
                                summaryPill(
                                    icon: "cart.fill",
                                    value: "\(vm.pendingCount)",
                                    label: l10n.t("shopping.toBuy"),
                                    color: .orange
                                )
                                summaryPill(
                                    icon: "checkmark.circle.fill",
                                    value: "\(vm.purchasedCount)",
                                    label: l10n.t("shopping.bought"),
                                    color: .green
                                )
                            }
                            .padding(.horizontal)

                            // Pending items
                            if !vm.pendingItems.isEmpty {
                                sectionHeader(l10n.t("shopping.toBuy"), icon: "cart.fill", color: .orange)

                                ForEach(vm.pendingItems) { item in
                                    shoppingRow(item, isPurchased: false)
                                }
                            }

                            // Purchased items
                            if !vm.purchasedItems.isEmpty {
                                sectionHeader(l10n.t("shopping.bought"), icon: "checkmark.circle.fill", color: .green)

                                ForEach(vm.purchasedItems) { item in
                                    shoppingRow(item, isPurchased: true)
                                }

                                Button {
                                    vm.clearPurchased()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trash")
                                            .font(.caption2)
                                        Text(l10n.t("shopping.clearBought"))
                                            .font(.caption.weight(.medium))
                                    }
                                    .foregroundStyle(.red.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle(l10n.t("cook.shoppingList"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Components

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.4))
            Text(l10n.t("shopping.empty"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(l10n.t("shopping.emptyHint"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func summaryPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color.opacity(0.7))
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal)
    }

    private func shoppingRow(_ item: ShoppingItem, isPurchased: Bool) -> some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                vm.togglePurchased(item)
            } label: {
                Image(systemName: isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isPurchased ? .green : .secondary.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(isPurchased)
                    .foregroundStyle(isPurchased ? .secondary : .primary)
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if !item.quantity.isEmpty {
                Text(item.quantity)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Delete
            Button {
                vm.remove(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .padding(6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }
}
