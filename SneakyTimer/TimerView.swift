import SwiftUI
import UIKit

struct TimerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = TimerViewModel()
    @State private var navigationPath: [TimerRoute] = []
    @State private var activeDurationEditor: DurationEditorMode?
    @State private var isShowingPositionEditor = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            timerContent
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: TimerRoute.self) { route in
                    switch route {
                    case .settings:
                        SettingsView(
                            viewModel: viewModel,
                            onShowDisplayedDurationEditor: {
                                activeDurationEditor = .displayedDuration
                            },
                            onShowAdjustmentEditor: {
                                activeDurationEditor = .adjustment
                            },
                            onShowPresetEditor: {
                                activeDurationEditor = .preset(index: $0)
                            },
                            onShowNewPresetEditor: {
                                activeDurationEditor = .newPreset
                            },
                            onShowPositionEditor: {
                                isShowingPositionEditor = true
                            },
                            onSelectPreset: {
                                viewModel.preparePresetTimer(at: $0)
                                navigationPath.removeAll()
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
        .sheet(isPresented: $isShowingPositionEditor) {
            PercentageEntryView(
                heading: "Timer position",
                initialDigits: viewModel.initialPositionEntryDefaultText,
                onSave: {
                    viewModel.saveInitialTimerPosition($0)
                    isShowingPositionEditor = false
                },
                onCancel: {
                    isShowingPositionEditor = false
                }
            )
            .presentationDetents([.height(580), .large])
        }
    }

    private var timerContent: some View {
        GeometryReader { geometry in
            let timerDiameter = timerDiameter(in: geometry.size)

            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 26) {
                    topBar

                    Spacer(minLength: 8)

                    CircularTimerView(
                        progress: viewModel.snapshot.visualProgress,
                        remainingColor: Color(timerColor: viewModel.timerColor)
                    )
                        .frame(width: timerDiameter, height: timerDiameter)

                    countdownCapsule

                    Spacer(minLength: 12)

                    controls
                        .padding(.bottom, 22)
                }
                .padding(.horizontal, 22)
            }
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
            Button(action: viewModel.resetToSelectedTimer) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(topBarForegroundColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset timer")

            Spacer()

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
        }
        .padding(.top, 8)
    }

    private var topBarForegroundColor: Color {
        colorScheme == .dark ? .white : .sneakyBlack
    }

    private func timerDiameter(in size: CGSize) -> CGFloat {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            return 288
        }

        return min(max(min(size.width, size.height) * 0.48, 320), 440)
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
        case .displayedDuration:
            viewModel.entryDefaultText
        case .adjustment:
            viewModel.adjustmentEntryDefaultText
        case .preset(let index):
            viewModel.presetEntryDefaultText(at: index)
        case .newPreset:
            ""
        }
    }

    private func saveDuration(_ duration: TimeInterval, for mode: DurationEditorMode) {
        switch mode {
        case .displayedDuration:
            viewModel.saveDisplayedDuration(duration)
        case .adjustment:
            viewModel.saveAdjustmentDuration(duration)
        case .preset(let index):
            viewModel.savePresetDuration(duration, at: index)
        case .newPreset:
            viewModel.addPresetDuration(duration)
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
    case displayedDuration
    case adjustment
    case preset(index: Int)
    case newPreset

    var id: Self { self }

    var heading: String {
        switch self {
        case .displayedDuration:
            "Duration"
        case .adjustment:
            "Timer adjustment (+/−)"
        case .preset, .newPreset:
            "Preset timer duration"
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var viewModel: TimerViewModel
    @State private var pendingPresetDeletion: PresetDeletionConfirmation?
    @State private var isShowingPresetDeletionAlert = false
    @State private var isShowingColorPicker = false
    let onShowDisplayedDurationEditor: () -> Void
    let onShowAdjustmentEditor: () -> Void
    let onShowPresetEditor: (Int) -> Void
    let onShowNewPresetEditor: () -> Void
    let onShowPositionEditor: () -> Void
    let onSelectPreset: (Int) -> Void

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            Form {
                Section {
                Button(action: onShowDisplayedDurationEditor) {
                    SettingsValueRow(
                        title: "Duration",
                        value: viewModel.displayedDurationDisplayText
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Duration")
                .accessibilityValue(viewModel.displayedDurationDisplayText)

                Button(action: onShowPositionEditor) {
                    SettingsValueRow(
                        title: "Timer position",
                        value: viewModel.initialPositionDisplayText
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Timer position")
                .accessibilityValue(viewModel.initialPositionDisplayText)

                Button(action: onShowAdjustmentEditor) {
                    SettingsValueRow(
                        title: "Timer adjustment (+/−)",
                        value: viewModel.adjustmentDisplayText
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Timer adjustment")
                .accessibilityValue(viewModel.adjustmentDisplayText)

                Toggle("Hide adjusted time", isOn: $viewModel.hidesAdjustedTime)

                LabeledContent("Background color") {
                    Button {
                        isShowingColorPicker = true
                    } label: {
                        BackgroundColorSelector(color: viewModel.timerColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Background color")
                    .accessibilityValue(viewModel.timerColor.hexString)
                    .popover(isPresented: $isShowingColorPicker) {
                        VStack(spacing: 12) {
                            SpectrumColorPicker(
                                initialColor: viewModel.timerColor,
                                onSelect: viewModel.saveTimerColor
                            )
                            .frame(height: 220)

                            Button("Reset") {
                                viewModel.saveTimerColor(.defaultRed)
                                isShowingColorPicker = false
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Reset background color")
                        }
                        .frame(width: 280)
                        .padding(12)
                        .presentationCompactAdaptation(.popover)
                    }
                }
                }

                Section("Preset timers") {
                    ForEach(viewModel.presetDurations.indices, id: \.self) { index in
                    PresetTimerRow(
                        durationText: viewModel.presetDisplayText(at: index),
                        onSelect: { onSelectPreset(index) },
                        onEdit: { onShowPresetEditor(index) },
                        onDelete: viewModel.canDeletePresetTimer ? {
                            pendingPresetDeletion = PresetDeletionConfirmation(
                                index: index,
                                durationText: viewModel.presetDisplayText(at: index)
                            )
                            isShowingPresetDeletionAlert = true
                        } : nil
                    )
                    }

                    if viewModel.canAddPresetTimer {
                        HStack {
                            Spacer()

                            Button(action: onShowNewPresetEditor) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Add preset timer")
                        }
                    }
                }
            }
            .frame(maxWidth: 600)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Do you want to delete the \(pendingPresetDeletion?.durationText ?? "") preset timer?",
            isPresented: $isShowingPresetDeletionAlert,
            presenting: pendingPresetDeletion
        ) { confirmation in
            Button("Delete", role: .destructive) {
                isShowingPresetDeletionAlert = false
                pendingPresetDeletion = nil
                viewModel.deletePresetDuration(at: confirmation.index)
            }

            Button("Cancel", role: .cancel) {
                isShowingPresetDeletionAlert = false
                pendingPresetDeletion = nil
            }
        }
    }
}

private struct BackgroundColorSelector: View {
    let color: TimerColor

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(timerColor: color))
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(.secondary.opacity(0.35), lineWidth: 1))

            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct SpectrumColorPicker: View {
    @State private var selection: UnitPoint
    let onSelect: (TimerColor) -> Void

    init(initialColor: TimerColor, onSelect: @escaping (TimerColor) -> Void) {
        _selection = State(initialValue: Self.selectionPoint(for: initialColor))
        self.onSelect = onSelect
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .clear, location: 0.5),
                            .init(color: .black, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                Circle()
                    .stroke(.white, lineWidth: 3)
                    .background(Circle().stroke(.black.opacity(0.35), lineWidth: 5))
                    .frame(width: 24, height: 24)
                    .position(
                        x: 12 + selection.x * max(geometry.size.width - 24, 0),
                        y: 12 + selection.y * max(geometry.size.height - 24, 0)
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        select(at: value.location, in: geometry.size)
                    }
            )
        }
        .accessibilityLabel("Color spectrum")
    }

    private func select(at location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let x = min(max(location.x / size.width, 0), 1)
        let y = min(max(location.y / size.height, 0), 1)
        selection = UnitPoint(x: x, y: y)

        let saturation: CGFloat
        let brightness: CGFloat
        if y <= 0.5 {
            saturation = y * 2
            brightness = 1
        } else {
            saturation = 1
            brightness = (1 - y) * 2
        }

        if let color = TimerColor(
            uiColor: UIColor(hue: x, saturation: saturation, brightness: brightness, alpha: 1)
        ) {
            onSelect(color)
        }
    }

    private static func selectionPoint(for color: TimerColor) -> UnitPoint {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(timerColor: color).getHue(
            &hue,
            saturation: &saturation,
            brightness: &brightness,
            alpha: &alpha
        ) else {
            return .center
        }

        let y = brightness < 0.999 ? 0.5 + (1 - brightness) / 2 : saturation / 2
        return UnitPoint(x: hue, y: y)
    }
}

private extension TimerColor {
    init?(uiColor: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        self.init(
            red: UInt8((red * 255).rounded()),
            green: UInt8((green * 255).rounded()),
            blue: UInt8((blue * 255).rounded())
        )
    }
}

private extension UIColor {
    convenience init(timerColor: TimerColor) {
        self.init(
            red: CGFloat(timerColor.red) / 255,
            green: CGFloat(timerColor.green) / 255,
            blue: CGFloat(timerColor.blue) / 255,
            alpha: 1
        )
    }
}

private struct PresetDeletionConfirmation {
    let index: Int
    let durationText: String
}

private struct PresetTimerRow: View {
    let durationText: String
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                Text(durationText)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Set timer to \(durationText)")

            Button(action: onEdit) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Edit \(durationText) preset")

            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.red)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete \(durationText) preset")
            }
        }
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }
}
