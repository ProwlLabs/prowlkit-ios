import SwiftUI

struct ProwlExampleNetworkLabView: View {
    @State private var status = "Tap a request to generate traffic."

    var body: some View {
        NavigationView {
            List {
                Section("Live HTTP (captured by Prowl)") {
                    Button("GET /posts") { run("GET /posts", ProwlExampleNetworkLab.fetchPosts) }
                    Button("GET /posts/1 (rewrite header)") { run("GET /posts/1", { try await ProwlExampleNetworkLab.fetchPost(id: 1) }) }
                    Button("GET /posts/999 (mocked)") { run("GET /posts/999", { try await ProwlExampleNetworkLab.fetchPost(id: 999) }) }
                    Button("POST /posts (body snapshot)") { run("POST /posts", ProwlExampleNetworkLab.createPost) }
                }

                Section("Ignored URL") {
                    Button("GET httpbin.org/status/418 (ignored)") {
                        Task {
                            status = "Fetching ignored URL…"
                            await ProwlExampleNetworkLab.fetchIgnoredURL()
                            status = "Should not appear in Prowl (ignored at start)"
                        }
                    }
                }

                Section("Rate alert") {
                    Button("Burst GET /todos × 4") {
                        Task {
                            status = "Bursting todos…"
                            for id in 1 ... 4 {
                                _ = try? await ProwlExampleNetworkLab.fetchPost(id: id)
                                _ = try? await URLSession.shared.data(
                                    from: ProwlExampleNetworkLab.base.appendingPathComponent("todos/\(id)")
                                )
                            }
                            status = "Check inspector for rate alert badge (todos threshold)"
                        }
                    }
                }
            }
            .navigationTitle("Network Lab")
            .safeAreaInset(edge: .bottom) {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.bar)
            }
        }
    }

    private func run(_ label: String, _ work: @escaping () async throws -> Data) {
        Task {
            status = "Running \(label)…"
            do {
                _ = try await work()
                status = "OK: \(label)"
            } catch {
                status = "Error: \(error.localizedDescription)"
            }
        }
    }
}
