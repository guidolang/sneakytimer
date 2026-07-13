import SwiftUI

struct DurationEntryView: View {
    @State private var entryBuffer: DurationEntryBuffer

    let heading: String
    let onSave: (TimeInterval) -> Void
    let onCancel: () -> Void
    private let embedsInNavigationStack: Bool

    init(
        heading: String,
        initialDigits: String,
        embedsInNavigationStack: Bool = true,
        onSave: @escaping (TimeInterval) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.heading = heading
        _entryBuffer = State(initialValue: DurationEntryBuffer(initialDigits: initialDigits))
        self.embedsInNavigationStack = embedsInNavigationStack
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NumericKeypadEditor(
            heading: heading,
            displayText: entryBuffer.formattedDigits,
            isSaveEnabled: enteredDuration > 0,
            embedsInNavigationStack: embedsInNavigationStack,
            onDigit: { entryBuffer.appendDigit($0) },
            onDelete: { entryBuffer.removeDigit() },
            onSave: { onSave(enteredDuration) },
            onCancel: onCancel
        )
    }

    private var enteredDuration: TimeInterval {
        TimerFormatting.duration(from: entryBuffer.digits)
    }
}

struct DurationEntryBuffer: Equatable {
    private(set) var digits: String
    private var hasEdited = false

    var formattedDigits: String {
        let rawDigits = String(digits.suffix(6))
        let padded = String(repeating: "0", count: max(0, 6 - rawDigits.count)) + rawDigits
        let hours = padded.prefix(2)
        let minutes = padded.dropFirst(2).prefix(2)
        let seconds = padded.suffix(2)
        return "\(hours) : \(minutes) : \(seconds)"
    }

    init(initialDigits: String) {
        digits = String(initialDigits.suffix(6))
    }

    mutating func appendDigit(_ value: String) {
        guard value.count == 1, value.allSatisfy(\.isNumber) else { return }
        prepareForFirstEdit()
        digits.append(value)
        digits = String(digits.suffix(6))
    }

    mutating func removeDigit() {
        prepareForFirstEdit()
        if !digits.isEmpty {
            digits.removeLast()
        }
    }

    private mutating func prepareForFirstEdit() {
        if !hasEdited {
            digits = ""
            hasEdited = true
        }
    }
}

struct PercentageEntryView: View {
    @State private var entryBuffer: PercentageEntryBuffer

    let heading: String
    let onSave: (Int) -> Void
    let onCancel: () -> Void

    init(
        heading: String,
        initialDigits: String,
        onSave: @escaping (Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.heading = heading
        _entryBuffer = State(initialValue: PercentageEntryBuffer(initialDigits: initialDigits))
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NumericKeypadEditor(
            heading: heading,
            displayText: entryBuffer.displayText,
            isSaveEnabled: entryBuffer.validPosition != nil,
            onDigit: { entryBuffer.appendDigit($0) },
            onDelete: { entryBuffer.removeDigit() },
            onSave: {
                if let position = entryBuffer.validPosition {
                    onSave(position)
                }
            },
            onCancel: onCancel
        )
    }
}

struct PercentageEntryBuffer: Equatable {
    private(set) var digits: String
    private var hasEdited = false

    var displayText: String {
        "\(digits.isEmpty ? "0" : digits)%"
    }

    var validPosition: Int? {
        TimerFormatting.timerPosition(from: digits)
    }

    init(initialDigits: String) {
        digits = String(initialDigits.prefix(3).filter(\.isNumber))
    }

    mutating func appendDigit(_ value: String) {
        guard value.count == 1, value.allSatisfy(\.isNumber) else { return }
        prepareForFirstEdit()
        guard digits.count < 3 else { return }
        digits.append(value)
    }

    mutating func removeDigit() {
        prepareForFirstEdit()
        if !digits.isEmpty {
            digits.removeLast()
        }
    }

    private mutating func prepareForFirstEdit() {
        if !hasEdited {
            digits = ""
            hasEdited = true
        }
    }
}

private struct NumericKeypadEditor: View {
    let heading: String
    let displayText: String
    let isSaveEnabled: Bool
    var embedsInNavigationStack = true
    let onDigit: (String) -> Void
    let onDelete: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        if embedsInNavigationStack {
            NavigationStack {
                content
            }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 22) {
            Text(heading)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 22)
                .padding(.top, 26)

            Text(displayText)
                .font(.system(size: 46, weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                keypadRow(["1", "2", "3"])
                keypadRow(["4", "5", "6"])
                keypadRow(["7", "8", "9"])

                HStack(spacing: 12) {
                    keypadSpacer
                    keypadButton("0")
                    Button(action: onDelete) {
                        Image(systemName: "delete.left")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 22)

            Spacer(minLength: 0)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: onSave)
                    .fontWeight(.semibold)
                    .disabled(!isSaveEnabled)
            }
        }
        .background(Color(.systemBackground))
        .tint(Color.primary)
    }

    private var keypadSpacer: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 58)
    }

    private func keypadRow(_ values: [String]) -> some View {
        HStack(spacing: 12) {
            ForEach(values, id: \.self) { value in
                keypadButton(value)
            }
        }
    }

    private func keypadButton(_ value: String) -> some View {
        Button {
            onDigit(value)
        } label: {
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

#Preview {
    DurationEntryView(heading: "Initial timer duration", initialDigits: "0100", onSave: { _ in }, onCancel: {})
}
