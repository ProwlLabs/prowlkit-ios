//
//  ProwlSettingsView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import SwiftUI
import ProwlCore
#if os(iOS) || os(visionOS)
import UIKit
#endif

struct ProwlSettingsView: View {
    @ObservedObject var viewModel: ProwlInspectorViewModel
    var onExportText: () -> Void
    var onExportCURL: () -> Void
    var onExportHAR: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("prowl_color_scheme") private var themeRaw: Int = 0
    @State private var isLoggingEnabled = true
    @State private var isSensitiveDataMaskingEnabled = false
    @AppStorage("prowl_floating_bubble") private var floatingBubbleEnabled = false
    @AppStorage("prowl_persist_sessions") private var persistSessions = false
    @State private var mockImportText = ""
    @State private var isMockImportPresented = false
    @State private var mockExportPayload: ProwlExportPayload?

    private var stats: ProwlRequestStats {
        ProwlRequestStatsCalculator.compute(from: viewModel.logs)
    }

    init(
        viewModel: ProwlInspectorViewModel,
        onExportText: @escaping () -> Void,
        onExportCURL: @escaping () -> Void,
        onExportHAR: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onExportText = onExportText
        self.onExportCURL = onExportCURL
        self.onExportHAR = onExportHAR
        _isLoggingEnabled = State(initialValue: ProwlRuntime.isLoggingEnabled)
        _isSensitiveDataMaskingEnabled = State(initialValue: ProwlRuntime.isSensitiveDataMaskingEnabled)
    }

