//
//  IngredientDetailSheet.swift
//  ChefOS
//
//  Wikipedia-style expandable detail for a catalog ingredient.
//  Data source: GET /public/catalog/ingredients/:slug → NutritionProductDetail.
//  Presented from ProductBotCard and any other chat card that has a slug.
//

import SwiftUI

// MARK: - Sheet wrapper (loads detail)

struct IngredientDetailSheet: View {
    let slug: String
    let fallbackName: String
    let fallbackImageUrl: String?

    @EnvironmentObject var l10n: LocalizationService
    @Environment(\.dismiss) private var dismiss

    @State private var detail: APIClient.IngredientDetailDTO?
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                if let d = detail {
                    IngredientDetailContent(detail: d, fallbackName: fallbackName, fallbackImageUrl: fallbackImageUrl)
                } else if isLoading {
                    ProgressView().controlSize(.large)
                } else if let err = errorText {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundStyle(AppColors.warning)
                        Text(err)
                            .font(.callout)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button(action: { Task { await load() } }) {
                            Text(retryLabel)
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle(detail?.localizedName(l10n.language) ?? fallbackName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
            .task { await load() }
        }
    }

    private var retryLabel: String {
        switch l10n.language {
        case "en": return "Retry"
        case "pl": return "Spróbuj ponownie"
        case "uk": return "Повторити"
        default:   return "Повторить"
        }
    }

    private func load() async {
        isLoading = true
        errorText = nil
        do {
            let d = try await APIClient.shared.getIngredientDetail(slug: slug)
            await MainActor.run {
                self.detail = d
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorText = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Content

private struct IngredientDetailContent: View {
    let detail: APIClient.IngredientDetailDTO
    let fallbackName: String
    let fallbackImageUrl: String?
    @EnvironmentObject var l10n: LocalizationService

    @State private var states: [APIClient.IngredientStateDTO] = []
    @State private var selectedState: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                heroSection
                if let desc = detail.localizedDescription(l10n.language), !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, Spacing.md)
                }

                physicalBadgesSection
                processingStatesSection
                macrosSection
                mineralsSection
                vitaminsSection
                culinarySection
                foodPropertiesSection
                healthSection
                sugarSection
                processingSection
                behaviorSection
                dietAllergensSection

                Spacer(minLength: 40)
            }
            .padding(.vertical, Spacing.md)
        }
        .task(id: detail.slug) {
            await loadStates()
        }
    }

    private func loadStates() async {
        guard !detail.slug.isEmpty else { return }
        do {
            let resp = try await APIClient.shared.getIngredientStates(slug: detail.slug)
            await MainActor.run {
                self.states = resp.states
                if self.selectedState == nil {
                    self.selectedState = resp.states.first?.state
                }
            }
        } catch {
            // Silent failure — section just won't appear.
        }
    }

    // MARK: Hero

