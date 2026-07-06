import SwiftUI
import UIKit

struct TimerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = TimerViewModel()
    @State private var navigationPath: [TimerRoute] = []
    @State private var activeDurationEditor: DurationEditorMode?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            timerContent
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: TimerRoute.self) { route in
                    switch route {
                    case .settings:
                        SettingsView(
                            viewModel: viewModel,
                            onShowAdjustmentEditor: {
                                activeDurationEditor = .adjustment
                            }
                        )
                    }
                }
        }
        .sheet(item: $activeDurationEditor) { mode in
            DurationEntryView(
                heading: mode.heading,
                initialDigits: initialDigits(for: mode),
                onSave: { saveDuration($0, for: mode) },
                onCancel: {
                    activeDurationEditor = nil
                }
            )
            .presentationDetents([.height(580), .large])
        }
    }

    private var timerContent: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                topBar

                Spacer(minLength: 8)

                CircularTimerView(progress: viewModel.snapshot.visualProgress)
                    .frame(maxWidth: 288)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 24)

                countdownCapsule

                Spacer(minLength: 12)

                controls
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, 22)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, newPhase in
            UIApplication.shared.isIdleTimerDisabled = newPhase == .active
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                navigationPath.append(.settings)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(topBarForegroundColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")

            Spacer()

            Button {
                activeDurationEditor = .reset
            } label: {
                Text("Reset")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(topBarForegroundColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset timer")
        }
        .padding(.top, 8)
    }

    private var topBarForegroundColor: Color {
        colorScheme == .dark ? .white : .sneakyBlack
    }

    private var countdownCapsule: some View {
        Text(viewModel.countdownText)
            .font(.system(size: 24, weight: .regular, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(countdownForegroundColor)
            .padding(.horizontal, 34)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(countdownBackgroundColor)
                    .shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 12)
            )
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        viewModel.handleTimeDisplayPress()
                    }
                    .onEnded { _ in
                        viewModel.handleTimeDisplayRelease()
                    }
            )
            .animation(.easeInOut(duration: 0.16), value: viewModel.isShowingActualRemaining)
    }

    private var countdownForegroundColor: Color {
        viewModel.isShowingActualRemaining ? .white : .sneakyBlack
    }

    private var countdownBackgroundColor: Color {
        viewModel.isShowingActualRemaining ? .sneakyBlack : .sneakyCapsule
    }

    private var controls: some View {
        HStack(spacing: 22) {
            adjustmentButton(systemName: "minus", action: viewModel.subtractAdjustmentDuration)

            Button(action: viewModel.toggleRunning) {
                Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 90, height: 90)
                    .background(Circle().fill(Color.sneakyBlack))
                    .overlay(Circle().stroke(.white, lineWidth: 4))
                    .shadow(color: .black.opacity(0.16), radius: 22, x: 0, y: 11)
            }
            .accessibilityLabel(viewModel.isRunning ? "Pause timer" : "Start timer")

            adjustmentButton(systemName: "plus", action: viewModel.addAdjustmentDuration)
        }
    }

    private func adjustmentButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.sneakyBlack)
                .frame(width: 61, height: 61)
                .background(Circle().fill(.white))
                .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 10)
        }
        .accessibilityLabel(systemName == "plus" ? "Add time" : "Subtract time")
    }

    private func initialDigits(for mode: DurationEditorMode) -> String {
        switch mode {
        case .reset:
            viewModel.entryDefaultText
        case .adjustment:
            viewModel.adjustmentEntryDefaultText
        }
    }

    private func saveDuration(_ duration: TimeInterval, for mode: DurationEditorMode) {
        switch mode {
        case .reset:
            viewModel.save(duration: duration)
            navigationPath.removeAll()
        case .adjustment:
            viewModel.saveAdjustmentDuration(duration)
        }
        activeDurationEditor = nil
    }
}

#Preview {
    TimerView()
}

private enum TimerRoute: Hashable {
    case settings
}

private enum DurationEditorMode: Hashable, Identifiable {
    case reset
    case adjustment

    var id: Self { self }

    var heading: String {
        switch self {
        case .reset:
            "Initial timer duration"
        case .adjustment:
            "Timer adjustment (+/−)"
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var viewModel: TimerViewModel
    let onShowAdjustmentEditor: () -> Void

    var body: some View {
        Form {
            Section {
                Toggle("Hide adjusted time", isOn: $viewModel.hidesAdjustedTime)

                Button(action: onShowAdjustmentEditor) {
                    HStack {
                        Text("Timer adjustment (+/−)")
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(viewModel.adjustmentDisplayText)
                            .foregroundStyle(.secondary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Timer adjustment")
                .accessibilityValue(viewModel.adjustmentDisplayText)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
