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
            Slice(id: "2xx", label: "2xx", value: stats.success2xx, color: .green),
            Slice(id: "3xx", label: "3xx", value: stats.redirect3xx, color: .blue),
            Slice(id: "4xx", label: "4xx", value: stats.client4xx, color: .orange),
            Slice(id: "5xx", label: "5xx", value: stats.server5xx, color: .red),
            Slice(id: "other", label: "Other", value: stats.other, color: .gray),
        ].filter { $0.value > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                statPill(title: ProwlStrings.totalRequests, value: "\(stats.total)")
                statPill(title: ProwlStrings.avgDuration, value: String(format: "%.0f ms", stats.avgDurationMs))
                statPill(title: ProwlStrings.successRate, value: "\(stats.successRatePercent)%")
            }

            if !slices.isEmpty {
                Text(ProwlStrings.statusDistribution)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 16) {
                    donutChart
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(slices) { slice in
                            HStack(spacing: 6) {
                                Circle().fill(slice.color).frame(width: 8, height: 8)
                                Text("\(slice.label): \(slice.value)")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            if !stats.methodCounts.isEmpty {
                Text(ProwlStrings.methodBreakdown)
                    .font(.subheadline.weight(.semibold))
                methodBarChart
            }
        }
    }

    private var donutChart: some View {
        Canvas { context, size in
            let total = max(slices.map(\.value).reduce(0, +), 1)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            var startAngle = Angle.degrees(-90)
            for slice in slices {
                let sweep = Angle.degrees(360 * Double(slice.value) / Double(total))
                var path = Path()
                path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle + sweep, clockwise: false)
                path.addArc(center: center, radius: radius * 0.55, startAngle: startAngle + sweep, endAngle: startAngle, clockwise: true)
                path.closeSubpath()
                context.fill(path, with: .color(slice.color))
                startAngle += sweep
            }
        }
        .frame(width: 120, height: 120)
    }

    private var methodBarChart: some View {
        let topMethods = stats.methodCounts.sorted { $0.value > $1.value }.prefix(6)
        let maxCount = max(topMethods.map(\.value).max() ?? 1, 1)
        return VStack(spacing: 8) {
            ForEach(Array(topMethods), id: \.key) { method, count in
                HStack(spacing: 8) {
                    Text(method)
                        .font(.caption.monospaced())
                        .frame(width: 56, alignment: .leading)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.35))
                            .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxCount))
                    }
                    .frame(height: 10)
                    Text("\(count)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold).monospaced())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
