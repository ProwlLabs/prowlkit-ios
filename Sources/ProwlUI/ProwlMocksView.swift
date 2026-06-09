//
//  ProwlMocksView.swift
//  Prowl
//

import SwiftUI
import ProwlCore

/// Lists active mock and request-rewrite rules with enable/disable, priority, and delete controls.
public struct ProwlMocksView: View {
    @StateObject private var viewModel = ProwlMocksViewModel()
    @State private var selectedTab = 0
    @State private var editingMockRule: ProwlMockRule?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            tabPicker
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Group {
                if viewModel.isLoading && isCurrentTabEmpty {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isCurrentTabEmpty {
                    emptyState
                } else if selectedTab == 0 {
                    mockRulesList
                } else {
                    rewriteRulesList
                }
            }
        }
        .navigationTitle("Mocks & Rewrites")
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete All", role: .destructive) {
                    if selectedTab == 0 {
                        viewModel.deleteAllMocks()
                    } else {
                        viewModel.deleteAllRewrites()
                    }
                }
                .disabled(isCurrentTabEmpty)
            }
        }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .prowlMockRulesDidChange)) { _ in
            Task { await viewModel.reloadMocks() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .prowlRewriteRulesDidChange)) { _ in
            Task { await viewModel.reloadRewrites() }
        }
        .sheet(item: $editingMockRule) { rule in
            #if os(macOS)
            ProwlMockEditorView(rule: rule)
                .frame(minWidth: 580, minHeight: 560)
            #else
            ProwlMockEditorView(rule: rule)
            #endif
        }
    }

    private var isCurrentTabEmpty: Bool {
        selectedTab == 0 ? viewModel.mockRules.isEmpty : viewModel.rewriteRules.isEmpty
    }

    private var tabPicker: some View {
        Picker("Rule type", selection: $selectedTab) {
            Text("Response Mocks").tag(0)
            Text("Request Rewrites").tag(1)
        }
        .pickerStyle(.segmented)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: selectedTab == 0 ? "wand.and.stars" : "arrow.triangle.branch")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(selectedTab == 0 ? "No Response Mocks" : "No Request Rewrites")
                .font(.headline)
            Text(selectedTab == 0
                 ? "Create a mock from any captured log to return synthetic responses."
                 : "Create a rewrite from any captured log to modify outbound requests.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mockRulesList: some View {
        List {
            Section {
                Text("First matching rule wins. Use arrows to change priority.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Mock Rules (\(viewModel.mockRules.count))") {
                ForEach(Array(viewModel.mockRules.enumerated()), id: \.element.id) { index, rule in
                    mockRow(rule, priority: index + 1, canMoveUp: index > 0, canMoveDown: index < viewModel.mockRules.count - 1)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteMock(viewModel.mockRules[index])
                    }
                }
            }
        }
    }

    private var rewriteRulesList: some View {
        List {
            Section("Rewrite Rules (\(viewModel.rewriteRules.count))") {
                ForEach(viewModel.rewriteRules) { rule in
                    rewriteRow(rule)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteRewrite(viewModel.rewriteRules[index])
                    }
                }
            }
        }
    }

    private func mockRow(_ rule: ProwlMockRule, priority: Int, canMoveUp: Bool, canMoveDown: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("#\(priority)")
                    .font(.caption2.weight(.bold).monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)

                statusBadge(rule.mockStatusCode)

                if rule.responseDelayMillis > 0 {
                    Text("\(rule.responseDelayMillis)ms")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Button { viewModel.moveMockUp(rule) } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canMoveUp)

                    Button { viewModel.moveMockDown(rule) } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canMoveDown)
                }

                Toggle(isOn: Binding(
                    get: { rule.isEnabled },
                    set: { _ in viewModel.toggleMockEnabled(rule) }
                )) {
                    EmptyView()
                }
                .labelsHidden()
            }

            Text(rule.targetURLPattern)
                .font(.caption.monospaced())
                .lineLimit(2)
                .contentShape(Rectangle())
                .onTapGesture { editingMockRule = rule }

            HStack(spacing: 8) {
                Text(rule.targetMethod)
                    .font(.caption2.weight(.bold).monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: Capsule())

                if !rule.mockBodyText.isEmpty {
                    Text(rule.mockBodyText)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(rule.isEnabled ? 1 : 0.55)
    }

    private func rewriteRow(_ rule: ProwlRequestRewriteRule) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(isOn: Binding(
                    get: { rule.isEnabled },
                    set: { _ in viewModel.toggleRewriteEnabled(rule) }
                )) {
                    Text(rule.isEnabled ? "Enabled" : "Disabled")
                        .font(.caption.weight(.semibold))
                }
                .toggleStyle(.switch)
            }

            Text(rule.targetURLPattern)
                .font(.caption.monospaced())
                .lineLimit(2)

            HStack(spacing: 8) {
                Text(rule.targetMethod)
                    .font(.caption2.weight(.bold).monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12), in: Capsule())

                if !rule.replacementURL.isEmpty {
                    Text("→ \(rule.replacementURL)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(rule.isEnabled ? 1 : 0.55)
    }

    private func statusBadge(_ code: Int) -> some View {
        Text("\(code)")
            .font(.caption.weight(.bold).monospaced())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(code).opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor(code))
    }

    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200...299: .green
        case 400...499: .orange
        case 500...599: .red
        default: .gray
        }
    }
}
