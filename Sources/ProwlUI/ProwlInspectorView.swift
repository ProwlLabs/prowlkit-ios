//
//  ProwlInspectorView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import SwiftUI
import ProwlCore

public struct ProwlInspectorView: View {
    private static let contentHorizontalInset: CGFloat = 4

    @StateObject private var viewModel: ProwlInspectorViewModel
    @State private var selectedLogID: NetworkLog.ID?
    @State private var iOSExportPayload: ProwlExportPayload?
    @State private var isSettingsPresented = false
    
    @AppStorage("prowl_color_scheme") private var themeRaw: Int = 0

    public init(storage: ProwlStorage? = nil) {
        _viewModel = StateObject(wrappedValue: ProwlInspectorViewModel(storage: storage))
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme

    public var body: some View {
        NavigationView {
            dashboardList
                .navigationTitle("Prowl")
                #if os(iOS)
                .searchable(
                    text: $viewModel.searchText,
                    placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "Search URL"
                )
                #else
                .searchable(text: $viewModel.searchText, prompt: "Search URL")
                #endif
                .toolbar { toolbarContent }
            #if os(macOS) || os(visionOS)
            detailPane
            #endif
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
        .preferredColorScheme(colorScheme)
        #if os(iOS) || os(visionOS)
        .sheet(item: $iOSExportPayload) { payload in
            ProwlActivityView(activityItems: [payload.content])
        }
        #endif
        #if os(macOS)
        .sheet(isPresented: $isSettingsPresented) {
            ProwlSettingsView(
                viewModel: viewModel,
                onExportText: { exportLogs(as: .formattedText) },
                onExportCURL: { exportLogs(as: .curlCommands) }
            )
            .frame(minWidth: 560, minHeight: 520)
        }
        #endif
    }

    private var colorScheme: ColorScheme? {
        switch themeRaw {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    private var dashboardList: some View {
        let logs = viewModel.filteredLogs

        return List(selection: $selectedLogID) {
            inspectorStatusRow

            ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                VStack(alignment: .leading, spacing: 0) {
                    dashboardListRow(for: log)

                    if logs.count > 1, index < logs.count - 1 {
                        Rectangle()
                            .fill(rowDividerColor)
                            .frame(height: 1)
                    }
                }
                .padding(.vertical, 4)
                .prowlHideListRowSeparator()
                .listRowInsets(
                    EdgeInsets(
                        top: 6,
                        leading: Self.contentHorizontalInset,
                        bottom: 6,
                        trailing: Self.contentHorizontalInset
                    )
                )
                .listRowBackground(Color.clear)
            }
            
            if !logs.isEmpty {
                Text("Prowl • Crafted by Elmee")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowInsets(
                        EdgeInsets(
                            top: 8,
                            leading: Self.contentHorizontalInset,
                            bottom: 8,
                            trailing: Self.contentHorizontalInset
                        )
                    )
                    .listRowBackground(Color.clear)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }
        }
        .overlay {
            if viewModel.filteredLogs.isEmpty {
                emptyStateView(title: "No Logs", subtitle: "No requests match your filters.")
            }
        }
        #if os(macOS)
        // Prevent first list row from appearing under toolbar/search field
        // when the window initially renders.
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 10)
        }
        #endif
    }

    @ViewBuilder
    private func dashboardListRow(for log: NetworkLog) -> some View {
        #if os(macOS) || os(visionOS)
        ProwlDashboardRowView(log: log)
            .tag(log.id)
        #else
        NavigationLink {
            ProwlLogDetailView(log: log)
        } label: {
            ProwlDashboardRowView(log: log)
        }
        .buttonStyle(.plain)
        #endif
    }

    private var rowDividerColor: Color {
        systemColorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.primary.opacity(0.10)
    }

    private var inspectorStatusRow: some View {
        HStack(spacing: 4) {
            Text("Prowl Status:")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)

            statusChipsLayout
        }
        .padding(.vertical, 4)
        .listRowInsets(
            EdgeInsets(
                top: 6,
                leading: Self.contentHorizontalInset,
                bottom: 6,
                trailing: Self.contentHorizontalInset
            )
        )
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var statusChipsLayout: some View {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            statusChipsViewThatFits
        } else {
            statusChipsStack
        }
        #elseif os(macOS)
        if #available(macOS 13.0, *) {
            statusChipsViewThatFits
        } else {
            statusChipsStack
        }
        #else
        statusChipsStack
        #endif
    }

    @available(iOS 16.0, macOS 13.0, *)
    private var statusChipsViewThatFits: some View {
        ViewThatFits(in: .horizontal) {
            statusChipsRow
            statusChipsStack
        }
    }

    private var statusChipsRow: some View {
        HStack(spacing: 8) {
            statusChip(title: "Logging", value: ProwlRuntime.isLoggingEnabled ? "On" : "Off", color: ProwlRuntime.isLoggingEnabled ? .green : .red)
            statusChip(
                title: "Sensitive",
                value: ProwlRuntime.isSensitiveDataMaskingEnabled ? "Masked" : "Raw",
                color: ProwlRuntime.isSensitiveDataMaskingEnabled ? .green : .orange
            )
            Spacer(minLength: 0)
        }
    }

    private var statusChipsStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            statusChip(title: "Logging", value: ProwlRuntime.isLoggingEnabled ? "On" : "Off", color: ProwlRuntime.isLoggingEnabled ? .green : .red)
            statusChip(
                title: "Sensitive",
                value: ProwlRuntime.isSensitiveDataMaskingEnabled ? "Masked" : "Raw",
                color: ProwlRuntime.isSensitiveDataMaskingEnabled ? .green : .orange
            )
        }
    }

    private func statusChip(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption2.weight(.bold))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.15), in: Capsule())
        }
        .padding(.vertical, 2)
    }

    #if os(macOS) || os(visionOS)
    private var detailPane: some View {
        Group {
            if let selectedLog = selectedLog {
                ProwlLogDetailView(log: selectedLog)
            } else {
                emptyStateView(title: "Select a Request", subtitle: "Choose a network event to inspect.")
            }
        }
    }
    #endif

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
    #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Dismiss")
        }
    #endif

    #if os(macOS)
        ToolbarItemGroup(placement: .primaryAction) {
            Button(role: .destructive) {
                viewModel.clearLogs()
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)

            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
            }
        }
    #elseif !os(watchOS)
        ToolbarItemGroup(placement: .primaryAction) {
            Button(role: .destructive) {
                viewModel.clearLogs()
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
            
            NavigationLink(destination: ProwlSettingsView(
                viewModel: viewModel,
                onExportText: { exportLogs(as: .formattedText) },
                onExportCURL: { exportLogs(as: .curlCommands) }
            )) {
                Image(systemName: "gearshape")
            }
        }
    #else
        ToolbarItem(placement: .primaryAction) {
            NavigationLink(destination: ProwlSettingsView(
                viewModel: viewModel,
                onExportText: { exportLogs(as: .formattedText) },
                onExportCURL: { exportLogs(as: .curlCommands) }
            )) {
                Image(systemName: "gearshape")
            }
        }
    #endif
    }

    private var selectedLog: NetworkLog? {
        guard let selectedLogID else { return nil }
        return viewModel.filteredLogs.first(where: { $0.id == selectedLogID })
    }

    private func exportLogs(as format: ProwlExportFormat) {
        let content = ProwlLogFormatter.export(logs: viewModel.filteredLogs, as: format)
    #if os(iOS)
        iOSExportPayload = ProwlExportPayload(content: content)
    #elseif os(macOS)
        ProwlMacExporter.save(content: content, suggestedFileName: format.fileName)
    #endif
    }

    private func emptyStateView(title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
    #if os(iOS)
                    .fill(Color(UIColor.secondarySystemFill))
    #else
                    .fill(Color.secondary.opacity(0.2))
    #endif
                    .frame(width: 88, height: 88)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(.secondary)
                    .offset(x: -8, y: -8)
                
                Image(systemName: "network")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.blue)
                    .offset(x: 10, y: 10)
            }
            .padding(.bottom, 8)
            
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
                
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .padding(.horizontal, 40)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

