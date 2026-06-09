//
//  ProwlRequestRewriteEditorView.swift
//  Prowl
//
//  Created by Elmee on 16/04/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import SwiftUI
import ProwlCore

struct ProwlRequestRewriteEditorView: View {
    @StateObject private var viewModel: ProwlRequestRewriteEditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var targetURLPattern: String
    @State private var targetMethod: String
    @State private var replacementURL: String
    @State private var headerOverrides: String
    @State private var headersToRemove: String
    @State private var bodyText: String
    @State private var contentType: String
    @State private var replaceBody: Bool

    private static let methods = ["ANY", "GET", "POST", "PUT", "PATCH", "DELETE"]

    init(log: NetworkLog) {
        let vm = ProwlRequestRewriteEditorViewModel(log: log)
        _viewModel = StateObject(wrappedValue: vm)
        _targetURLPattern = State(initialValue: vm.initialURLPattern)
        _targetMethod = State(initialValue: vm.initialMethod)
        _replacementURL = State(initialValue: vm.initialReplacementURL)
        _headerOverrides = State(initialValue: vm.initialHeaderOverrides)
        _headersToRemove = State(initialValue: vm.initialHeadersToRemove)
        _bodyText = State(initialValue: vm.initialBody)
        _contentType = State(initialValue: vm.initialContentType)
        _replaceBody = State(initialValue: vm.initialReplaceBody)
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

    #if os(macOS)
    private var macLayout: some View {
        VStack(spacing: 0) {
            macHeader
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    matcherCard
                    rewriteCard
                    headersCard
                    bodyCard
                }
                .padding(20)
            }
        }
        .frame(minWidth: 580, idealWidth: 620, minHeight: 620, idealHeight: 680)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var macHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rewrite Request")
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
            Button("Save & Enable") { saveRewrite() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    #endif

    #if !os(macOS)
    private var iosLayout: some View {
        NavigationView {
            Form {
                matcherSection
                rewriteSection
                headersSection
                bodySection
            }
            .navigationTitle("Rewrite Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Enable") { saveRewrite() }
                        .font(.body.weight(.semibold))
                        .disabled(!canSave)
                }
            }
        }
    }
    #endif

    #if os(macOS)
    private var matcherCard: some View {
        editorCard(title: "Matcher", subtitle: "Apply this rewrite when the request URL contains the pattern.") {
            editorField(label: "URL Pattern") {
                TextField("", text: $targetURLPattern, prompt: Text("api.example.com/users"))
                    .textFieldStyle(.roundedBorder)
            }
            editorField(label: "HTTP Method") {
                Picker("", selection: $targetMethod) {
                    ForEach(Self.methods, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: 120)
            }
        }
    }

    private var rewriteCard: some View {
        editorCard(title: "URL", subtitle: "Full URL or path. Leave blank to keep the original URL.") {
            editorField(label: "Replacement URL") {
                TextField("", text: $replacementURL, prompt: Text("https://staging.api.com/v2/users"))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var headersCard: some View {
        editorCard(title: "Headers", subtitle: "One header per line. Comma-separated names to remove.") {
            editorField(label: "Header Overrides") {
                TextEditor(text: $headerOverrides)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100)
            }
            editorField(label: "Remove Headers") {
                TextField("", text: $headersToRemove, prompt: Text("Cookie, X-Old-Header"))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var bodyCard: some View {
        editorCard(title: "Body", subtitle: "Optionally replace the request body before it is sent.") {
            Toggle("Replace body", isOn: $replaceBody)
            if replaceBody {
                editorField(label: "Content-Type") {
                    TextField("", text: $contentType, prompt: Text("application/json"))
                        .textFieldStyle(.roundedBorder)
                }
                TextEditor(text: $bodyText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 180)
            }
        }
    }

    @ViewBuilder
    private func editorCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func editorField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.semibold))
            content()
        }
    }
    #endif

    #if !os(macOS)
    private var matcherSection: some View {
        Section {
            TextField("api.example.com/users", text: $targetURLPattern)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            if let sourceURL = viewModel.sourceURL {
                Text(sourceURL)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Picker("HTTP Method", selection: $targetMethod) {
                ForEach(Self.methods, id: \.self) { Text($0).tag($0) }
            }
        } header: {
            Text("Matcher")
        }
    }

    private var rewriteSection: some View {
        Section {
            TextField("https://staging.api.com/v2/users", text: $replacementURL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        } header: {
            Text("Replacement URL")
        } footer: {
            Text("Full URL or path. Leave blank to keep the original URL.")
        }
    }

    private var headersSection: some View {
        Section {
            TextEditor(text: $headerOverrides)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 100)
            TextField("Cookie, X-Old-Header", text: $headersToRemove)
                .autocapitalization(.none)
        } header: {
            Text("Headers")
        } footer: {
            Text("Overrides: one `Name: value` per line. Remove: comma-separated header names.")
        }
    }

    private var bodySection: some View {
        Section {
            Toggle("Replace body", isOn: $replaceBody)
            if replaceBody {
                TextField("application/json", text: $contentType)
                    .autocapitalization(.none)
                TextEditor(text: $bodyText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 160)
            }
        } header: {
            Text("Body")
        }
    }
    #endif

    private var canSave: Bool {
        !targetURLPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveRewrite() {
        viewModel.save(
            urlPattern: targetURLPattern,
            method: targetMethod,
            replacementURL: replacementURL,
            headerOverridesText: headerOverrides,
            headersToRemoveText: headersToRemove,
            bodyText: bodyText,
            contentType: contentType,
            replaceBody: replaceBody
        )
    }
}
