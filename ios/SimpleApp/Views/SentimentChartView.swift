import SwiftUI
import Charts

struct SentimentChartView: View {
    let priceHistory: [PricePoint]
    let timeRange: TimeRange
    @State private var selectedPoint: PricePoint?

    private var filteredData: [PricePoint] {
        switch timeRange {
        case .oneHour: return Array(priceHistory.suffix(max(2, priceHistory.count / 10)))
        case .oneDay: return Array(priceHistory.suffix(24))
        case .oneWeek: return priceHistory
        case .oneMonth: return priceHistory
        case .all: return priceHistory
        }
    }

    private var believeColor: Color { Color(red: 0.13, green: 0.78, blue: 0.45) }
    private var doubtColor: Color { Color(red: 0.95, green: 0.25, blue: 0.3) }

    private var displayPoint: PricePoint? {
        selectedPoint ?? filteredData.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            priceHeader

            chartBody
                .frame(height: 200)

            legendRow
        }
    }

    private var priceHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            if let point = displayPoint {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 16) {
                        HStack(spacing: 5) {
                            Circle().fill(believeColor).frame(width: 8, height: 8)
                            Text(String(format: "%.1f¢", point.believePrice * 100))
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(believeColor)
                        }
                        HStack(spacing: 5) {
                            Circle().fill(doubtColor).frame(width: 8, height: 8)
                            Text(String(format: "%.1f¢", point.doubtPrice * 100))
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(doubtColor)
                        }
                    }
                    if selectedPoint != nil {
                        Text(point.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var chartBody: some View {
        Chart {
            ForEach(Array(filteredData.enumerated()), id: \.element.id) { index, point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Believe", point.believePrice * 100),
                    series: .value("Side", "Believe")
                )
                .foregroundStyle(believeColor)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Start", yDomain.lowerBound),
                    yEnd: .value("Believe", point.believePrice * 100),
                    series: .value("Side", "Believe")
                )
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: believeColor.opacity(0.25), location: 0),
                            .init(color: believeColor.opacity(0.08), location: 0.5),
                            .init(color: believeColor.opacity(0.0), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Doubt", point.doubtPrice * 100),
                    series: .value("Side", "Doubt")
                )
                .foregroundStyle(doubtColor)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                AreaMark(
                    x: .value("Time", point.date),
                    yStart: .value("Start", yDomain.lowerBound),
                    yEnd: .value("Doubt", point.doubtPrice * 100),
                    series: .value("Side", "Doubt")
                )
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: doubtColor.opacity(0.2), location: 0),
                            .init(color: doubtColor.opacity(0.05), location: 0.5),
                            .init(color: doubtColor.opacity(0.0), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }

            if let point = displayPoint {
                RuleMark(x: .value("Selected", point.date))
                    .foregroundStyle(Color.white.opacity(selectedPoint != nil ? 0.15 : 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                PointMark(
                    x: .value("Time", point.date),
                    y: .value("Believe", point.believePrice * 100)
                )
                .foregroundStyle(believeColor)
                .symbolSize(selectedPoint != nil ? 60 : 30)
                .symbol {
                    Circle()
                        .fill(believeColor)
                        .frame(width: selectedPoint != nil ? 8 : 6, height: selectedPoint != nil ? 8 : 6)
                        .shadow(color: believeColor.opacity(0.6), radius: 4)
                }

                PointMark(
                    x: .value("Time", point.date),
                    y: .value("Doubt", point.doubtPrice * 100)
                )
                .foregroundStyle(doubtColor)
                .symbolSize(selectedPoint != nil ? 60 : 30)
                .symbol {
                    Circle()
                        .fill(doubtColor)
                        .frame(width: selectedPoint != nil ? 8 : 6, height: selectedPoint != nil ? 8 : 6)
                        .shadow(color: doubtColor.opacity(0.6), radius: 4)
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .trailing, values: yAxisValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3, 4]))
                    .foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel(anchor: .leading) {
                    if let intVal = value.as(Int.self) {
                        Text("\(intVal)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                    .foregroundStyle(.clear)
                AxisValueLabel(format: xAxisFormat)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let x = value.location.x - geo[plotFrame].origin.x
                                guard let date: Date = proxy.value(atX: x) else { return }
                                let closest = filteredData.min(by: {
                                    abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                })
                                if selectedPoint?.id != closest?.id {
                                    selectedPoint = closest
                                }
                            }
                            .onEnded { _ in
                                selectedPoint = nil
                            }
                    )
            }
        }
    }

    private var legendRow: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(believeColor)
                    .frame(width: 16, height: 3)
                Text("Believe")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(doubtColor)
                    .frame(width: 16, height: 3)
                Text("Doubt")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var yDomain: ClosedRange<Double> {
        guard !filteredData.isEmpty else { return 0...100 }
        let allVals = filteredData.flatMap { [$0.believePrice * 100, $0.doubtPrice * 100] }
        let minVal = (allVals.min() ?? 0)
        let maxVal = (allVals.max() ?? 100)
        let padding = max((maxVal - minVal) * 0.15, 3)
        return max(0, minVal - padding)...min(100, maxVal + padding)
    }

    private var yAxisValues: [Int] {
        let lower = Int(yDomain.lowerBound)
        let upper = Int(yDomain.upperBound)
        let range = upper - lower
        let step = max(1, range / 4)
        return stride(from: lower, through: upper, by: step).map { $0 }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch timeRange {
        case .oneHour, .oneDay:
            return .dateTime.hour().minute()
        case .oneWeek:
            return .dateTime.weekday(.abbreviated)
        case .oneMonth, .all:
            return .dateTime.month(.abbreviated).day()
        }
    }
}
