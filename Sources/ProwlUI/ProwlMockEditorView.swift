//
//  ProwlMockEditorView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import SwiftUI
import ProwlCore

struct ProwlMockEditorView: View {
    @StateObject private var viewModel: ProwlMockEditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var targetURLPattern: String
    @State private var targetMethod: String
    @State private var mockStatusCodeStr: String
    @State private var responseDelayMillisStr: String
    @State private var mockBodyJSONString: String

    private static let methods = ["ANY", "GET", "POST", "PUT", "PATCH", "DELETE"]

    init(log: NetworkLog) {
        let vm = ProwlMockEditorViewModel(log: log)
        _viewModel = StateObject(wrappedValue: vm)
        _targetURLPattern = State(initialValue: vm.initialURLPattern)
        _targetMethod = State(initialValue: vm.initialMethod)
        _mockStatusCodeStr = State(initialValue: vm.initialStatusCode)
        _responseDelayMillisStr = State(initialValue: vm.initialDelayMillis)
        _mockBodyJSONString = State(initialValue: vm.initialBodyJSON)
    }

    init(rule: ProwlMockRule) {
        let vm = ProwlMockEditorViewModel(rule: rule)
        _viewModel = StateObject(wrappedValue: vm)
        _targetURLPattern = State(initialValue: vm.initialURLPattern)
        _targetMethod = State(initialValue: vm.initialMethod)
        _mockStatusCodeStr = State(initialValue: vm.initialStatusCode)
        _responseDelayMillisStr = State(initialValue: vm.initialDelayMillis)
        _mockBodyJSONString = State(initialValue: vm.initialBodyJSON)
    }

    var body: some View {
        Group {
            #if os(macOS)
            macLayout
            #else
            iosLayout
            #endif
        }
        .onChange(of: viewModel.isSaved) { saved in
            if saved { dismiss() }
        }
    }

    // MARK: - macOS

