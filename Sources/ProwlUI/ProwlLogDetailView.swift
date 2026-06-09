//
//  ProwlLogDetailView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import ProwlCore
import SwiftUI

#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// SwiftUI detail screen for a single captured log (Info, Request, Response tabs).
///
/// Embed when building a custom inspector layout. ``ProwlInspectorView`` uses
/// this view internally on iPad-style and macOS split layouts.
public struct ProwlLogDetailView: View {
    /// Tabs shown in the detail header.
    public enum Tab: String, CaseIterable, Identifiable {
        /// URL, timing, status, and metadata.
        case info = "Info"
        /// Request headers and body.
        case request = "Request"
        /// Response headers and body.
        case response = "Response"

        public var id: String { rawValue }
    }

    private static let detailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()
    private static let titleFontSize: CGFloat = 14
    private static let contentFontSize: CGFloat = 12

    public let log: NetworkLog

    @State private var selectedTab: Tab = .info
    @State private var sharePayload: ProwlExportPayload?
    @State private var isMockEditorPresented = false
    @State private var isRewriteEditorPresented = false
    @State private var copyToastMessage: String?
    @State private var copyToastToken = UUID()
    @State private var isShowingFullRequestBody = false
    @State private var isShowingFullResponseBody = false
    @State private var isWatched = false

    /// Creates a detail view for one captured log entry.
    public init(log: NetworkLog) {
        self.log = log
        _isWatched = State(initialValue: ProwlWatchStore.isWatched(log))
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 10)

            Divider()

