//
//  ProwlDashboardRowView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import SwiftUI
import ProwlCore

struct ProwlDashboardRowView: View {
#if os(iOS) || os(visionOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    let log: NetworkLog

    init(log: NetworkLog) {
        self.log = log
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: rowSpacing) {
                methodBadge(log.method)
                
                Text(log.url?.path.isEmpty == false ? (log.url?.path ?? "/") : "/")
                    .font(pathFont)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.primary)
                
                Spacer(minLength: 8)
                
                Text(Self.timestampFormatter.string(from: log.startedAt))
                    .font(metaFont)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                statusBadge(statusCode: log.statusCode)

                if log.endpointRateAlertTriggered {
                    HStack(spacing: 3) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption2.weight(.bold))
                        Text("RATE")
                            .font(.caption2.weight(.heavy))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.18), in: Capsule())
                    .accessibilityLabel("Endpoint rate threshold reached")
                }
                
                if let host = log.url?.host {
                    Text(host)
                        .font(hostFont)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                Text(String(format: "%.3fs", log.duration))
                    .font(metaFont)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, rowVerticalPadding)
    }

    @ViewBuilder
    private func methodBadge(_ method: String) -> some View {
        Text(method.uppercased())
            .font(badgeFont)
            .foregroundColor(methodColor(method))
            .padding(.horizontal, badgeHorizontalPadding)
            .padding(.vertical, badgeVerticalPadding)
            .background(methodColor(method).opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func statusBadge(statusCode: Int?) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(statusCode))
                .frame(width: statusDotSize, height: statusDotSize)
            Text(statusCode.map { "\($0)" } ?? "ERR")
                .font(statusFont)
                .foregroundColor(statusColor(statusCode))
        }
        .padding(.horizontal, badgeHorizontalPadding)
        .padding(.vertical, badgeVerticalPadding)
        .background(statusColor(statusCode).opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
    }

    private var isRegularWidthLayout: Bool {
#if os(iOS) || os(visionOS)
        return horizontalSizeClass == .regular
#else
        return false
#endif
    }

    private var rowSpacing: CGFloat { isRegularWidthLayout ? 14 : 10 }
    private var rowVerticalPadding: CGFloat { isRegularWidthLayout ? 12 : 8 }
    private var badgeHorizontalPadding: CGFloat { isRegularWidthLayout ? 8 : 6 }
    private var badgeVerticalPadding: CGFloat { isRegularWidthLayout ? 5 : 4 }
    private var statusDotSize: CGFloat { isRegularWidthLayout ? 9 : 8 }

    private var pathFont: Font {
        isRegularWidthLayout
            ? .title3.monospaced().weight(.medium)
            : .body.monospaced().weight(.medium)
    }

    private var hostFont: Font {
        isRegularWidthLayout ? .callout : .caption
    }

    private var metaFont: Font {
        isRegularWidthLayout ? .callout.monospacedDigit() : .caption2.monospacedDigit()
    }

    private var badgeFont: Font {
        isRegularWidthLayout
            ? .caption.monospaced().weight(.bold)
            : .caption2.monospaced().weight(.bold)
    }

    private var statusFont: Font {
        isRegularWidthLayout
            ? .callout.monospaced().weight(.bold)
            : .caption.monospaced().weight(.bold)
    }

    private func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET": return Color(red: 0.94, green: 0.42, blue: 0.16)
        case "POST": return Color(red: 0.95, green: 0.57, blue: 0.19)
        case "PUT", "PATCH": return Color(red: 0.98, green: 0.72, blue: 0.29)
        case "DELETE": return .red
        default: return .secondary
        }
    }

    private func statusColor(_ statusCode: Int?) -> Color {
        guard let code = statusCode else { return .red }
        switch code {
        case 200...299: return .green
        case 300...399: return .blue
        case 400...499: return .orange
        case 500...599: return .red
        default: return .secondary
        }
    }
}
