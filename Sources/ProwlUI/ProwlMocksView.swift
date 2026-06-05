//
//  ProwlMocksView.swift
//  Prowl
//
//  Created by Elmee on 05/06/26.
//  Copyright © 2026 Elmee. All rights reserved.
//

import SwiftUI
import ProwlCore

/// Lists active mock rules with enable/disable and delete controls.
public struct ProwlMocksView: View {
    @StateObject private var viewModel = ProwlMocksViewModel()

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.rules.isEmpty {
                ProgressView("Loading mocks…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.rules.isEmpty {
                emptyState
            } else {
                rulesList
            }
        }
        .navigationTitle("Active Mocks")
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete All", role: .destructive) {
                    viewModel.deleteAll()
                }
                .disabled(viewModel.rules.isEmpty)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh")
                .disabled(viewModel.rules.isEmpty)
            }
        }
        .task { await viewModel.load() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Active Mocks")
                .font(.headline)
            Text("Create a mock from any captured log, or disable mocks here to restore live API responses.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rulesList: some View {
        List {
            Section {
                Text("Disable or delete mocks to restore normal network responses without restarting the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Mock Rules (\(viewModel.rules.count))") {
                ForEach(viewModel.rules) { rule in
                    mockRow(rule)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.delete(viewModel.rules[index])
                    }
                }
            }
        }
    }

    private func mockRow(_ rule: ProwlMockRule) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                statusBadge(rule.mockStatusCode)

                Toggle(isOn: Binding(
                    get: { rule.isEnabled },
                    set: { _ in viewModel.toggleEnabled(rule) }
                )) {
                    Text(rule.isEnabled ? "Enabled" : "Disabled")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(rule.isEnabled ? .primary : .secondary)
                }
                .toggleStyle(.switch)
            }

            Text(rule.targetURLPattern)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .lineLimit(2)

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
