//
//  ProwlStatsCharts.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import SwiftUI
import ProwlCore

struct ProwlStatsCharts: View {
    let stats: ProwlRequestStats

    private struct Slice: Identifiable {
        let id: String
        let label: String
        let value: Int
        let color: Color
    }

    private var slices: [Slice] {
        [
            Slice(id: "2xx", label: "2xx", value: stats.success2xx, color: Color(red: 0.20, green: 0.78, blue: 0.35)),
            Slice(id: "3xx", label: "3xx", value: stats.redirect3xx, color: Color(red: 0.0, green: 0.48, blue: 1.0)),
            Slice(id: "4xx", label: "4xx", value: stats.client4xx, color: Color(red: 1.0, green: 0.58, blue: 0.0)),
            Slice(id: "5xx", label: "5xx", value: stats.server5xx, color: Color(red: 1.0, green: 0.23, blue: 0.19)),
            Slice(id: "other", label: "Other", value: stats.other, color: .secondary),
        ].filter { $0.value > 0 }
    }

    var body: some View {
        if stats.total == 0 {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 22) {
                metricsRow
                if !slices.isEmpty {
                    statusSection
                }
                if !stats.methodCounts.isEmpty {
                    methodSection
                }
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No Traffic Yet")
                .font(.subheadline.weight(.semibold))
            Text("Captured requests will appear here with status and method breakdowns.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Metrics

    private var metricsRow: some View {
        HStack(spacing: 10) {
            metricTile(
                value: "\(stats.total)",
                label: ProwlStrings.totalRequests,
                symbol: "arrow.left.arrow.right",
                tint: Color(red: 0.0, green: 0.48, blue: 1.0)
            )
            metricTile(
                value: String(format: "%.0f", stats.avgDurationMs),
                label: ProwlStrings.avgDuration,
                symbol: "clock.fill",
                tint: Color(red: 1.0, green: 0.58, blue: 0.0)
            )
            metricTile(
                value: "\(stats.successRatePercent)%",
                label: ProwlStrings.successRate,
                symbol: "checkmark.circle.fill",
                tint: Color(red: 0.20, green: 0.78, blue: 0.35)
            )
        }
    }

    private func metricTile(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        }
    }

    // MARK: - Status donut

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(ProwlStrings.statusDistribution)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    donutChart
                    VStack(spacing: 2) {
                        Text("\(stats.successRatePercent)%")
                            .font(.title2.weight(.bold).monospacedDigit())
                        Text("2xx")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 132, height: 132)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(slices) { slice in
                        statusLegendRow(slice)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func statusLegendRow(_ slice: Slice) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(slice.color)
                .frame(width: 12, height: 12)
            Text(slice.label)
                .font(.caption.weight(.semibold).monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            GeometryReader { geo in
                let total = max(slices.map(\.value).reduce(0, +), 1)
                let fraction = CGFloat(slice.value) / CGFloat(total)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(slice.color.opacity(0.85))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
            Text("\(slice.value)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private var donutChart: some View {
        Canvas { context, size in
            let total = max(slices.map(\.value).reduce(0, +), 1)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerRadius = min(size.width, size.height) / 2
            let innerRadius = outerRadius * 0.62
            let gapDegrees = slices.count > 1 ? 2.5 : 0.0
            var startAngle = Angle.degrees(-90)

            for slice in slices {
                let sweepDegrees = 360 * Double(slice.value) / Double(total) - gapDegrees
                guard sweepDegrees > 0 else { continue }
                let sweep = Angle.degrees(sweepDegrees)
                let endAngle = startAngle + sweep

                var path = Path()
                path.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
                path.closeSubpath()
                context.fill(path, with: .color(slice.color))
                startAngle = endAngle + Angle.degrees(gapDegrees)
            }
        }
    }

    // MARK: - Methods

    private var methodSection: some View {
        let topMethods = stats.methodCounts.sorted { $0.value > $1.value }.prefix(6)
        let maxCount = max(topMethods.map(\.value).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 14) {
            Text(ProwlStrings.methodBreakdown)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(Array(topMethods), id: \.key) { method, count in
                    methodRow(method: method, count: count, maxCount: maxCount)
                }
            }
        }
    }

    private func methodRow(method: String, count: Int, maxCount: Int) -> some View {
        let tint = methodColor(method)
        return HStack(spacing: 10) {
            Text(method.uppercased())
                .font(.caption2.weight(.bold).monospaced())
                .foregroundStyle(tint)
                .frame(width: 52, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.9), tint.opacity(0.55)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxCount))
                }
            }
            .frame(height: 8)
            Text("\(count)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET": return Color(red: 0.0, green: 0.48, blue: 1.0)
        case "POST": return Color(red: 0.20, green: 0.78, blue: 0.35)
        case "PUT", "PATCH": return Color(red: 1.0, green: 0.58, blue: 0.0)
        case "DELETE": return Color(red: 1.0, green: 0.23, blue: 0.19)
        default: return Color(red: 0.424, green: 0.361, blue: 0.906)
        }
    }
}
