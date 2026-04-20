import SwiftUI

struct CookModeView: View {
    let dish: APIClient.SuggestedDish
    let onComplete: () -> Void
    @EnvironmentObject var l10n: LocalizationService
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex = 0
    @State private var timerSeconds = 0
    @State private var timerRunning = false
    @State private var timer: Timer?
    @State private var showQuitConfirm = false

    private var steps: [APIClient.RecipeStep] { dish.steps }
    private var current: APIClient.RecipeStep? { steps.indices.contains(currentIndex) ? steps[currentIndex] : nil }
    private var isLast: Bool { currentIndex == steps.count - 1 }
    private var progress: Double { steps.isEmpty ? 0 : Double(currentIndex + 1) / Double(steps.count) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { showQuitConfirm = true } label: {
                        Image(systemName: "xmark").font(.title3.weight(.bold)).foregroundStyle(.white.opacity(0.7))
                            .frame(width: 40, height: 40).background(Color.white.opacity(0.1), in: Circle())
                    }
                    Spacer()
                    Text(dish.displayName ?? dish.dishNameLocal ?? dish.dishName)
                        .font(.subheadline.weight(.bold)).foregroundStyle(.white).lineLimit(1)
                    Spacer()
                    Text("\(currentIndex + 1)/\(steps.count)")
                        .font(.subheadline.weight(.bold)).foregroundStyle(.white.opacity(0.7))
                        .frame(width: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15))
                        Capsule().fill(Color.orange)
                            .frame(width: geo.size.width * progress)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }.frame(height: 4).padding(.horizontal, 20).padding(.top, 12)

                Spacer()

                // Step content
                if let step = current {
                    VStack(spacing: 24) {
                        // Step number
                        Text("\(step.step)")
                            .font(.system(size: 60, weight: .black, design: .rounded))
                            .foregroundStyle(.orange)

                        // Step text
                        Text(step.text)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        // Time & Temp
                        HStack(spacing: 20) {
                            if let time = step.timeMin {
                                VStack(spacing: 4) {
                                    Image(systemName: "clock.fill").font(.title2).foregroundStyle(.orange)
                                    Text("\(time) \(l10n.t("cook.min"))").font(.headline).foregroundStyle(.white)
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                            }
                            if let temp = step.tempC {
                                VStack(spacing: 4) {
                                    Image(systemName: "thermometer.medium").font(.title2).foregroundStyle(.red)
                                    Text("\(temp)°C").font(.headline).foregroundStyle(.white)
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                            }
                        }

                        // Timer
                        if step.timeMin != nil {
                            timerView(step: step)
                        }

                        // Tip
                        if let tip = step.tip {
                            HStack(spacing: 8) {
                                Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                                Text(tip).font(.subheadline).foregroundStyle(.white.opacity(0.7)).italic()
                            }
                            .padding(12)
                            .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 24)
                        }
                    }
                }

                Spacer()

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentIndex > 0 {
                        Button {
                            stopTimer()
                            withAnimation { currentIndex -= 1 }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text(l10n.t("cook.prevStep"))
                            }
                            .font(.headline).foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 24).padding(.vertical, 14)
                            .background(Color.white.opacity(0.1), in: Capsule())
                        }
                    }

                    Button {
                        stopTimer()
                        if isLast {
                            onComplete()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentIndex += 1
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(isLast ? l10n.t("cook.done") : l10n.t("cook.nextStep"))
                            Image(systemName: isLast ? "checkmark" : "chevron.right")
                        }
                        .font(.headline.weight(.bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isLast ? Color.green : Color.orange, in: Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .confirmationDialog(l10n.t("cook.quitCooking"), isPresented: $showQuitConfirm) {
            Button(l10n.t("cook.quit"), role: .destructive) { dismiss() }
            Button(l10n.t("cook.continueCooking"), role: .cancel) {}
        }
        .onDisappear { stopTimer() }
    }

    // MARK: - Timer

    @ViewBuilder
    private func timerView(step: APIClient.RecipeStep) -> some View {
        VStack(spacing: 8) {
            Text(timerString)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(timerRunning ? .orange : .white.opacity(0.5))
            HStack(spacing: 16) {
                Button {
                    if timerRunning { stopTimer() } else { startTimer(minutes: step.timeMin ?? 0) }
                } label: {
                    Image(systemName: timerRunning ? "pause.fill" : "play.fill")
                        .font(.title3).foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(timerRunning ? Color.orange : Color.white.opacity(0.15), in: Circle())
                }
                Button { timerSeconds = 0; stopTimer() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3).foregroundStyle(.white.opacity(0.5))
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
            }
        }
    }

    private var timerString: String {
        let m = timerSeconds / 60
        let s = timerSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func startTimer(minutes: Int) {
        if timerSeconds == 0 { timerSeconds = minutes * 60 }
        timerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timerSeconds > 0 {
                timerSeconds -= 1
            } else {
                stopTimer()
            }
        }
    }

    private func stopTimer() {
        timerRunning = false
        timer?.invalidate()
        timer = nil
    }
}