            ScrollView {
                Group {
                    switch selectedTab {
                    case .info:
                        infoTabContent
                    case .request:
                        requestTabContent
                    case .response:
                        responseTabContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            footerCreditView
                .padding(.top, 10)
                .padding(.bottom, 2)
        }
        .background(platformBackground)
        .navigationTitle(detailsNavigationTitle)
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Share JSON") {
                        shareContent(ProwlLogFormatter.shareText(log: log))
                    }
                    Button("Share cURL") {
                        shareContent(ProwlLogFormatter.export(logs: [log], as: .curlCommands))
                    }
                    Button("Create Mock") {
                        isMockEditorPresented = true
                    }
                    Button("Rewrite Request") {
                        isRewriteEditorPresented = true
                    }
                    Button(isWatched ? "Unwatch Endpoint" : "Watch Endpoint") {
                        ProwlWatchStore.toggleWatch(for: log)
                        isWatched.toggle()
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        #if os(iOS) || os(visionOS)
        .sheet(item: $sharePayload) { payload in
            ProwlActivityView(activityItems: [payload.content])
        }
        #endif
        .sheet(isPresented: $isMockEditorPresented) {
            #if os(macOS)
            ProwlMockEditorView(log: log)
                .frame(minWidth: 580, minHeight: 560)
            #else
            ProwlMockEditorView(log: log)
            #endif
        }
        .sheet(isPresented: $isRewriteEditorPresented) {
            #if os(macOS)
            ProwlRequestRewriteEditorView(log: log)
                .frame(minWidth: 580, minHeight: 560)
            #else
            ProwlRequestRewriteEditorView(log: log)
            #endif
        }
        .overlay(alignment: .bottom) {
            if let copyToastMessage {
                copyToastView(message: copyToastMessage)
                    .padding(.bottom, 22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: tabBarSpacing) {
            ForEach(Tab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: tabBarFontSize, weight: selectedTab == tab ? .semibold : .medium))
                        .foregroundStyle(selectedTab == tab ? tabBarSelectedForeground : tabBarUnselectedForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, tabBarVerticalPadding)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? tabBarSelectedBackground : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.rawValue) tab")
                .accessibilityHint("Shows \(tab.rawValue.lowercased()) details")
                .accessibilityAddTraits(selectedTab == tab ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(tabBarContainerPadding)
        .background(
            Capsule()
                .fill(tabBarTrackBackground)
        )
        .overlay(
            Capsule()
                .strokeBorder(tabBarTrackBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var tabBarSpacing: CGFloat {
        #if os(macOS)
        4
        #else
        8
        #endif
    }

    private var tabBarFontSize: CGFloat {
        #if os(macOS)
        13
        #else
        Self.titleFontSize
        #endif
    }

    private var tabBarVerticalPadding: CGFloat {
        #if os(macOS)
        8
        #else
        10
        #endif
    }

    private var tabBarContainerPadding: CGFloat {
        #if os(macOS)
        4
        #else
        6
        #endif
    }

    private var tabBarSelectedBackground: Color {
        #if os(macOS)
        Color.accentColor
        #else
        platformSelectedTabBackground
        #endif
    }

    private var tabBarSelectedForeground: Color {
        #if os(macOS)
        .white
        #else
        .primary
        #endif
    }

    private var tabBarUnselectedForeground: Color {
        .secondary
    }

    private var tabBarTrackBackground: Color {
        #if os(macOS)
        Color(NSColor.controlBackgroundColor)
        #else
        platformSecondaryBackground
        #endif
    }

    private var tabBarTrackBorder: Color {
        Color.primary.opacity(0.08)
    }

    private var detailsNavigationTitle: String {
        let appName = (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
            ?? ""
        if appName.isEmpty {
            return "Details"
        }
        return "Details \(appName)"
    }

    private var infoTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            fixedHeightSectionCard(title: "Endpoint") {
                VStack(alignment: .leading, spacing: 8) {
                    if log.responseMocked {
                        infoBanner(
                            text: "Response was served by a Prowl mock rule (not from the network).",
                            color: Color(red: 0.69, green: 0.32, blue: 0.87)
                        )
                    }
                    if log.requestRewritten {
                        infoBanner(
                            text: "Request was rewritten by a Prowl rule before sending.",
                            color: Color(red: 0.95, green: 0.57, blue: 0.19)
                        )
                    }
                    if log.endpointRateAlertTriggered {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.orange)
                            Text("This request reached a configured per-endpoint call-count threshold. Adjust Prowl.endpointRateAlertRules, or reset counters when clearing logs (Prowl.resetEndpointRateAlertCounters).")
                                .font(.system(size: Self.contentFontSize))
                                .foregroundColor(.primary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.orange.opacity(0.12))
                        )
                    }
                    labeledValue(
                        "URL",
                        value: log.url?.absoluteString ?? "-",
                        toastMessage: "URL copied"
                    )
                    if let hostIp = log.hostIp, !hostIp.isEmpty {
                        labeledValue(ProwlStrings.hostIP, value: hostIp, toastMessage: "Host IP copied")
                    }
                    Divider()
                    HStack(spacing: 10) {
                        capsuleTag(
                            text: log.method.uppercased(),
                            color: brandAccent,
                            copyValue: log.method.uppercased(),
                            toastMessage: "Method copied"
                        )
                        if let statusCode = log.statusCode {
                            capsuleTag(
                                text: "Status \(statusCode)",
                                color: statusColor(statusCode),
                                copyValue: String(statusCode),
                                toastMessage: "Status code copied"
                            )
                        } else {
                            capsuleTag(
                                text: "No response",
                                color: .secondary,
                                copyValue: "No response",
                                toastMessage: "Status copied"
                            )
                        }
                    }
                }
            }

            fixedHeightSectionCard(title: "Timing") {
                VStack(alignment: .leading, spacing: 10) {
                    labeledValue(
                        "Request date",
                        value: String(describing: log.startedAt),
                        toastMessage: "Request date copied"
                    )
                    if log.statusCode != nil {
                        labeledValue(
                            "Response date",
                            value: String(describing: log.startedAt.addingTimeInterval(log.duration)),
                            toastMessage: "Response date copied"
                        )
                        labeledValue(
                            "Time interval",
                            value: String(format: "%.0f ms", log.duration * 1000),
                            toastMessage: "Time interval copied"
                        )
                    }
                    if let timing = log.timing {
                        Divider()
                        timingRow(ProwlStrings.timingDNS, timing.dnsMillis)
                        timingRow(ProwlStrings.timingConnect, timing.connectMillis)
                        timingRow(ProwlStrings.timingTLS, timing.secureConnectMillis)
                        timingRow(ProwlStrings.timingRequest, timing.requestBodyMillis)
                        timingRow(ProwlStrings.timingResponse, timing.responseBodyMillis)
                    }
                    labeledValue(
                        "Timeout",
                        value: log.timeoutInterval.map { String($0) } ?? "-",
                        toastMessage: "Timeout copied"
                    )
                    labeledValue(
                        "Cache policy",
                        value: log.cachePolicy ?? "-",
                        toastMessage: "Cache policy copied"
                    )
                }
            }

            if hasURLQueryItems {
                fixedHeightSectionCard(title: "URL Query Strings") {
                    queryItemList(log.url)
                }
            }
        }
    }

    private var hasURLQueryItems: Bool {
        guard
            let url = log.url,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return false
        }
        return !(components.queryItems ?? []).isEmpty
    }

    private var requestTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Request")
            fixedHeightSectionCard(title: "Headers") {
                headerList(log.requestHeaders, emptyText: "Request headers are empty")
            }
            fixedHeightSectionCard(title: "Body") {
                bodyView(
                    log.requestBody,
                    emptyText: "Request body is empty",
                    applyJSONHighlighting: true,
                    toastMessage: "Request body copied",
                    isShowingFullBody: $isShowingFullRequestBody,
                    fullBodyButtonTitle: "Show request body"
                )
            }
            multipartSection(log.requestMultipartParts)
        }
    }