    var body: some View {
        Group {
            #if os(macOS)
            macSettingsLayout
            #else
            iosSettingsLayout
            #endif
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .onChange(of: isLoggingEnabled) { ProwlRuntime.isLoggingEnabled = $0 }
        .onChange(of: isSensitiveDataMaskingEnabled) { ProwlRuntime.isSensitiveDataMaskingEnabled = $0 }
        .onChange(of: persistSessions) { ProwlSessionPersistence.isEnabled = $0 }
        .onChange(of: floatingBubbleEnabled) { enabled in
            UserDefaults.standard.set(enabled, forKey: "prowl_floating_bubble")
            NotificationCenter.default.post(
                name: Notification.Name("prowlFloatingBubblePreferenceDidChange"),
                object: enabled
            )
        }
        .sheet(isPresented: $isMockImportPresented) { mockImportSheet }
        .sheet(item: $mockExportPayload) { payload in
            #if os(iOS)
            ProwlActivityView(activityItems: [payload.content])
            #else
            EmptyView()
            #endif
        }
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        #endif
    }

    #if !os(macOS)
    private var iosSettingsLayout: some View {
        List {
            Section {
                overviewCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            Section {
                ProwlSettingsToggleRow(
                    icon: "antenna.radiowaves.left.and.right",
                    tint: .blue,
                    title: "Request Logging",
                    isOn: $isLoggingEnabled
                )
                ProwlSettingsToggleRow(
                    icon: "externaldrive",
                    tint: .indigo,
                    title: ProwlStrings.persistSessions,
                    isOn: $persistSessions
                )
            } header: {
                Text("Capture")
            } footer: {
                Text("When logging is off, the inspector stays available but new requests are not recorded.")
            }

            Section {
                ProwlSettingsToggleRow(
                    icon: "eye.slash.fill",
                    tint: .orange,
                    title: "Mask Sensitive Data",
                    isOn: $isSensitiveDataMaskingEnabled
                )
            } header: {
                Text("Privacy")
            } footer: {
                Text("Redacts Authorization headers, cookies, tokens, and common secret JSON fields.")
            }

            #if os(iOS)
            Section {
                ProwlSettingsToggleRow(
                    icon: "circle.circle.fill",
                    tint: ProwlSettingsDesign.brand,
                    title: "Floating Debug Bubble",
                    isOn: $floatingBubbleEnabled
                )
            } header: {
                Text("Inspector")
            } footer: {
                Text("Draggable shortcut to open Prowl from any screen. Shake still works when the bubble is off.")
            }
            #endif

            Section {
                ProwlSettingsPickerRow(
                    icon: "checkmark.seal.fill",
                    tint: .green,
                    title: "Response Status",
                    selection: $viewModel.statusFilter
                ) {
                    ForEach(ProwlStatusCategory.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                ProwlSettingsPickerRow(
                    icon: "doc.text.fill",
                    tint: .teal,
                    title: "Content Type",
                    selection: $viewModel.contentTypeFilter
                ) {
                    ForEach(ProwlContentTypeCategory.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
            } header: {
                Text("Filters")
            }

            Section {
                Picker(selection: $themeRaw) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                } label: {
                    ProwlSettingsLabel(
                        icon: "circle.lefthalf.filled",
                        tint: .purple,
                        title: "Appearance"
                    )
                }
                .pickerStyle(.menu)
            }

            Section {
                NavigationLink {
                    ProwlMocksView()
                } label: {
                    ProwlSettingsLabel(icon: "wand.and.stars", tint: .pink, title: "Active Mocks")
                }
                Button {
                    Task {
                        let rules = await ProwlMocker.shared.allRules()
                        mockExportPayload = ProwlExportPayload(content: ProwlMockExporter.exportRules(rules))
                    }
                } label: {
                    ProwlSettingsLabel(icon: "square.and.arrow.up", tint: .blue, title: ProwlStrings.exportMocks)
                }
                .buttonStyle(.plain)
                Button { isMockImportPresented = true } label: {
                    ProwlSettingsLabel(icon: "square.and.arrow.down", tint: .blue, title: ProwlStrings.importMocks)
                }
                .buttonStyle(.plain)
            } header: {
                Text("Mocks")
            } footer: {
                Text("Import, export, and manage mock rules. Disable or delete mocks to restore live API responses without restarting the app.")
            }

            Section {
                exportRow(
                    title: "Share Logs",
                    subtitle: "Readable request & response dump",
                    icon: "doc.richtext",
                    tint: .blue,
                    action: { runExport(onExportText) }
                )
                exportRow(
                    title: "Share cURL",
                    subtitle: "Replay in Terminal",
                    icon: "terminal",
                    tint: .orange,
                    action: { runExport(onExportCURL) }
                )
                exportRow(
                    title: ProwlStrings.exportHAR,
                    subtitle: "HAR 1.2 for DevTools",
                    icon: "chart.bar.doc.horizontal",
                    tint: .purple,
                    action: { runExport(onExportHAR) }
                )
            } header: {
                Text("Export")
            }

            Section {
                aboutRow("App", appName)
                aboutRow("Version", appVersion)
                aboutRow("OS", osVersion)
                aboutRow("Display", screenResolution)
            } header: {
                Text("About")
            } footer: {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        ProwlBrandIconView(height: 20, variant: .colored)
                        Text("Crafted by Elmee")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProwlStatsCharts(stats: stats)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ProwlSettingsDesign.cardBackground)
                .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        }
        .padding(.horizontal, 16)
    }

    private func exportRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ProwlSettingsIcon(symbol: icon, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func aboutRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func runExport(_ action: @escaping () -> Void) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: action)
    }
    #endif

    #if os(macOS)
    private var macSettingsLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                macPanel("Overview") {
                    ProwlStatsCharts(stats: stats)
                }

                macPanel("Capture") {
                    macToggle("Request Logging", isOn: $isLoggingEnabled)
                    Divider().padding(.leading, 44)
                    macToggle(ProwlStrings.persistSessions, isOn: $persistSessions)
                    Text("When logging is off, the inspector stays available but new requests are not recorded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 44)
                }

                macPanel("Privacy") {
                    macToggle("Mask Sensitive Data", isOn: $isSensitiveDataMaskingEnabled)
                    Text("Redacts Authorization headers, cookies, tokens, and common secret JSON fields.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 44)
                }

                macPanel("Filters") {
                    macPickerRow("Response Status", selection: $viewModel.statusFilter) {
                        ForEach(ProwlStatusCategory.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    Divider().padding(.leading, 44)
                    macPickerRow("Content Type", selection: $viewModel.contentTypeFilter) {
                        ForEach(ProwlContentTypeCategory.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                }

                macPanel("Appearance") {
                    Picker("Theme", selection: $themeRaw) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                macPanel("Mocking") {
                    NavigationLink { ProwlMocksView() } label: {
                        Label("Active Mocks", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.plain)
                }

                macPanel("Export") {
                    HStack(spacing: 10) {
                        if #available(macOS 13.0, *) {
                            ShareLink(item: formattedTextExportContent) {
                                Label("Share Logs", systemImage: "doc.richtext")
                            }
                            ShareLink(item: curlExportContent) {
                                Label("Share cURL", systemImage: "terminal")
                            }
                            Button { onExportHAR() } label: {
                                Label(ProwlStrings.exportHAR, systemImage: "chart.bar.doc.horizontal")
                            }
                        } else {
                            Button { onExportText() } label: {
                                Label("Share Logs", systemImage: "doc.richtext")
                            }
                            Button { onExportCURL() } label: {
                                Label("Share cURL", systemImage: "terminal")
                            }
                        }
                    }
                }

                macPanel("About") {
                    macAboutRow("App", appName)
                    macAboutRow("Version", appVersion)
                    macAboutRow("OS", osVersion)
                }
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func macPanel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func macToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
        }
        .toggleStyle(.switch)
    }

    private func macPickerRow<Selection: Hashable, Content: View>(
        _ title: String,
        selection: Binding<Selection>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker(title, selection: selection, content: content)
                .labelsHidden()
                .frame(width: 180)
        }
    }

    private func macAboutRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
    #endif

    private var mockImportSheet: some View {
        NavigationView {
            Form {
                Section {
                    TextEditor(text: $mockImportText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 220)
                } header: {
                    Text("Paste mock rules JSON")
                }
            }
            .navigationTitle(ProwlStrings.importMocks)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isMockImportPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        let rules = ProwlMockExporter.importRules(mockImportText)
                        Task {
                            for rule in rules {
                                await ProwlMocker.shared.saveRule(rule)
                            }
                        }
                        mockImportText = ""
                        isMockImportPresented = false
                    }
                }
            }
        }
    }

    private var formattedTextExportContent: String {
        ProwlLogFormatter.export(logs: viewModel.filteredLogs, as: .formattedText)
    }

    private var curlExportContent: String {
        ProwlLogFormatter.export(logs: viewModel.filteredLogs, as: .curlCommands)
    }

    private var appName: String {
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
            ?? "App"
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var osVersion: String {
        #if os(iOS) || os(visionOS)
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #elseif os(macOS)
        return ProcessInfo.processInfo.operatingSystemVersionString
        #else
        return "Unknown"
        #endif
    }

    private var screenResolution: String {
        #if os(iOS) || os(visionOS)
        let bounds = UIScreen.main.bounds
        return "\(Int(bounds.width)) × \(Int(bounds.height))"
        #else
        return "—"
        #endif
    }
}

private enum ProwlSettingsDesign {
    static let brand = Color(red: 0.424, green: 0.361, blue: 0.906)

    static var cardBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color.secondary.opacity(0.08)
        #endif
    }
}

private struct ProwlSettingsIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }
}

private struct ProwlSettingsLabel: View {
    let icon: String
    let tint: Color
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            ProwlSettingsIcon(symbol: icon, tint: tint)
            Text(title)
                .foregroundStyle(.primary)
        }
    }
}

private struct ProwlSettingsToggleRow: View {
    let icon: String
    let tint: Color
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            ProwlSettingsLabel(icon: icon, tint: tint, title: title)
        }
    }
}

private struct ProwlSettingsPickerRow<Selection: Hashable, Content: View>: View {
    let icon: String
    let tint: Color
    let title: String
    @Binding var selection: Selection
    @ViewBuilder let content: () -> Content

    var body: some View {
        Picker(selection: $selection, content: content) {
            ProwlSettingsLabel(icon: icon, tint: tint, title: title)
        }
    }
}