    @ViewBuilder
    private var heroSection: some View {
        ZStack {
            let url = detail.imageUrl ?? fallbackImageUrl
            if let s = url, let u = URL(string: s) {
                AsyncImage(url: u) { phase in
                    if let img = phase.image { img.resizable().scaledToFill() }
                    else { placeholder }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipped()
    }

    private var placeholder: some View {
        ZStack {
            AppColors.textSecondary.opacity(0.08)
            Image(systemName: "leaf.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: Physical badges (shelf life, temp, water type, yield…)

    @ViewBuilder
    private var physicalBadgesSection: some View {
        let badges = buildPhysicalBadges()
        if !badges.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(badges.enumerated()), id: \.offset) { _, b in
                        badgePill(icon: b.icon, text: b.text, color: b.color)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    private struct Badge { let icon: String; let text: String; let color: Color }

    private func buildPhysicalBadges() -> [Badge] {
        var out: [Badge] = []
        if let d = detail.shelfLifeDays {
            out.append(.init(icon: "clock.fill", text: "\(d) \(daysUnit(d))", color: .orange))
        }
        if let y = detail.edibleYieldPercent {
            out.append(.init(icon: "leaf.arrow.circlepath", text: String(format: "%.0f%%", y), color: .green))
        }
        if let p = detail.typicalPortionG {
            out.append(.init(icon: "scalemass.fill", text: String(format: "%.0f g", p), color: .blue))
        }
        if let dens = detail.densityGPerMl {
            out.append(.init(icon: "drop.fill", text: String(format: "%.2f g/ml", dens), color: .cyan))
        }
        if let w = detail.waterType, !w.isEmpty {
            out.append(.init(icon: "water.waves", text: w, color: .cyan))
        }
        if let wf = detail.wildFarmed, !wf.isEmpty {
            out.append(.init(icon: "fish.fill", text: wf, color: .teal))
        }
        if detail.sushiGrade == true {
            out.append(.init(icon: "star.fill", text: "sushi-grade", color: .pink))
        }
        return out
    }

    private func daysUnit(_ d: Int) -> String {
        // Russian plural: 1 день / 2-4 дня / 5+ дней. For EN/PL/UK: just "days" (simple).
        if l10n.language == "ru" {
            let n = d % 100
            if (11...14).contains(n) { return "дней" }
            switch n % 10 {
            case 1: return "день"
            case 2, 3, 4: return "дня"
            default: return "дней"
            }
        }
        return l10n.language == "en" ? "days" : "d"
    }

    private func badgePill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(text).font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: Processing states (raw / boiled / fried / …)

    @ViewBuilder
    private var processingStatesSection: some View {
        if !states.isEmpty {
            SectionCard(title: sectionTitle(.processingStates), icon: "flame.fill", accent: .orange) {
                VStack(alignment: .leading, spacing: 12) {
                    // Horizontal pill row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(states) { s in
                                statePill(s)
                            }
                        }
                    }
                    // Selected state details
                    if let sel = states.first(where: { $0.state == selectedState }) ?? states.first {
                        stateDetailView(sel)
                    }
                }
            }
        }
    }

    private func statePill(_ s: APIClient.IngredientStateDTO) -> some View {
        let isSelected = (selectedState ?? states.first?.state) == s.state
        let label = s.localizedSuffix(l10n.language) ?? stateFallbackLabel(s.state)
        return Button(action: { selectedState = s.state }) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : AppColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? Color.orange : AppColors.textSecondary.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func stateDetailView(_ s: APIClient.IngredientStateDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top metric strip — weight change + shelf + temp
            HStack(spacing: 8) {
                if let w = s.weightChangePercent {
                    let positive = w >= 0
                    let text = String(format: "%@%.0f%%", positive ? "+" : "", w)
                    metricChip(
                        icon: positive ? "arrow.up.right" : "arrow.down.right",
                        label: weightLabel,
                        value: text,
                        color: positive ? .green : .red
                    )
                }
                if let h = s.shelfLifeHours {
                    metricChip(icon: "clock.fill", label: shelfLabel, value: formatShelf(h), color: .blue)
                }
                if let t = s.storageTempC {
                    metricChip(icon: "thermometer", label: tempLabel, value: "\(t)°C", color: .cyan)
                }
            }
            // Macros row
            if s.caloriesPer100g != nil || s.proteinPer100g != nil || s.fatPer100g != nil || s.carbsPer100g != nil {
                VStack(spacing: 0) {
                    if let v = s.caloriesPer100g { dataRow("kcal", value: format1(v), unit: "") }
                    if let v = s.proteinPer100g  { dataRow(sectionTitle(.protein), value: format2(v), unit: "g") }
                    if let v = s.fatPer100g      { dataRow(sectionTitle(.fat),     value: format2(v), unit: "g") }
                    if let v = s.carbsPer100g    { dataRow(sectionTitle(.carbs),   value: format2(v), unit: "g") }
                    if let v = s.fiberPer100g    { dataRow(sectionTitle(.fiber),   value: format2(v), unit: "g") }
                    if let v = s.waterPercent    { dataRow(sectionTitle(.water),   value: format1(v), unit: "%") }
                    if let v = s.oilAbsorptionG  { dataRow(oilLabel, value: format1(v), unit: "g") }
                    if let v = s.waterLossPercent { dataRow(waterLossLabel, value: format1(v), unit: "%") }
                }
            }
            // Texture + notes
            if let tex = s.texture, !tex.isEmpty {
                tagRow(label: sectionTitle(.texture), value: tex)
            }
            if let notes = s.localizedNotes(l10n.language), !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func metricChip(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func formatShelf(_ hours: Int) -> String {
        if hours >= 48 {
            let d = hours / 24
            return "\(d) \(daysUnit(d))"
        }
        return "\(hours) h"
    }

    private func stateFallbackLabel(_ state: String) -> String {
        // Fallback if suffix missing — capitalize raw key.
        return state.prefix(1).uppercased() + state.dropFirst()
    }

    private var weightLabel: String {
        switch l10n.language {
        case "en": return "Weight change"
        case "pl": return "Zmiana masy"
        case "uk": return "Зміна ваги"
        default:   return "Изменение массы"
        }
    }
    private var shelfLabel: String {
        switch l10n.language {
        case "en": return "Shelf life"
        case "pl": return "Trwałość"
        case "uk": return "Зберігання"
        default:   return "Хранение"
        }
    }
    private var tempLabel: String {
        switch l10n.language {
        case "en": return "Temp"
        case "pl": return "Temp."
        case "uk": return "Темп."
        default:   return "Темп."
        }
    }
    private var oilLabel: String {
        switch l10n.language {
        case "en": return "Oil absorbed"
        case "pl": return "Absorpcja oleju"
        case "uk": return "Поглинання олії"
        default:   return "Впитывание масла"
        }
    }
    private var waterLossLabel: String {
        switch l10n.language {
        case "en": return "Water loss"
        case "pl": return "Utrata wody"
        case "uk": return "Втрата води"
        default:   return "Потеря воды"
        }
    }

    // MARK: Macros

    @ViewBuilder
    private var macrosSection: some View {
        if let m = detail.macros {
            SectionCard(title: sectionTitle(.macros), icon: "flame.fill", accent: .orange) {
                VStack(spacing: 0) {
                    if let v = m.caloriesKcal { dataRow("kcal", value: "\(format1(v))", unit: "") }
                    if let v = m.proteinG    { dataRow(sectionTitle(.protein), value: format2(v), unit: "g") }
                    if let v = m.fatG        { dataRow(sectionTitle(.fat),     value: format2(v), unit: "g") }
                    if let v = m.carbsG      { dataRow(sectionTitle(.carbs),   value: format2(v), unit: "g") }
                    if let v = m.fiberG      { dataRow(sectionTitle(.fiber),   value: format2(v), unit: "g") }
                    if let v = m.sugarG      { dataRow(sectionTitle(.sugar),   value: format2(v), unit: "g") }
                    if let v = m.starchG     { dataRow(sectionTitle(.starch),  value: format2(v), unit: "g") }
                    if let v = m.waterG      { dataRow(sectionTitle(.water),   value: format1(v), unit: "g") }
                }
            }
        }
    }

    // MARK: Minerals

    @ViewBuilder
    private var mineralsSection: some View {
        if let m = detail.minerals, hasAnyMineral(m) {
            SectionCard(title: sectionTitle(.minerals), icon: "atom", accent: .blue) {
                VStack(spacing: 0) {
                    if let v = m.calcium    { dataRow(mineralName(.calcium),    value: format1(v), unit: "mg") }
                    if let v = m.iron       { dataRow(mineralName(.iron),       value: format2(v), unit: "mg") }
                    if let v = m.magnesium  { dataRow(mineralName(.magnesium),  value: format1(v), unit: "mg") }
                    if let v = m.phosphorus { dataRow(mineralName(.phosphorus), value: format1(v), unit: "mg") }
                    if let v = m.potassium  { dataRow(mineralName(.potassium),  value: format1(v), unit: "mg") }
                    if let v = m.sodium     { dataRow(mineralName(.sodium),     value: format1(v), unit: "mg") }
                    if let v = m.zinc       { dataRow(mineralName(.zinc),       value: format2(v), unit: "mg") }
                    if let v = m.copper     { dataRow(mineralName(.copper),     value: format2(v), unit: "mg") }
                    if let v = m.manganese  { dataRow(mineralName(.manganese),  value: format2(v), unit: "mg") }
                    if let v = m.selenium   { dataRow(mineralName(.selenium),   value: format1(v), unit: "µg") }
                }
            }
        }
    }

    private func hasAnyMineral(_ m: APIClient.IngredientDetailDTO.Minerals) -> Bool {
        return [m.calcium, m.iron, m.magnesium, m.phosphorus, m.potassium, m.sodium,
                m.zinc, m.copper, m.manganese, m.selenium].contains(where: { $0 != nil })
    }

    // MARK: Vitamins

    @ViewBuilder
    private var vitaminsSection: some View {
        if let v = detail.vitamins, hasAnyVitamin(v) {
            SectionCard(title: sectionTitle(.vitamins), icon: "pill.fill", accent: .orange) {
                VStack(spacing: 0) {
                    if let x = v.vitaminA   { dataRow("A", value: format2(x), unit: "µg") }
                    if let x = v.vitaminC   { dataRow("C", value: format1(x), unit: "mg") }
                    if let x = v.vitaminD   { dataRow("D", value: format2(x), unit: "µg") }
                    if let x = v.vitaminE   { dataRow("E", value: format2(x), unit: "mg") }
                    if let x = v.vitaminK   { dataRow("K", value: format1(x), unit: "µg") }
                    if let x = v.vitaminB1  { dataRow("B1", value: format2(x), unit: "mg") }
                    if let x = v.vitaminB2  { dataRow("B2", value: format2(x), unit: "mg") }
                    if let x = v.vitaminB3  { dataRow("B3", value: format2(x), unit: "mg") }
                    if let x = v.vitaminB5  { dataRow("B5", value: format2(x), unit: "mg") }
                    if let x = v.vitaminB6  { dataRow("B6", value: format2(x), unit: "mg") }
                    if let x = v.vitaminB7  { dataRow("B7", value: format2(x), unit: "µg") }
                    if let x = v.vitaminB9  { dataRow("B9", value: format1(x), unit: "µg") }
                    if let x = v.vitaminB12 { dataRow("B12", value: format2(x), unit: "µg") }
                }
            }
        }
    }

    private func hasAnyVitamin(_ v: APIClient.IngredientDetailDTO.Vitamins) -> Bool {
        return [v.vitaminA, v.vitaminC, v.vitaminD, v.vitaminE, v.vitaminK,
                v.vitaminB1, v.vitaminB2, v.vitaminB3, v.vitaminB5, v.vitaminB6,
                v.vitaminB7, v.vitaminB9, v.vitaminB12].contains(where: { $0 != nil })
    }

    // MARK: Culinary profile

    @ViewBuilder
    private var culinarySection: some View {
        if let c = detail.culinary {
            let any = c.sweetness ?? c.acidity ?? c.bitterness ?? c.umami ?? c.aroma
            if any != nil || (c.texture?.isEmpty == false) {
                SectionCard(title: sectionTitle(.culinary), icon: "fork.knife.circle.fill", accent: .pink) {
                    VStack(spacing: 10) {
                        if let x = c.sweetness  { culinaryBar(label: sectionTitle(.sweetness),  value: x) }
                        if let x = c.acidity    { culinaryBar(label: sectionTitle(.acidity),    value: x) }
                        if let x = c.bitterness { culinaryBar(label: sectionTitle(.bitterness), value: x) }
                        if let x = c.umami      { culinaryBar(label: sectionTitle(.umami),      value: x) }
                        if let x = c.aroma      { culinaryBar(label: sectionTitle(.aroma),      value: x) }
                        if let t = c.texture, !t.isEmpty {
                            HStack {
                                Text(sectionTitle(.texture))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                Spacer()
                                Text(t)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    private func culinaryBar(label: String, value: Double) -> some View {
        let clamped = max(0, min(10, value))
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text(String(format: "%.0f", clamped))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.textSecondary.opacity(0.12))
                    Capsule().fill(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(clamped / 10.0))
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: Food properties

    @ViewBuilder
    private var foodPropertiesSection: some View {
        if let f = detail.foodProperties {
            let any = f.glycemicIndex ?? f.glycemicLoad ?? f.ph ?? f.smokePoint ?? f.waterActivity
            if any != nil {
                SectionCard(title: sectionTitle(.foodProperties), icon: "waveform.path.ecg", accent: .purple) {
                    VStack(spacing: 0) {
                        if let v = f.glycemicIndex { dataRow(sectionTitle(.gi),  value: format1(v), unit: "") }
                        if let v = f.glycemicLoad  { dataRow(sectionTitle(.gl),  value: format2(v), unit: "") }
                        if let v = f.ph            { dataRow("pH", value: format1(v), unit: "") }
                        if let v = f.waterActivity { dataRow("aw", value: format2(v), unit: "") }
                        if let v = f.smokePoint    { dataRow(sectionTitle(.smokePoint), value: format1(v), unit: "°C") }
                    }
                }
            }
        }
    }

    // MARK: Health

    @ViewBuilder
    private var healthSection: some View {
        if let h = detail.healthProfile {
            let bioactive = pickLocalizedArray(h.bioactiveCompoundsEn, h.bioactiveCompoundsRu, h.bioactiveCompoundsPl, h.bioactiveCompoundsUk)
            let effects   = pickLocalizedArray(h.healthEffectsEn, h.healthEffectsRu, h.healthEffectsPl, h.healthEffectsUk)
            let contras   = pickLocalizedArray(h.contraindicationsEn, h.contraindicationsRu, h.contraindicationsPl, h.contraindicationsUk)
            let notes     = pickLocalizedString(h.absorptionNotesEn, h.absorptionNotesRu, h.absorptionNotesPl, h.absorptionNotesUk)

            let hasAny = !bioactive.isEmpty || !effects.isEmpty || !contras.isEmpty
                || h.foodRole != nil || h.oracScore != nil || (notes?.isEmpty == false)

            if hasAny {
                SectionCard(title: sectionTitle(.health), icon: "heart.text.square.fill", accent: .red) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let role = h.foodRole, !role.isEmpty {
                            tagRow(label: sectionTitle(.foodRole), value: role)
                        }
                        if let orac = h.oracScore {
                            tagRow(label: "ORAC", value: String(format: "%.0f", orac))
                        }
                        if !bioactive.isEmpty {
                            tagList(title: sectionTitle(.bioactive), items: bioactive, color: .purple)
                        }
                        if !effects.isEmpty {
                            checklist(title: sectionTitle(.healthEffects), items: effects, symbol: "checkmark.circle.fill", color: .green)
                        }
                        if !contras.isEmpty {
                            checklist(title: sectionTitle(.contraindications), items: contras, symbol: "exclamationmark.triangle.fill", color: .orange)
                        }
                        if let notes = notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sectionTitle(.absorption))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.textSecondary)
                                Text(notes)
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Sugar profile

    @ViewBuilder
    private var sugarSection: some View {
        if let s = detail.sugarProfile {
            let any = s.glucose ?? s.fructose ?? s.sucrose ?? s.lactose ?? s.maltose
                ?? s.totalSugars ?? s.addedSugars ?? s.sweetnessPerception ?? s.sugarAlcohols
            if any != nil {
                SectionCard(title: sectionTitle(.sugarProfile), icon: "cube.fill", accent: .brown) {
                    VStack(spacing: 0) {
                        if let v = s.glucose       { dataRow(sectionTitle(.glucose),  value: format2(v), unit: "g") }
                        if let v = s.fructose      { dataRow(sectionTitle(.fructose), value: format2(v), unit: "g") }
                        if let v = s.sucrose       { dataRow(sectionTitle(.sucrose),  value: format2(v), unit: "g") }
                        if let v = s.lactose       { dataRow(sectionTitle(.lactose),  value: format2(v), unit: "g") }
                        if let v = s.maltose       { dataRow(sectionTitle(.maltose),  value: format2(v), unit: "g") }
                        if let v = s.totalSugars   { dataRow(sectionTitle(.totalSugars), value: format2(v), unit: "g") }
                        if let v = s.addedSugars   { dataRow(sectionTitle(.addedSugars), value: format2(v), unit: "g") }
                        if let v = s.sugarAlcohols { dataRow(sectionTitle(.sugarAlcohols), value: format2(v), unit: "g") }
                        if let v = s.sweetnessPerception {
                            dataRow(sectionTitle(.sweetnessPerception), value: String(format: "%.0f/10", v), unit: "")
                        }
                    }
                }
            }
        }
    }

    // MARK: Processing effects

    @ViewBuilder
    private var processingSection: some View {
        if let p = detail.processingEffects {
            let best = pickLocalizedString(p.bestCookingMethodEn, p.bestCookingMethodRu, p.bestCookingMethodPl, p.bestCookingMethodUk)
            let notes = pickLocalizedString(p.processingNotesEn, p.processingNotesRu, p.processingNotesPl, p.processingNotesUk)
            let hasAny = p.vitaminRetentionPct != nil || p.proteinDenatureTemp != nil
                || p.mineralLeachingRisk != nil || p.maillardTemp != nil
                || (best?.isEmpty == false) || (notes?.isEmpty == false)
            if hasAny {
                SectionCard(title: sectionTitle(.processing), icon: "flame.circle.fill", accent: .orange) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let v = p.vitaminRetentionPct { dataRow(sectionTitle(.vitaminRetention), value: format1(v), unit: "%") }
                        if let v = p.maillardTemp        { dataRow(sectionTitle(.maillard), value: format1(v), unit: "°C") }
                        if let v = p.proteinDenatureTemp { dataRow(sectionTitle(.proteinDenature), value: format1(v), unit: "°C") }
                        if let r = p.mineralLeachingRisk, !r.isEmpty {
                            dataRow(sectionTitle(.leaching), value: r, unit: "")
                        }
                        if let best = best, !best.isEmpty {
                            tagRow(label: sectionTitle(.bestMethod), value: best)
                        }
                        if let notes = notes, !notes.isEmpty {
                            Text(notes)
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: Culinary behavior

    @ViewBuilder
    private var behaviorSection: some View {
        if let cb = detail.culinaryBehavior, !cb.behaviors.isEmpty {
            SectionCard(title: sectionTitle(.behavior), icon: "sparkles", accent: .yellow) {
                VStack(spacing: 8) {
                    ForEach(cb.behaviors) { b in
                        behaviorRow(b)
                    }
                }
            }
        }
    }

    private func behaviorRow(_ b: APIClient.IngredientDetailDTO.CookingBehavior) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(b.polarity == "+" ? "＋" : (b.polarity == "-" ? "－" : "•"))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(b.polarity == "-" ? AppColors.danger : AppColors.success)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(b.key.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                HStack(spacing: 6) {
                    if !b.type.isEmpty {
                        smallTag(b.type)
                    }
                    if let d = b.domain, !d.isEmpty { smallTag(d) }
                    if let t = b.trigger, !t.isEmpty { smallTag(t) }
                    if let temp = b.tempThreshold {
                        smallTag(String(format: "%.0f°C", temp))
                    }
                    if let i = b.intensity {
                        smallTag(String(format: "%.0f%%", i * 100))
                    }
                }
                if let targets = b.targets, !targets.isEmpty {
                    Text("→ " + targets.joined(separator: ", "))
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            Spacer()
        }
    }

    private func smallTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(AppColors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppColors.textSecondary.opacity(0.10), in: Capsule())
    }

    // MARK: Diet flags + allergens

    @ViewBuilder
    private var dietAllergensSection: some View {
        let diet = diets()
        let alg = allergens()
        if !diet.isEmpty || !alg.isEmpty {
            SectionCard(title: sectionTitle(.dietFlags), icon: "fork.knife", accent: .green) {
                VStack(alignment: .leading, spacing: 10) {
                    if !diet.isEmpty {
                        DetailFlowLayout(spacing: 6) {
                            ForEach(diet, id: \.self) { d in
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 10))
                                    Text(d)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.green.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    if !alg.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sectionTitle(.allergens))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary)
                            DetailFlowLayout(spacing: 6) {
                                ForEach(alg, id: \.self) { a in
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 10))
                                        Text(a)
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func diets() -> [String] {
        guard let d = detail.dietFlags else { return [] }
        var out: [String] = []
        if d.vegan == true { out.append("vegan") }
        if d.vegetarian == true { out.append("vegetarian") }
        if d.keto == true { out.append("keto") }
        if d.paleo == true { out.append("paleo") }
        if d.glutenFree == true { out.append("gluten-free") }
        if d.mediterranean == true { out.append("mediterranean") }
        if d.lowCarb == true { out.append("low-carb") }
        return out
    }

    private func allergens() -> [String] {
        guard let a = detail.allergens else { return [] }
        var out: [String] = []
        if a.milk == true { out.append("milk") }
        if a.fish == true { out.append("fish") }
        if a.shellfish == true { out.append("shellfish") }
        if a.nuts == true { out.append("nuts") }
        if a.peanuts == true { out.append("peanuts") }
        if a.soy == true { out.append("soy") }
        if a.gluten == true { out.append("gluten") }
        if a.eggs == true { out.append("eggs") }
        if a.sesame == true { out.append("sesame") }
        if a.celery == true { out.append("celery") }
        if a.mustard == true { out.append("mustard") }
        if a.sulfites == true { out.append("sulfites") }
        if a.lupin == true { out.append("lupin") }
        if a.molluscs == true { out.append("molluscs") }
        return out
    }

    // MARK: Small builders

    private func dataRow(_ label: String, value: String, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColors.divider).frame(height: 0.5)
        }
    }

    private func tagRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(AppColors.textSecondary.opacity(0.10), in: Capsule())
        }
    }

    private func tagList(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
            DetailFlowLayout(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(color)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(color.opacity(0.12), in: Capsule())
                }
            }
        }
    }

    private func checklist(title: String, items: [String], symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: symbol)
                            .font(.system(size: 11))
                            .foregroundStyle(color)
                            .padding(.top, 3)
                        Text(item)
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: Format helpers

    private func format1(_ v: Double) -> String { String(format: "%.1f", v) }
    private func format2(_ v: Double) -> String { String(format: "%.2f", v) }

    private func pickLocalizedArray(_ en: [String]?, _ ru: [String]?, _ pl: [String]?, _ uk: [String]?) -> [String] {
        switch l10n.language {
        case "en": return en ?? ru ?? []
        case "pl": return pl ?? en ?? []
        case "uk": return uk ?? ru ?? []
        default:   return ru ?? en ?? []
        }
    }

    private func pickLocalizedString(_ en: String?, _ ru: String?, _ pl: String?, _ uk: String?) -> String? {
        switch l10n.language {
        case "en": return en ?? ru
        case "pl": return pl ?? en
        case "uk": return uk ?? ru
        default:   return ru ?? en
        }
    }
}

// MARK: - Section card chrome

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let accent: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
            }
            content()
        }
        .padding(Spacing.md)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(AppColors.divider.opacity(0.4), lineWidth: 0.5)
        )
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Simple wrap layout for tags

private struct DetailFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxW {
                x = 0
                y += rowH + spacing
                rowH = 0
            }
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return CGSize(width: maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowH: CGFloat = 0
        let maxX = bounds.maxX
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxX {
                x = bounds.minX
                y += rowH + spacing
                rowH = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}

// MARK: - Localized section titles (lightweight, no new i18n keys needed)

private enum SectionKey {
    case macros, minerals, vitamins, culinary, foodProperties, health, sugarProfile, processing, behavior, dietFlags, allergens
    case processingStates
    case protein, fat, carbs, fiber, sugar, starch, water, calcium, iron, magnesium, phosphorus, potassium, sodium, zinc, copper, manganese, selenium
    case sweetness, acidity, bitterness, umami, aroma, texture
    case gi, gl, smokePoint
    case foodRole, bioactive, healthEffects, contraindications, absorption
    case glucose, fructose, sucrose, lactose, maltose, totalSugars, addedSugars, sweetnessPerception, sugarAlcohols
    case vitaminRetention, maillard, proteinDenature, leaching, bestMethod
}

private extension IngredientDetailContent {
    func sectionTitle(_ k: SectionKey) -> String {
        switch (k, l10n.language) {
        // Headline groups
        case (.macros, "en"):          return "Nutrition per 100g"
        case (.macros, "pl"):          return "Wartości odżywcze na 100g"
        case (.macros, "uk"):          return "Харчова цінність на 100г"
        case (.macros, _):             return "Пищевая ценность на 100г"
        case (.minerals, "en"):        return "Minerals per 100g"
        case (.minerals, "pl"):        return "Minerały na 100g"
        case (.minerals, "uk"):        return "Мінерали на 100г"
        case (.minerals, _):           return "Минералы на 100г"
        case (.vitamins, "en"):        return "Vitamins per 100g"
        case (.vitamins, "pl"):        return "Witaminy na 100g"
        case (.vitamins, "uk"):        return "Вітаміни на 100г"
        case (.vitamins, _):           return "Витамины на 100г"
        case (.culinary, "en"):        return "Culinary profile"
        case (.culinary, "pl"):        return "Profil kulinarny"
        case (.culinary, "uk"):        return "Кулінарний профіль"
        case (.culinary, _):           return "Кулинарный профиль"
        case (.foodProperties, "en"):  return "Properties"
        case (.foodProperties, "pl"):  return "Właściwości"
        case (.foodProperties, "uk"):  return "Властивості"
        case (.foodProperties, _):     return "Свойства"
        case (.health, "en"):          return "Health profile"
        case (.health, "pl"):          return "Profil zdrowotny"
        case (.health, "uk"):          return "Профіль здоров'я"
        case (.health, _):             return "Профиль здоровья"
        case (.sugarProfile, "en"):    return "Sugar profile"
        case (.sugarProfile, "pl"):    return "Profil cukrowy"
        case (.sugarProfile, "uk"):    return "Цукровий профіль"
        case (.sugarProfile, _):       return "Сахарный профиль"
        case (.processing, "en"):      return "Processing effects"
        case (.processing, "pl"):      return "Efekty przetwarzania"
        case (.processing, "uk"):      return "Ефекти обробки"
        case (.processing, _):         return "Эффекты обработки"
        case (.processingStates, "en"): return "Processing states"
        case (.processingStates, "pl"): return "Stany przetwarzania"
        case (.processingStates, "uk"): return "Стани обробки"
        case (.processingStates, _):    return "Состояния обработки"
        case (.behavior, "en"):        return "Cooking behavior"
        case (.behavior, "pl"):        return "Zachowanie kulinarne"
        case (.behavior, "uk"):        return "Кулінарна поведінка"
        case (.behavior, _):           return "Кулинарное поведение"
        case (.dietFlags, "en"):       return "Diet & allergens"
        case (.dietFlags, "pl"):       return "Dieta i alergeny"
        case (.dietFlags, "uk"):       return "Дієта та алергени"
        case (.dietFlags, _):          return "Диета и аллергены"
        case (.allergens, "en"):       return "Allergens"
        case (.allergens, "pl"):       return "Alergeny"
        case (.allergens, "uk"):       return "Алергени"
        case (.allergens, _):          return "Аллергены"

        // Macros
        case (.protein, "en"): return "Protein"
        case (.protein, "pl"): return "Białko"
        case (.protein, "uk"): return "Білок"
        case (.protein, _):    return "Белки"
        case (.fat, "en"):     return "Fat"
        case (.fat, "pl"):     return "Tłuszcz"
        case (.fat, "uk"):     return "Жири"
        case (.fat, _):        return "Жиры"
        case (.carbs, "en"):   return "Carbs"
        case (.carbs, "pl"):   return "Węglowodany"
        case (.carbs, "uk"):   return "Вуглеводи"
        case (.carbs, _):      return "Углеводы"
        case (.fiber, "en"):   return "Fiber"
        case (.fiber, "pl"):   return "Błonnik"
        case (.fiber, "uk"):   return "Клітковина"
        case (.fiber, _):      return "Клетчатка"
        case (.sugar, "en"):   return "Sugar"
        case (.sugar, "pl"):   return "Cukier"
        case (.sugar, "uk"):   return "Цукор"
        case (.sugar, _):      return "Сахар"
        case (.starch, "en"):  return "Starch"
        case (.starch, "pl"):  return "Skrobia"
        case (.starch, "uk"):  return "Крохмаль"
        case (.starch, _):     return "Крахмал"
        case (.water, "en"):   return "Water"
        case (.water, "pl"):   return "Woda"
        case (.water, "uk"):   return "Вода"
        case (.water, _):      return "Вода"

        // Minerals (simple words — fallback to english name)
        case (.calcium, "ru"): return "Кальций"
        case (.iron, "ru"):    return "Железо"
        case (.magnesium, "ru"): return "Магний"
        case (.phosphorus, "ru"): return "Фосфор"
        case (.potassium, "ru"): return "Калий"
        case (.sodium, "ru"):  return "Натрий"
        case (.zinc, "ru"):    return "Цинк"
        case (.copper, "ru"):  return "Медь"
        case (.manganese, "ru"): return "Марганец"
        case (.selenium, "ru"): return "Селен"
        case (.calcium, "pl"): return "Wapń"
        case (.iron, "pl"):    return "Żelazo"
        case (.magnesium, "pl"): return "Magnez"
        case (.phosphorus, "pl"): return "Fosfor"
        case (.potassium, "pl"): return "Potas"
        case (.sodium, "pl"):  return "Sód"
        case (.zinc, "pl"):    return "Cynk"
        case (.copper, "pl"):  return "Miedź"
        case (.manganese, "pl"): return "Mangan"
        case (.selenium, "pl"): return "Selen"
        case (.calcium, "uk"): return "Кальцій"
        case (.iron, "uk"):    return "Залізо"
        case (.magnesium, "uk"): return "Магній"
        case (.phosphorus, "uk"): return "Фосфор"
        case (.potassium, "uk"): return "Калій"
        case (.sodium, "uk"):  return "Натрій"
        case (.zinc, "uk"):    return "Цинк"
        case (.copper, "uk"):  return "Мідь"
        case (.manganese, "uk"): return "Марганець"
        case (.selenium, "uk"): return "Селен"
        case (.calcium, _):    return "Calcium"
        case (.iron, _):       return "Iron"
        case (.magnesium, _):  return "Magnesium"
        case (.phosphorus, _): return "Phosphorus"
        case (.potassium, _):  return "Potassium"
        case (.sodium, _):     return "Sodium"
        case (.zinc, _):       return "Zinc"
        case (.copper, _):     return "Copper"
        case (.manganese, _):  return "Manganese"
        case (.selenium, _):   return "Selenium"

        // Culinary axes
        case (.sweetness, "en"):  return "Sweetness"
        case (.sweetness, "pl"):  return "Słodycz"
        case (.sweetness, "uk"):  return "Солодкість"
        case (.sweetness, _):     return "Сладость"
        case (.acidity, "en"):    return "Acidity"
        case (.acidity, "pl"):    return "Kwasowość"
        case (.acidity, "uk"):    return "Кислотність"
        case (.acidity, _):       return "Кислотность"
        case (.bitterness, "en"): return "Bitterness"
        case (.bitterness, "pl"): return "Gorycz"
        case (.bitterness, "uk"): return "Гіркота"
        case (.bitterness, _):    return "Горечь"
        case (.umami, _):         return "Umami"
        case (.aroma, "en"):      return "Aroma"
        case (.aroma, "pl"):      return "Aromat"
        case (.aroma, "uk"):      return "Аромат"
        case (.aroma, _):         return "Аромат"
        case (.texture, "en"):    return "Texture"
        case (.texture, "pl"):    return "Tekstura"
        case (.texture, "uk"):    return "Текстура"
        case (.texture, _):       return "Текстура"

        // Food properties
        case (.gi, "en"):         return "Glycemic index"
        case (.gi, "pl"):         return "Indeks glikemiczny"
        case (.gi, "uk"):         return "Глікемічний індекс"
        case (.gi, _):            return "Гликемический индекс"
        case (.gl, "en"):         return "Glycemic load"
        case (.gl, "pl"):         return "Ładunek glikemiczny"
        case (.gl, "uk"):         return "Глікемічне навантаження"
        case (.gl, _):            return "Гликемическая нагрузка"
        case (.smokePoint, "en"): return "Smoke point"
        case (.smokePoint, "pl"): return "Temp. dymienia"
        case (.smokePoint, "uk"): return "Точка диму"
        case (.smokePoint, _):    return "Точка дыма"

        // Health
        case (.foodRole, "en"):           return "Food role"
        case (.foodRole, "pl"):           return "Rola żywieniowa"
        case (.foodRole, "uk"):           return "Харчова роль"
        case (.foodRole, _):              return "Пищевая роль"
        case (.bioactive, "en"):          return "Bioactive compounds"
        case (.bioactive, "pl"):          return "Związki bioaktywne"
        case (.bioactive, "uk"):          return "Біоактивні сполуки"
        case (.bioactive, _):             return "Биоактивные соединения"
        case (.healthEffects, "en"):      return "Health effects"
        case (.healthEffects, "pl"):      return "Efekty zdrowotne"
        case (.healthEffects, "uk"):      return "Ефекти для здоров'я"
        case (.healthEffects, _):         return "Эффекты для здоровья"
        case (.contraindications, "en"):  return "Contraindications"
        case (.contraindications, "pl"):  return "Przeciwwskazania"
        case (.contraindications, "uk"):  return "Протипоказання"
        case (.contraindications, _):     return "Противопоказания"
        case (.absorption, "en"):         return "Absorption notes"
        case (.absorption, "pl"):         return "Uwagi o wchłanianiu"
        case (.absorption, "uk"):         return "Примітки про засвоєння"
        case (.absorption, _):            return "Заметки о всасывании"

        // Sugar profile
        case (.glucose, "ru"):    return "Глюкоза"
        case (.glucose, "pl"):    return "Glukoza"
        case (.glucose, "uk"):    return "Глюкоза"
        case (.glucose, _):       return "Glucose"
        case (.fructose, "ru"):   return "Фруктоза"
        case (.fructose, "pl"):   return "Fruktoza"
        case (.fructose, "uk"):   return "Фруктоза"
        case (.fructose, _):      return "Fructose"
        case (.sucrose, "ru"):    return "Сахароза"
        case (.sucrose, "pl"):    return "Sacharoza"
        case (.sucrose, "uk"):    return "Сахароза"
        case (.sucrose, _):       return "Sucrose"
        case (.lactose, "ru"):    return "Лактоза"
        case (.lactose, "pl"):    return "Laktoza"
        case (.lactose, "uk"):    return "Лактоза"
        case (.lactose, _):       return "Lactose"
        case (.maltose, "ru"):    return "Мальтоза"
        case (.maltose, "pl"):    return "Maltoza"
        case (.maltose, "uk"):    return "Мальтоза"
        case (.maltose, _):       return "Maltose"
        case (.totalSugars, "en"):  return "Total sugars"
        case (.totalSugars, "pl"):  return "Cukry ogółem"
        case (.totalSugars, "uk"):  return "Загалом цукру"
        case (.totalSugars, _):     return "Сахара всего"
        case (.addedSugars, "en"):  return "Added sugars"
        case (.addedSugars, "pl"):  return "Cukry dodane"
        case (.addedSugars, "uk"):  return "Додані цукри"
        case (.addedSugars, _):     return "Добавленные сахара"
        case (.sugarAlcohols, "en"): return "Sugar alcohols"
        case (.sugarAlcohols, "pl"): return "Alkohole cukrowe"
        case (.sugarAlcohols, "uk"): return "Цукрові спирти"
        case (.sugarAlcohols, _):    return "Сахарные спирты"
        case (.sweetnessPerception, "en"): return "Sweetness perception"
        case (.sweetnessPerception, "pl"): return "Odczucie słodyczy"
        case (.sweetnessPerception, "uk"): return "Відчуття солодкості"
        case (.sweetnessPerception, _):    return "Восприятие сладости"

        // Processing
        case (.vitaminRetention, "en"): return "Vitamin retention"
        case (.vitaminRetention, "pl"): return "Retencja witamin"
        case (.vitaminRetention, "uk"): return "Збереження вітамінів"
        case (.vitaminRetention, _):    return "Сохранность витаминов"
        case (.maillard, "en"):         return "Maillard temp"
        case (.maillard, "pl"):         return "Temp. reakcji Maillarda"
        case (.maillard, "uk"):         return "Температура Маяра"
        case (.maillard, _):            return "Температура реакции Майяра"
        case (.proteinDenature, "en"):  return "Protein denature"
        case (.proteinDenature, "pl"):  return "Denaturacja białka"
        case (.proteinDenature, "uk"):  return "Денатурація білка"
        case (.proteinDenature, _):     return "Денатурация белка"
        case (.leaching, "en"):         return "Mineral leaching risk"
        case (.leaching, "pl"):         return "Ryzyko wypłukiwania minerałów"
        case (.leaching, "uk"):         return "Ризик вимивання мінералів"
        case (.leaching, _):            return "Риск вымывания минералов"
        case (.bestMethod, "en"):       return "Best method"
        case (.bestMethod, "pl"):       return "Najlepsza metoda"
        case (.bestMethod, "uk"):       return "Найкращий метод"
        case (.bestMethod, _):          return "Лучший метод"
        }
    }

    /// Mineral display helper — proxies through `sectionTitle(_:)`.
    func mineralName(_ k: SectionKey) -> String { sectionTitle(k) }
}
