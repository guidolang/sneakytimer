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
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 22)
                .padding(.top, 26)

            Text(formattedDigits)
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
                    Button {
                        entryBuffer.removeDigit()
                    } label: {
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
                Button("Save") {
                    onSave(TimerViewModel.duration(from: entryBuffer.digits))
                }
                .fontWeight(.semibold)
                .disabled(TimerViewModel.duration(from: entryBuffer.digits) <= 0)
            }
        }
        .background(Color(.systemBackground))
        .tint(Color.primary)
    }

    private var formattedDigits: String {
        entryBuffer.formattedDigits
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
            entryBuffer.appendDigit(value)
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
        if !hasEdited {
            digits = ""
            hasEdited = true
        }
        digits.append(value)
        digits = String(digits.suffix(6))
    }

    mutating func removeDigit() {
        if !hasEdited {
            digits = ""
            hasEdited = true
        }
        if !digits.isEmpty {
            digits.removeLast()
        }
    }
}

#Preview {
    DurationEntryView(heading: "Initial timer duration", initialDigits: "0100", onSave: { _ in }, onCancel: {})
}