    #if os(macOS)
    private var macLayout: some View {
        VStack(spacing: 0) {
            macHeader

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    matcherCard
                    responseCard
                    bodyCard
                }
                .padding(20)
            }
        }
        .frame(minWidth: 580, idealWidth: 620, minHeight: 560, idealHeight: 620)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var macHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.isEditing ? "Edit Mock Rule" : "Mock Endpoint")
                    .font(.title3.weight(.semibold))
                if let sourceURL = viewModel.sourceURL {
                    Text(sourceURL)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Button("Save & Enable") { saveMock() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var matcherCard: some View {
        mockCard(title: "Matcher", subtitle: "Intercept requests whose URL contains the pattern below.") {
            mockFieldRow(label: "URL Pattern", hint: "Host and path work best, e.g. jsonplaceholder.typicode.com/posts") {
                TextField("", text: $targetURLPattern, prompt: Text("api.example.com/users"))
                    .textFieldStyle(.roundedBorder)
                    .disableAutocorrection(true)
            }

            mockFieldRow(label: "HTTP Method", hint: "Use ANY to match every method.") {
                Picker("", selection: $targetMethod) {
                    ForEach(Self.methods, id: \.self) { method in
                        Text(method).tag(method)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
            }
        }
    }

    private var responseCard: some View {
        mockCard(title: "Response", subtitle: "Return this status code when the mock matches.") {
            mockFieldRow(label: "Status Code", hint: nil) {
                HStack(spacing: 10) {
                    TextField("", text: $mockStatusCodeStr, prompt: Text("500"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 72)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif

                    statusPresetBar
                }
            }
            mockFieldRow(label: "Response Delay (ms)", hint: "0–60000. Simulates network latency before returning the mock.") {
                TextField("", text: $responseDelayMillisStr, prompt: Text("0"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }
        }
    }

    private var bodyCard: some View {
        mockCard(title: "JSON Body", subtitle: "Paste error JSON from Mock Examples or edit the response payload.") {
            jsonEditor
                .frame(minHeight: 240)
        }
    }

    @ViewBuilder
    private func mockCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func mockFieldRow<Content: View>(
        label: String,
        hint: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.semibold))

            HStack(alignment: .center, spacing: 12) {
                content()
                Spacer(minLength: 0)
            }

            if let hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    #endif

    // MARK: - iOS

    #if !os(macOS)
    private var iosLayout: some View {
        NavigationView {
            Form {
                matcherSection
                responseSection
                bodySection
            }
            .navigationTitle(viewModel.isEditing ? "Edit Mock Rule" : "Mock Endpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Enable") { saveMock() }
                        .font(.body.weight(.semibold))
                        .disabled(!canSave)
                }
            }
        }
    }
    #endif

    // MARK: - iOS form sections

    #if !os(macOS)
    private var matcherSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("URL Pattern")
                    .font(.subheadline.weight(.semibold))
                TextField("api.example.com/users", text: $targetURLPattern)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            if let sourceURL = viewModel.sourceURL {
                Text(sourceURL)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Picker("HTTP Method", selection: $targetMethod) {
                ForEach(Self.methods, id: \.self) { method in
                    Text(method).tag(method)
                }
            }
        } header: {
            Text("Matcher")
        } footer: {
            Text("Matches requests whose URL contains this text (case-insensitive).")
        }
    }

    private var responseSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Status Code")
                    .font(.subheadline.weight(.semibold))
                TextField("500", text: $mockStatusCodeStr)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .frame(maxWidth: 80)
            }
            statusPresetBar
            VStack(alignment: .leading, spacing: 6) {
                Text("Response Delay (ms)")
                    .font(.subheadline.weight(.semibold))
                TextField("0", text: $responseDelayMillisStr)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .frame(maxWidth: 100)
            }
        } header: {
            Text("Response")
        } footer: {
            Text("Delay simulates latency (0–60000 ms) before the mock response is returned.")
        }
    }

    private var bodySection: some View {
        Section {
            jsonEditor
                .frame(minHeight: 200)
        } header: {
            Text("JSON Body")
        }
    }
    #endif

    private var statusPresetBar: some View {
        HStack(spacing: 8) {
            ForEach(ProwlMockEditorViewModel.statusPresets, id: \.self) { code in
                Button {
                    mockStatusCodeStr = "\(code)"
                    applyPresetBody(for: code)
                } label: {
                    Text("\(code)")
                        .font(.caption.weight(.semibold).monospaced())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            mockStatusCodeStr == "\(code)"
                                ? statusColor(code).opacity(0.18)
                                : Color.secondary.opacity(0.08),
                            in: Capsule()
                        )
                        .foregroundStyle(statusColor(code))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var jsonEditor: some View {
        TextEditor(text: $mockBodyJSONString)
            .font(.system(.body, design: .monospaced))
            #if os(macOS)
            .padding(10)
            .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            #else
            .frame(minHeight: 200)
            #endif
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !targetURLPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveMock() {
        viewModel.handle(.save(
            urlPattern: targetURLPattern,
            method: targetMethod,
            statusCodeStr: mockStatusCodeStr,
            delayMillisStr: responseDelayMillisStr,
            bodyJSON: mockBodyJSONString
        ))
    }

    private func applyPresetBody(for code: Int) {
        switch code {
        case 401:
            mockBodyJSONString = """
            {
              "error": "Unauthorized",
              "message": "Invalid or expired access token"
            }
            """
        case 404:
            mockBodyJSONString = """
            {
              "error": "Not Found",
              "message": "The requested resource does not exist"
            }
            """
        case 500:
            mockBodyJSONString = """
            {
              "error": "Internal Server Error",
              "message": "Something went wrong on the server"
            }
            """
        case 503:
            mockBodyJSONString = """
            {
              "error": "Service Unavailable",
              "message": "Service is temporarily unavailable"
            }
            """
        default:
            break
        }
    }

    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200...299: .green
        case 400...499: .orange
        case 500...599: .red
        default: .secondary
        }
    }
}