private extension View {
    @ViewBuilder
    func prowlHideListRowSeparator() -> some View {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            self.listRowSeparator(.hidden)
        } else {
            self
        }
        #else
        self.listRowSeparator(.hidden)
        #endif
    }
}

#if DEBUG
private struct ProwlInspectorPreviewHarness: View {
    private let storage = ProwlStorage(limit: 50)
    @State private var hasSeeded = false

    var body: some View {
        ProwlInspectorView(storage: storage)
            .onAppear {
                guard !hasSeeded else { return }
                hasSeeded = true

                Task {
                    await storage.clear()
                    ProwlEndpointRateAlerts.resetCounters()
                    for log in previewLogs {
                        await storage.append(log)
                    }
                }
            }
    }

    private var previewLogs: [NetworkLog] {
        let now = Date()
        return [
            NetworkLog(
                url: URL(string: "https://api.prowl.dev/v1/profile?expand=devices"),
                method: "GET",
                requestHeaders: ["Authorization": "Bearer preview-token"],
                responseHeaders: ["Content-Type": "application/json"],
                responseBody: .init(data: Data("{\"name\":\"Elmee\"}".utf8), contentType: "application/json"),
                statusCode: 200,
                startedAt: now.addingTimeInterval(-8),
                duration: 0.182,
                timeoutInterval: 60,
                cachePolicy: "UseProtocolCachePolicy"
            ),
            NetworkLog(
                url: URL(string: "https://api.prowl.dev/v1/orders?page=2&limit=20"),
                method: "POST",
                requestHeaders: ["Content-Type": "application/json"],
                requestBody: .init(data: Data("{\"status\":\"pending\"}".utf8), contentType: "application/json"),
                responseHeaders: ["Content-Type": "application/json"],
                responseBody: .init(data: Data("{\"ok\":true}".utf8), contentType: "application/json"),
                statusCode: 201,
                startedAt: now.addingTimeInterval(-5),
                duration: 0.341,
                timeoutInterval: 30,
                cachePolicy: "ReloadIgnoringLocalCacheData"
            ),
            NetworkLog(
                url: URL(string: "https://api.prowl.dev/v1/upload"),
                method: "PUT",
                requestHeaders: ["Content-Type": "application/octet-stream"],
                responseHeaders: ["Content-Type": "application/json"],
                responseBody: .init(data: Data("{\"error\":\"timeout\"}".utf8), contentType: "application/json"),
                statusCode: 504,
                startedAt: now.addingTimeInterval(-2),
                duration: 1.219,
                timeoutInterval: 15,
                cachePolicy: "ReloadIgnoringLocalCacheData",
                errorDescription: "The request timed out."
            )
        ]
    }
}

#Preview("Inspector Dashboard") {
    ProwlInspectorPreviewHarness()
}
#endif