    private var responseTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Response")
            fixedHeightSectionCard(title: "Headers") {
                headerList(log.responseHeaders, emptyText: "Response headers are empty")
            }
            fixedHeightSectionCard(title: "Body") {
                bodyView(
                    log.responseBody,
                    emptyText: "Response body is empty",
                    applyJSONHighlighting: true,
                    toastMessage: "Response body copied",
                    isShowingFullBody: $isShowingFullResponseBody,
                    fullBodyButtonTitle: "Show response body"
                )
            }
            multipartSection(log.responseMultipartParts)
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: Self.titleFontSize, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View, Trailing: View>(
        title: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: Self.titleFontSize, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                trailing()
            }
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(platformSecondaryBackground)
        )
    }

    @ViewBuilder
    private func fixedHeightSectionCard<Content: View, Trailing: View>(
        title: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        sectionCard(title: title, trailing: trailing) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func infoBanner(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: Self.contentFontSize))
            .foregroundColor(.primary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
            )
    }

    @ViewBuilder
    private func timingRow(_ label: String, _ millis: Int?) -> some View {
        if let millis {
            labeledValue(label, value: "\(millis) ms", toastMessage: "\(label) copied")
        }
    }

    @ViewBuilder
    private func multipartSection(_ parts: [MultipartPart]) -> some View {
        if !parts.isEmpty {
            fixedHeightSectionCard(title: ProwlStrings.multipartParts) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(parts) { part in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(part.name ?? part.fileName ?? "part")
                                .font(.caption.weight(.semibold))
                            if let fileName = part.fileName {
                                Text("file: \(fileName)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            if let contentType = part.contentType {
                                Text(contentType)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(part.sizeBytes) bytes")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let preview = part.textPreview {
                                Text(preview)
                                    .font(.caption2.monospaced())
                                    .lineLimit(4)
                            }
                        }
                        if part.id != parts.last?.id { Divider() }
                    }
                }
            }
        }
    }

    private func labeledValue(_ label: String, value: String, toastMessage: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: Self.contentFontSize, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: Self.contentFontSize))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .onLongPressGesture(minimumDuration: 0.4) {
                    copyToPasteboard(value, toastMessage: toastMessage ?? "\(label) copied")
                }
                .contextMenu {
                    Button("Copy") {
                        copyToPasteboard(value, toastMessage: toastMessage ?? "\(label) copied")
                    }
                }
        }
    }

    @ViewBuilder
    private func capsuleTag(
        text: String,
        color: Color,
        copyValue: String? = nil,
        toastMessage: String? = nil
    ) -> some View {
        Button {
            guard let copyValue else { return }
            copyToPasteboard(copyValue, toastMessage: toastMessage ?? "\(text) copied")
        } label: {
            Text(text)
                .font(.system(size: Self.contentFontSize, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(copyValue == nil)
    }

    @ViewBuilder
    private func headerList(_ headers: [String: String], emptyText: String) -> some View {
        if headers.isEmpty {
            Text(emptyText)
                .font(.system(size: Self.contentFontSize))
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(headers.keys.sorted(), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(key)
                            .font(.system(size: Self.contentFontSize, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(headers[key] ?? "")
                            .font(.system(size: Self.contentFontSize))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .onLongPressGesture(minimumDuration: 0.4) {
                                let headerValue = headers[key] ?? ""
                                copyToPasteboard("\(key): \(headerValue)", toastMessage: "\(key) header copied")
                            }
                            .contextMenu {
                                Button("Copy") {
                                    let headerValue = headers[key] ?? ""
                                    copyToPasteboard("\(key): \(headerValue)", toastMessage: "\(key) header copied")
                                }
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bodyContentView(text: String, body: NetworkLog.Body, toastMessage: String) -> some View {
        Group {
            if ProwlJSONSyntaxHighlighter.looksLikeJSON(text, contentType: body.contentType) {
                ProwlJSONTreeView(json: text)
            } else {
                let highlighted = ProwlJSONSyntaxHighlighter.highlight(text, contentType: body.contentType)
                Text(highlighted)
                    .font(.system(size: Self.contentFontSize, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            copyToPasteboard(text, toastMessage: toastMessage)
        }
        .contextMenu {
            Button("Copy") {
                copyToPasteboard(text, toastMessage: toastMessage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(platformBodyBackground)
        )
    }

    @ViewBuilder
    private func bodyView(
        _ body: NetworkLog.Body?,
        emptyText: String,
        applyJSONHighlighting: Bool = false,
        toastMessage: String = "Body copied",
        isShowingFullBody: Binding<Bool> = .constant(true),
        fullBodyButtonTitle: String? = nil
    ) -> some View {
        let text = bodyText(body, emptyText: emptyText)
        let hasBody = body != nil && text != emptyText
        let isTooLong = text.count > 1024
        let shouldShowPreviewMessage = hasBody && isTooLong && !isShowingFullBody.wrappedValue
        VStack(alignment: .leading, spacing: 8) {
            if shouldShowPreviewMessage {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Too long to show. If you want to see it, please tap the following button")
                        .font(.system(size: Self.contentFontSize))
                        .foregroundColor(.secondary)

                    if let fullBodyButtonTitle {
                        Button(fullBodyButtonTitle) {
                            isShowingFullBody.wrappedValue = true
                        }
                        .font(.system(size: Self.contentFontSize, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(brandAccent.opacity(0.16), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(platformBodyBackground)
                )
            } else {
                if applyJSONHighlighting, let body {
                    bodyContentView(text: text, body: body, toastMessage: toastMessage)
                } else {
                    Text(text)
                        .font(.system(size: Self.contentFontSize, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                    .onLongPressGesture(minimumDuration: 0.4) {
                        copyToPasteboard(text, toastMessage: toastMessage)
                    }
                    .contextMenu {
                        Button("Copy") {
                            copyToPasteboard(text, toastMessage: toastMessage)
                        }
                    }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(platformBodyBackground)
                        )
                }
            }
        }
    }

    @ViewBuilder
    private func queryItemList(_ url: URL?) -> some View {
        if let url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let queryItems = components.queryItems ?? []
            if queryItems.isEmpty {
                Text("No query parameters")
                    .font(.system(size: Self.contentFontSize))
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(queryItems.enumerated()), id: \.offset) { _, queryItem in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(queryItem.name)
                                .font(.system(size: Self.contentFontSize, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text(queryItem.value ?? "")
                                .font(.system(size: Self.contentFontSize))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .onLongPressGesture(minimumDuration: 0.4) {
                                    copyToPasteboard(
                                        "\(queryItem.name)=\(queryItem.value ?? "")",
                                        toastMessage: "\(queryItem.name) query copied"
                                    )
                                }
                                .contextMenu {
                                    Button("Copy") {
                                        copyToPasteboard(
                                            "\(queryItem.name)=\(queryItem.value ?? "")",
                                            toastMessage: "\(queryItem.name) query copied"
                                        )
                                    }
                                }
                        }
                    }
                }
            }
        } else {
            Text("No query parameters")
                .font(.system(size: Self.contentFontSize))
                .foregroundColor(.secondary)
        }
    }

    private func byteSizeText(_ bytes: Int) -> String {
        if bytes == 0 { return "0 B" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func bodyText(_ body: NetworkLog.Body?, emptyText: String) -> String {
        guard let body, !body.data.isEmpty else { return emptyText }
        return ProwlLogFormatter.bodyText(from: body, pretty: true)
    }

    @ViewBuilder
    private func prowlSectionTextView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Self.contentFontSize, design: .monospaced))
            .foregroundColor(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(platformBodyBackground)
            )
    }

    private func requestDumpText() -> String {
        prowlRequestString(showFullBody: true)
    }

    private func responseDumpText() -> String {
        prowlResponseString(showFullBody: true)
    }

    private var shouldShowRequestBodyButton: Bool {
        (log.requestBody?.data.count ?? 0) > 1024 && !isShowingFullRequestBody
    }

    private var shouldShowResponseBodyButton: Bool {
        (log.responseBody?.data.count ?? 0) > 1024 && !isShowingFullResponseBody
    }

    private func prowlInfoString() -> String {
        var lines: [String] = []
        lines.append("URL: \(log.url?.absoluteString ?? "-")")
        lines.append("Method: \(log.method)")
        if let statusCode = log.statusCode {
            lines.append("Status: \(statusCode)")
        }
        lines.append("Request date: \(String(describing: log.startedAt))")
        if log.statusCode != nil {
            lines.append("Response date: \(String(describing: log.startedAt.addingTimeInterval(log.duration)))")
            lines.append("Time interval: \(String(Float(log.duration)))")
        }
        lines.append("Timeout: \(log.timeoutInterval.map { String($0) } ?? "-")")
        lines.append("Cache policy: \(log.cachePolicy ?? "-")")
        return lines.joined(separator: "\n")
    }

    private func prowlRequestString(showFullBody: Bool) -> String {
        var lines: [String] = []
        lines.append("Headers:")
        if log.requestHeaders.isEmpty {
            lines.append("Request headers: empty")
        } else {
            for key in log.requestHeaders.keys.sorted() {
                lines.append("\(key): \(log.requestHeaders[key] ?? "")")
            }
        }
        lines.append("Request Payload:")
        lines.append(prowlBodyString(body: log.requestBody, emptyText: "Request body is empty", showFullBody: showFullBody))
        return lines.joined(separator: "\n")
    }

    private func prowlResponseString(showFullBody: Bool) -> String {
        guard log.statusCode != nil || !log.responseHeaders.isEmpty || log.responseBody != nil else {
            return "No response"
        }
        var lines: [String] = []
        lines.append("Headers:")
        if log.responseHeaders.isEmpty {
            lines.append("Response headers: empty")
        } else {
            for key in log.responseHeaders.keys.sorted() {
                lines.append("\(key): \(log.responseHeaders[key] ?? "")")
            }
        }
        lines.append("Response Body:")
        lines.append(prowlBodyString(body: log.responseBody, emptyText: "Response body is empty", showFullBody: showFullBody))
        return lines.joined(separator: "\n")
    }

    private func prowlBodyString(body: NetworkLog.Body?, emptyText: String, showFullBody: Bool) -> String {
        guard let body else { return emptyText }
        if body.data.isEmpty { return emptyText }
        if body.data.count > 1024 && !showFullBody {
            return "Too long to show. If you want to see it, please tap the following button"
        }
        return ProwlLogFormatter.bodyText(from: body, pretty: true)
    }

    @ViewBuilder
    private var footerCreditView: some View {
        VStack(spacing: 4) {
            Text("Copyright © 2026 Elmee")
                .foregroundColor(.secondary)
            if let siteURL = URL(string: "https://elmee.my") {
                Link("elmee.my", destination: siteURL)
                    .foregroundColor(brandAccent)
            }
        }
        .font(.system(size: Self.contentFontSize))
        .lineLimit(1)
    }

    @ViewBuilder
    private func copyToastView(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(.system(size: Self.contentFontSize, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    private func shareContent(_ content: String) {
        #if os(macOS)
        ProwlMacExporter.save(content: content, suggestedFileName: "prowl-log.txt")
        #else
        sharePayload = ProwlExportPayload(content: content)
        #endif
    }

    private func copyToPasteboard(_ string: String, toastMessage: String = "Copied") {
        #if os(iOS) || os(visionOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        let p = NSPasteboard.general
        p.clearContents()
        p.setString(string, forType: .string)
        #endif
        triggerCopyFeedback()
        showCopyToast(toastMessage)
    }

    private func triggerCopyFeedback() {
        #if os(iOS) || os(visionOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    private func showCopyToast(_ message: String) {
        let token = UUID()
        copyToastToken = token
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            copyToastMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard copyToastToken == token else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                copyToastMessage = nil
            }
        }
    }

    private func statusColor(_ code: Int?) -> Color {
        guard let code else { return .red }
        switch code {
        case 200...299: return .green
        case 300...399: return .blue
        case 400...499: return .orange
        case 500...599: return .red
        default: return .secondary
        }
    }

    private var brandAccent: Color {
        Color(red: 0.94, green: 0.42, blue: 0.16)
    }

    private var platformBackground: Color {
        #if os(iOS) || os(visionOS)
        return Color(UIColor.systemGroupedBackground)
        #elseif os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return .clear
        #endif
    }

    private var platformSecondaryBackground: Color {
        #if os(iOS) || os(visionOS)
        return Color(UIColor.secondarySystemGroupedBackground)
        #elseif os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return .clear
        #endif
    }

    private var platformSelectedTabBackground: Color {
        #if os(iOS) || os(visionOS)
        return Color(UIColor.tertiarySystemGroupedBackground)
        #else
        return Color.primary.opacity(0.08)
        #endif
    }

    private var platformBodyBackground: Color {
        #if os(iOS) || os(visionOS)
        return Color(UIColor.systemBackground).opacity(0.7)
        #elseif os(macOS)
        return Color(NSColor.textBackgroundColor).opacity(0.7)
        #else
        return Color.primary.opacity(0.05)
        #endif
    }
}
