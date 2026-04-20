//
//  ProfileView.swift
//  ChefOS
//

import SwiftUI

// MARK: - Features/Profile

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var regionService: RegionService
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var l10n: LocalizationService
    @State private var appeared = false
    @State private var showCountryPicker = false
    @State private var showPhotoPicker = false
    @State private var avatarImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.screenBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        avatarHeader
                            .staggerIn(appeared: appeared, delay: 0)

                        goalsCard
                            .staggerIn(appeared: appeared, delay: 0.05)

                        personalInfoCard
                            .staggerIn(appeared: appeared, delay: 0.1)

                        preferencesCard
                            .staggerIn(appeared: appeared, delay: 0.15)

                        restrictionsCard
                            .staggerIn(appeared: appeared, delay: 0.2)

                        lifestyleCard
                            .staggerIn(appeared: appeared, delay: 0.25)

                        aiSummaryCard
                            .staggerIn(appeared: appeared, delay: 0.3)

                        regionCard
                            .staggerIn(appeared: appeared, delay: 0.35)

                        logoutButton
                            .staggerIn(appeared: appeared, delay: 0.4)
                    }
                    .padding()
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle(l10n.t("profile.title"))
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .overlay(alignment: .bottom) {
                if viewModel.autoSaved {
                    autoSavedBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    appeared = true
                }
                Task {
                    await viewModel.load()
                    if !viewModel.language.isEmpty {
                        l10n.language = viewModel.language
                    }
                }
            }
            .onChange(of: viewModel.language) { _, newValue in
                guard !viewModel.isLoading, !newValue.isEmpty else { return }
                l10n.language = newValue
                viewModel.updateLanguage(newValue)
            }
        }
    }

    // MARK: - Avatar

    private var avatarHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.orange.opacity(0.25))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)

                if let url = viewModel.avatarUrl, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        default:
                            avatarPlaceholder
                        }
                    }
                } else {
                    avatarPlaceholder
                }
            }
            .shadow(color: .orange.opacity(0.5), radius: 20, y: 4)
            .onTapGesture { showPhotoPicker = true }

            TextField(l10n.t("onboarding.name"), text: $viewModel.profile.name)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            if !viewModel.email.isEmpty {
                Text(viewModel.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
        .sheet(isPresented: $showPhotoPicker) {
            ImagePicker(image: $avatarImage, sourceType: .photoLibrary)
        }
        .onChange(of: avatarImage) { _, newImage in
            if let image = newImage {
                Task { await viewModel.uploadAvatar(image: image) }
                avatarImage = nil
            }
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(LinearGradient.userBubble)
            .frame(width: 80, height: 80)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .overlay(
                Image(systemName: "person.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
            )
    }

    // MARK: - Personal Info

    private var personalInfoCard: some View {
        ProfileSection(title: l10n.t("profile.personalInfo"), icon: "person.text.rectangle") {
            ProfileField(l10n.t("profile.age")) {
                TextField("25", text: $viewModel.ageText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            ProfileField(l10n.t("profile.weight")) {
                TextField("70", text: $viewModel.weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Goals

    private var goalsCard: some View {
        ProfileSection(title: l10n.t("profile.goals"), icon: "target", emphasis: true) {
            ProfileField(l10n.t("profile.goal")) {
                Picker("", selection: $viewModel.profile.goal) {
                    ForEach(UserProfile.FitnessGoal.allCases) { g in
                        Text(l10n.t(g.l10nKey)).tag(g)
                    }
                }
                .labelsHidden()
                .tint(.orange)
            }
            ProfileField(l10n.t("profile.targetWeight")) {
                TextField("65", text: $viewModel.targetWeightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            ProfileField(l10n.t("profile.caloriesDay")) {
                TextField("2200", text: $viewModel.calorieText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            ProfileField(l10n.t("profile.protein")) {
                TextField("120", text: $viewModel.proteinText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - Preferences

    private var preferencesCard: some View {
        ProfileSection(title: l10n.t("profile.preferences"), icon: "fork.knife") {
            ProfileField(l10n.t("profile.diet")) {
                Picker("", selection: $viewModel.profile.diet) {
                    ForEach(UserProfile.DietType.allCases) { d in
                        Text(l10n.t(d.l10nKey)).tag(d)
                    }
                }
                .labelsHidden()
                .tint(.orange)
            }
            ProfileField(l10n.t("profile.cuisine")) {
                Picker("", selection: $viewModel.profile.preferredCuisine) {
                    ForEach(UserProfile.CuisineType.allCases) { c in
                        Text(l10n.t(c.l10nKey)).tag(c)
                    }
                }
                .labelsHidden()
                .tint(.orange)
            }

            TagEditor(
                title: l10n.t("profile.likes"),
                tags: viewModel.profile.likes,
                input: $viewModel.newLike,
                placeholder: l10n.t("tags.addLikes"),
                color: .green
            ) { tag in
                viewModel.addTag(to: \.likes, value: tag)
                viewModel.newLike = ""
            } onRemove: { tag in
                viewModel.removeTag(from: \.likes, value: tag)
            }

            TagEditor(
                title: l10n.t("profile.dislikes"),
                tags: viewModel.profile.dislikes,
                input: $viewModel.newDislike,
                placeholder: l10n.t("tags.addDislikes"),
                color: .red
            ) { tag in
                viewModel.addTag(to: \.dislikes, value: tag)
                viewModel.newDislike = ""
            } onRemove: { tag in
                viewModel.removeTag(from: \.dislikes, value: tag)
            }
        }
    }

    // MARK: - Restrictions

    private var restrictionsCard: some View {
        ProfileSection(title: l10n.t("profile.restrictions"), icon: "exclamationmark.shield") {
            TagEditor(
                title: l10n.t("profile.allergies"),
                tags: viewModel.profile.allergies,
                input: $viewModel.newAllergy,
                placeholder: l10n.t("tags.addAllergies"),
                color: .orange
            ) { tag in
                viewModel.addTag(to: \.allergies, value: tag)
                viewModel.newAllergy = ""
            } onRemove: { tag in
                viewModel.removeTag(from: \.allergies, value: tag)
            }

            TagEditor(
                title: l10n.t("profile.conditions"),
                tags: viewModel.profile.medicalConditions,
                input: $viewModel.newCondition,
                placeholder: l10n.t("tags.addConditions"),
                color: .purple
            ) { tag in
                viewModel.addTag(to: \.medicalConditions, value: tag)
                viewModel.newCondition = ""
            } onRemove: { tag in
                viewModel.removeTag(from: \.medicalConditions, value: tag)
            }
        }
    }

    // MARK: - Lifestyle

    private var lifestyleCard: some View {
        ProfileSection(title: l10n.t("profile.lifestyle"), icon: "clock") {
            ProfileField(l10n.t("profile.cookingLevel")) {
                Picker("", selection: $viewModel.profile.cookingLevel) {
                    ForEach(UserProfile.CookingLevel.allCases) { l in
                        Text(l10n.t(l.l10nKey)).tag(l)
                    }
                }
                .labelsHidden()
                .tint(.orange)
            }
            ProfileField(l10n.t("profile.cookingTime")) {
                Picker("", selection: $viewModel.profile.cookingTime) {
                    ForEach(UserProfile.CookingTime.allCases) { t in
                        Text(l10n.t(t.l10nKey)).tag(t)
                    }
                }
                .labelsHidden()
                .tint(.orange)
            }
            ProfileField(l10n.t("profile.mealsDay")) {
                TextField("3", text: $viewModel.mealsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - AI Summary

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .symbolEffect(.pulse, options: .repeating)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t("profile.aiTitle"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(l10n.t("profile.aiSubtitle"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider().overlay(Color.white.opacity(0.08))

            Text(viewModel.profile.localizedAiSummary(l10n))
                .font(.callout)
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(5)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.18), Color.cyan.opacity(0.1), Color.purple.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.cyan.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .purple.opacity(0.2), radius: 16, y: 6)
    }

    // MARK: - Region

    private var regionCard: some View {
        ProfileSection(title: l10n.t("profile.region"), icon: "globe") {
            Button {
                showCountryPicker = true
            } label: {
                HStack {
                    Text(l10n.t("profile.country"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Spacer()
                    Text("\(regionService.countryFlag) \(regionService.countryName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
            }

            Divider().overlay(Color.white.opacity(0.04))

            HStack {
                Text(l10n.t("profile.currency"))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer()
                Text(regionService.currency)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            Divider().overlay(Color.white.opacity(0.04))

            HStack {
                Text(l10n.t("profile.language"))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $viewModel.language) {
                    Text("🇬🇧 English").tag("en")
                    Text("🇵🇱 Polski").tag("pl")
                    Text("🇷🇺 Русский").tag("ru")
                    Text("🇺🇦 Українська").tag("uk")
                }
                .pickerStyle(.menu)
                .tint(.orange)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            Divider().overlay(Color.white.opacity(0.04))

            HStack {
                Text(l10n.t("profile.security"))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: authService.biometricIcon)
                        .font(.caption)
                    Text(authService.biometricLabel)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.cyan)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
        .sheet(isPresented: $showCountryPicker) {
            NavigationStack {
                CountryPickerView(regionService: regionService)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(l10n.t("onboarding.done")) { showCountryPicker = false }
                                .foregroundStyle(.orange)
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Logout

    private var logoutButton: some View {
        Button {
            authService.logout()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline)
                Text(l10n.t("profile.signOut"))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.red.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.red.opacity(0.12), lineWidth: 1)
            )
        }
    }

    // MARK: - Auto-save Banner

    private var autoSavedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
            Text(l10n.t("profile.autoSaved"))
                .fontWeight(.medium)
        }
        .font(.subheadline)
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .padding(.bottom, 16)
    }
}

// MARK: - Reusable Components

struct ProfileSection<Content: View>: View {
    let title: String
    let icon: String
    var emphasis: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(emphasis ? .orange : .secondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(emphasis ? .white.opacity(0.9) : .secondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
            .glassCard(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(emphasis ? 0.12 : 0.05), lineWidth: 0.5)
            )
        }
    }
}

struct ProfileField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer()
                content
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .tint(.orange)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            Divider().overlay(Color.white.opacity(0.04))
        }
    }
}

struct TagEditor: View {
    let title: String
    let tags: [String]
    @Binding var input: String
    var placeholder: String = ""
    var color: Color = .orange
    var onAdd: (String) -> Void
    var onRemove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 10)

            // Tags
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.caption.weight(.medium))
                            Button {
                                onRemove(tag)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .foregroundStyle(color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.12), in: Capsule())
                    }
                }
                .padding(.horizontal, 14)
            }

            // Input
            HStack(spacing: 8) {
                TextField(placeholder.isEmpty ? title : placeholder, text: $input)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .onSubmit {
                        onAdd(input)
                    }
                if !input.isEmpty {
                    Button {
                        onAdd(input)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(color)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Flow Layout (tag wrapping)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxWidth = max(maxWidth, x)
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

// MARK: - Stagger Entrance Animation

extension View {
    func staggerIn(appeared: Bool, delay: Double) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.easeOut(duration: 0.4).delay(delay), value: appeared)
    }
}

#Preview {
    ProfileView()
        .environmentObject(RegionService())
        .environmentObject(AuthService())
        .environmentObject(LocalizationService())
        .preferredColorScheme(.dark)
}
