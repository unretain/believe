import SwiftUI

struct BeliefGaugeView: View {
    let percentage: Int
    let size: CGFloat

    private var progress: Double {
        Double(percentage) / 100.0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: size * 0.06)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [.green, .green.opacity(0.8)],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: progress, to: 1.0)
                .stroke(
                    Color.red.opacity(0.4),
                    style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(percentage)%")
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                Text("BELIEF")
                    .font(.system(size: size * 0.1, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
