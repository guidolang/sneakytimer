import SwiftUI

struct CircularTimerView: View {
    var progress: Double

    private var elapsedFraction: Double {
        min(max(1 - progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let pointerAngle = Angle.degrees(-90 + elapsedFraction * 360)

            ZStack {
                Circle()
                    .fill(Color.sneakyRed)
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 7)

                PieSlice(fraction: elapsedFraction)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 2)

                pointer(size: size, angle: pointerAngle)

                Circle()
                    .fill(Color.sneakyBlack)
                    .frame(width: size * 0.105, height: size * 0.105)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func pointer(size: CGFloat, angle: Angle) -> some View {
        Capsule()
            .fill(Color.sneakyBlack)
            .frame(width: size * 0.085, height: size * 0.018)
            .offset(x: size * 0.045)
            .rotationEffect(angle)
    }
}

private struct PieSlice: Shape {
    var fraction: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard fraction > 0 else { return path }

        let clampedFraction = min(max(fraction, 0), 1)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let start = Angle.degrees(-90)
        let end = Angle.degrees(-90 + clampedFraction * 360)

        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()

        return path
    }
}

extension Color {
    static let sneakyRed = Color(red: 0.91, green: 0.02, blue: 0.16)
    static let sneakyBlack = Color(red: 0.17, green: 0.17, blue: 0.17)
    static let sneakyCapsule = Color(red: 0.94, green: 0.94, blue: 0.94)
}

#Preview {
    CircularTimerView(progress: 0.85)
        .frame(width: 360, height: 360)
        .padding()
}
