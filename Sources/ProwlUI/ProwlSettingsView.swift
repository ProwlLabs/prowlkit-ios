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
    
    @Environment(\.dismiss) private var dismiss
    @AppStorage("prowl_color_scheme") private var themeRaw: Int = 0
    @State private var isLoggingEnabled = true
    @State private var isSensitiveDataMaskingEnabled = false
    
    init(
        viewModel: ProwlInspectorViewModel,
        onExportText: @escaping () -> Void,
        onExportCURL: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onExportText = onExportText
        self.onExportCURL = onExportCURL
        _isLoggingEnabled = State(initialValue: ProwlRuntime.isLoggingEnabled)
        _isSensitiveDataMaskingEnabled = State(initialValue: ProwlRuntime.isSensitiveDataMaskingEnabled)
    }

    var body: some View {
        Group {
            #if os(macOS)
            macSettingsLayout
            #else
            defaultSettingsLayout
            #endif
        }
        .navigationTitle("Settings")
        .onChange(of: isLoggingEnabled) { isEnabled in
            ProwlRuntime.isLoggingEnabled = isEnabled
        }
        .onChange(of: isSensitiveDataMaskingEnabled) { isEnabled in
            ProwlRuntime.isSensitiveDataMaskingEnabled = isEnabled
        }
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Dismiss")
            }
        }
        #endif
    }

    private var defaultSettingsLayout: some View {
        Form {
            Section(header: Text("Statistics")) {
                labeledStatRow(title: "Total Requests", value: "\(viewModel.logs.count)")
                labeledStatRow(title: "Success Rate (2xx)", value: successRateString)
                labeledStatRow(title: "Total Errors (4xx/5xx)", value: "\(errorCount)")
            }

            Section(header: Text("Filters")) {
                Picker("Response Status", selection: $viewModel.statusFilter) {
                    ForEach(ProwlStatusCategory.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }

                Picker("Content Type", selection: $viewModel.contentTypeFilter) {
                    ForEach(ProwlContentTypeCategory.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
            }

            Section(header: Text("Appearance")) {
                Picker("Theme", selection: $themeRaw) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(.segmented)
            }

            loggingSection
            sensitiveDataSection

            Section(header: Text("Export & Share")) {
                exportJSONButton
                exportCURLButton
                Text("Export data for debugging and issue reporting.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Environment Info")) {
                labeledStatRow(title: "App Name", value: appName)
                labeledStatRow(title: "App Version", value: appVersion)
                labeledStatRow(title: "Minimum OS", value: minOSVersion)
                labeledStatRow(title: "OS Version", value: osVersion)
                labeledStatRow(title: "Screen Size", value: screenResolution)
            }
        }
    }

    #if os(macOS)
    private var macSettingsLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                macSection("Statistics") {
                    labeledStatRow(title: "Total Requests", value: "\(viewModel.logs.count)")
                    labeledStatRow(title: "Success Rate (2xx)", value: successRateString)
                    labeledStatRow(title: "Total Errors (4xx/5xx)", value: "\(errorCount)")
                }

                macSection("Filters") {
                    VStack(alignment: .leading, spacing: 10) {
                        labeledControlRow(title: "Response Status") {
                            Picker("Response Status", selection: $viewModel.statusFilter) {
                                ForEach(ProwlStatusCategory.allCases) { filter in
                                    Text(filter.title).tag(filter)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                        }

                        labeledControlRow(title: "Content Type") {
                            Picker("Content Type", selection: $viewModel.contentTypeFilter) {
                                ForEach(ProwlContentTypeCategory.allCases) { filter in
                                    Text(filter.rawValue).tag(filter)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                        }
                    }
                }

                macSection("Appearance") {
                    labeledControlRow(title: "Theme") {
                        Picker("Theme", selection: $themeRaw) {
                            Text("System").tag(0)
                            Text("Light").tag(1)
                            Text("Dark").tag(2)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 230)
                    }
                }

                macSection("Sensitive Data") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Mask sensitive data", isOn: $isSensitiveDataMaskingEnabled)
                        Text("Default OFF. When ON, Prowl redacts values like Authorization bearer tokens, cookies, private keys, and common secret fields.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                macSection("Logging") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Enable request logging", isOn: $isLoggingEnabled)
                        Text("When OFF, Prowl inspector stays available but request interception is paused.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                macSection("Export & Share") {
                    HStack(spacing: 10) {
                        if #available(macOS 13.0, *) {
                            ShareLink(item: formattedTextExportContent) {
                                Label("Share / Email Logs (JSON)", systemImage: "envelope")
                            }
                            ShareLink(item: curlExportContent) {
                                Label("Share cURL Commands", systemImage: "terminal")
                            }
                        } else {
                            Button {
                                onExportText()
                            } label: {
                                Label("Export Logs (JSON)", systemImage: "envelope")
                            }
                            Button {
                                onExportCURL()
                            } label: {
                                Label("Export cURL Commands", systemImage: "terminal")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                macSection("Environment Info") {
                    labeledStatRow(title: "App Name", value: appName)
                    labeledStatRow(title: "App Version", value: appVersion)
                    labeledStatRow(title: "Minimum OS", value: minOSVersion)
                    labeledStatRow(title: "OS Version", value: osVersion)
                    labeledStatRow(title: "Screen Size", value: screenResolution)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func macSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    #endif

    private var successRateString: String {
        let total = viewModel.logs.count
        guard total > 0 else { return "0%" }
        let successCount = viewModel.logs.filter { ($0.statusCode ?? 0) >= 200 && ($0.statusCode ?? 0) < 300 }.count
        let percentage = (Double(successCount) / Double(total)) * 100
        return String(format: "%.1f%%", percentage)
    }

    private var loggingSection: some View {
        Section(header: Text("Logging")) {
            Toggle("Enable request logging", isOn: $isLoggingEnabled)
            Text("When OFF, Prowl inspector stays available but request interception is paused.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var sensitiveDataSection: some View {
        Section(header: Text("Sensitive Data")) {
            Toggle("Mask sensitive data", isOn: $isSensitiveDataMaskingEnabled)
            Text("Default OFF. When ON, Prowl redacts values like Authorization bearer tokens, cookies, private keys, and common secret fields.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var errorCount: Int {
        viewModel.logs.filter { ($0.statusCode ?? 0) >= 400 || $0.errorDescription != nil }.count
    }

    private var appName: String {
        (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? 
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String) ?? ""
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var minOSVersion: String {
        Bundle.main.infoDictionary?["MinimumOSVersion"] as? String ?? "Not Specified"
    }

    private var osVersion: String {
    #if os(iOS) || os(visionOS)
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    #elseif os(macOS)
        return "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
    #else
        return "Unknown OS"
    #endif
    }

    private var screenResolution: String {
    #if os(iOS) || os(visionOS)
        let bounds = UIScreen.main.bounds
        return "\(Int(bounds.width)) x \(Int(bounds.height))"
    #else
        return "Undefined"
    #endif
    }

    private var formattedTextExportContent: String {
        ProwlLogFormatter.export(logs: viewModel.filteredLogs, as: .formattedText)
    }

    private var curlExportContent: String {
        ProwlLogFormatter.export(logs: viewModel.filteredLogs, as: .curlCommands)
    }

    private var exportJSONButton: some View {
        Button(role: .none, action: {
            #if os(macOS)
            onExportText()
            #else
            dismiss()

            // Adding slight delay allowing modal dismissal animation to complete
            // before prompting UIActivityViewController to avoid hierarchy alerts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onExportText()
            }
            #endif
        }) {
            exportActionLabel(
                title: "Share / Email Logs (JSON)",
                subtitle: "Readable request/response dump",
                systemImage: "envelope",
                tint: .blue
            )
        }
        .buttonStyle(.plain)
    }

    private var exportCURLButton: some View {
        Button(role: .none, action: {
            #if os(macOS)
            onExportCURL()
            #else
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onExportCURL()
            }
            #endif
        }) {
            exportActionLabel(
                title: "Share cURL Commands",
                subtitle: "Replay requests quickly in terminal",
                systemImage: "terminal",
                tint: .orange
            )
        }
        .buttonStyle(.plain)
    }

    private func exportActionLabel(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func labeledStatRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeledControlRow<Content: View>(
        title: String,
        @ViewBuilder control: () -> Content
    ) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer(minLength: 12)
            control()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
