import SwiftUI

struct MarketCardView: View {
    let market: Market
    let viewModel: MarketViewModel

    var body: some View {
        HStack(spacing: 14) {
            Color(.secondarySystemBackground)
                .frame(width: 56, height: 56)
                .overlay {
                    AsyncImage(url: URL(string: market.avatarURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(market.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)

                    if market.isTrending {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Text(market.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(market.believePercentage)%")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)

                if market.change24h != 0 {
                    Text(String(format: "%+.1f%%", market.change24h))
                        .font(.caption)
                        .foregroundStyle(market.change24h >= 0 ? .green : .red)
                } else {
                    Text("50/50")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            MiniGaugeView(percentage: market.believePercentage)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}

struct MiniGaugeView: View {
    let percentage: Int

    private var progress: Double {
        Double(percentage) / 100.0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.red.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 32, height: 32)
    }
}
