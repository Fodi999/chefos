//
//  DecimalPickerSheet.swift
//  ChefOS
//
//  Modern iOS 26 decimal wheel picker (Apple Health weight-style).
//  Two wheels: whole part + fractional part, with unit label beside the
//  live value. Returns a Double via the onSave callback.
//

import SwiftUI

struct DecimalPickerSheet: View {
    let title: String
    var unit: String = ""
    /// Whole-number range (e.g. 0...9999 for grams)
    let wholeRange: ClosedRange<Int>
    /// Fractional step — how many decimal slots. 10 → .0 … .9, 100 → .00 … .99
    var fractionSlots: Int = 10
    let initial: Double
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var whole: Int
    @State private var fraction: Int

    init(
        title: String,
        unit: String = "",
        wholeRange: ClosedRange<Int>,
        fractionSlots: Int = 10,
        initial: Double,
        onSave: @escaping (Double) -> Void
    ) {
        self.title = title
        self.unit = unit
        self.wholeRange = wholeRange
        self.fractionSlots = fractionSlots
        self.initial = initial
        self.onSave = onSave

        let clamped = min(max(initial, Double(wholeRange.lowerBound)), Double(wholeRange.upperBound))
        let w = Int(clamped)
        let f = Int(((clamped - Double(w)) * Double(fractionSlots)).rounded())
        _whole = State(initialValue: w)
        _fraction = State(initialValue: min(f, fractionSlots - 1))
    }

    private var combined: Double {
        Double(whole) + Double(fraction) / Double(fractionSlots)
    }

    private var fractionDigits: Int {
        // 10 slots → 1 digit, 100 → 2 digits
        Int(log10(Double(fractionSlots)).rounded(.up))
    }

    private var displayString: String {
        String(format: "%.\(fractionDigits)f", combined)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Live preview
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(displayString)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.15), value: combined)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.bottom, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 8)

                // Dual wheel pickers
                HStack(spacing: 0) {
                    Picker("", selection: $whole) {
                        ForEach(Array(wholeRange), id: \.self) { v in
                            Text("\(v)").tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Text(".")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    Picker("", selection: $fraction) {
                        ForEach(0..<fractionSlots, id: \.self) { v in
                            Text(String(format: "%0\(fractionDigits)d", v)).tag(v)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 0)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onSave(combined)
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Row helper (mirrors NumberPickerRow but accepts Double)

struct DecimalPickerRow: View {
    let label: String
    let value: Double
    var unit: String = ""
    var icon: String = "slider.horizontal.3"
    var fractionDigits: Int = 1
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 28, height: 28)
                    .background(AppColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(label)
                    .font(.body)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.\(fractionDigits)f", value))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText())
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
