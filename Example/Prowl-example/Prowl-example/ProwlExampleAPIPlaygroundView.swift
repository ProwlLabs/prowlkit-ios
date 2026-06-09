import SwiftUI

struct ProwlExampleAPIPlaygroundView: View {
    @ObservedObject var playground: ProwlExampleAPIPlayground

    var body: some View {
        NavigationView {
            List {
                statusSection

                Section("Lifecycle") {
                    apiButton("Prowl.show()") { playground.showInspector() }
                    apiButton("Prowl.hide()") { playground.hideInspector() }
                    apiButton("Prowl.toggle()") { playground.toggleInspector() }
                    apiButton("Prowl.stop() → start()") { playground.restart() }
                }

                Section("Runtime flags") {
                    apiButton("Toggle isLoggingEnabled") { playground.toggleLogging() }
                    apiButton("Toggle isSensitiveDataMaskingEnabled") { playground.toggleMasking() }
                    apiButton("Toggle isSessionPersistenceEnabled") { playground.togglePersistence() }
                }

                Section("Ignore rules") {
                    apiButton("Prowl.ignoreURL(_:)") { playground.addIgnoreURL() }
                    apiButton("Prowl.ignoreURL(regex:)") { playground.addIgnoreRegex() }
                    apiButton("Replace ignoredURLs / ignoredURLRegexes") { playground.replaceIgnoreSets() }
                }

                Section("Storage & rate alerts") {
                    apiButton("Prowl.storage()") { playground.run("storage") { await playground.readStorage() } }
                    apiButton("Set endpointRateAlertRules") { playground.setRateAlertRules() }
                    apiButton("resetEndpointRateAlertCounters()") { playground.resetRateAlerts() }
                }

                Section("Mock rules") {
                    apiButton("add / update / save / move / enable") {
                        playground.run("mock CRUD") { await playground.demoMockCRUD() }
                    }
                    apiButton("removeMockRule(id:)") {
                        playground.run("remove mock") { await playground.removeOneMock() }
                    }
                    apiButton("removeAllMockRules()") {
                        playground.run("remove all mocks") { await playground.removeAllMocks() }
                    }
                }

                Section("Rewrite rules") {
                    apiButton("add / update / save / enable") {
                        playground.run("rewrite CRUD") { await playground.demoRewriteCRUD() }
                    }
                    apiButton("removeRequestRewriteRule(id:)") {
                        playground.run("remove rewrite") { await playground.removeOneRewrite() }
                    }
                    apiButton("removeAllRequestRewriteRules()") {
                        playground.run("remove all rewrites") { await playground.removeAllRewrites() }
                    }
                }

                Section("WebSocket & gRPC hooks") {
                    apiButton("logWebSocketEvent × 3") {
                        playground.run("websocket") { await playground.logWebSocketSequence() }
                    }
                    apiButton("logGrpcCall()") {
                        playground.run("grpc") { await playground.logGrpcCall() }
                    }
                }

                Section("Export & search") {
                    apiButton("ProwlLogFormatter.export") {
                        playground.run("export") { await playground.exportLogs() }
                    }
                    apiButton("ProwlSearchParser") {
                        playground.run("search") { await playground.runSearchParser() }
                    }
                    if !playground.exportPreview.isEmpty {
                        Text(playground.exportPreview).font(.caption.monospaced())
                    }
                    if !playground.searchResult.isEmpty {
                        Text(playground.searchResult).font(.caption)
                    }
                }

                Section("Configured at launch") {
                    Label("Prowl.configure(storage:masker:…)", systemImage: "checkmark.circle")
                    Label("Prowl.start(ignoredURLs:ignoredURLRegexes:)", systemImage: "checkmark.circle")
                    Label("customSessionDelegate", systemImage: "checkmark.circle")
                    Label("responseBodyLoggingTransformer", systemImage: "checkmark.circle")
                }
            }
            .navigationTitle("Public API")
        }
    }

    private var statusSection: some View {
        Section("Status") {
            Text(playground.status)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func apiButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
    }
}
