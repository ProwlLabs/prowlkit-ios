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
    @State private var mockStatusCodeStr: String = "200"
    @State private var mockBodyJSONString: String

    init(log: NetworkLog) {
        let vm = ProwlMockEditorViewModel(log: log)
        _viewModel = StateObject(wrappedValue: vm)
        _targetURLPattern = State(initialValue: vm.initialURLPattern)
        _mockBodyJSONString = State(initialValue: vm.initialBodyJSON)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Matcher Rules (URL Contains)")) {
                    TextField("Enter URL pattern to mock", text: $targetURLPattern)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                }

                Section(header: Text("Response Status Code")) {
                    TextField("e.g. 200, 404, 500", text: $mockStatusCodeStr)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }

                Section(header: Text("Response Body (JSON Mock)")) {
                    TextEditor(text: $mockBodyJSONString)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 200)
                }
            }
            .navigationTitle("Mock Endpoint")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Dismiss")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Enable") {
                        viewModel.handle(.save(
                            urlPattern: targetURLPattern,
                            statusCodeStr: mockStatusCodeStr,
                            bodyJSON: mockBodyJSONString
                        ))
                    }
                    .font(.headline)
                }
            }
        }
        .onChange(of: viewModel.isSaved) { saved in
            if saved { dismiss() }
        }
    }
}
