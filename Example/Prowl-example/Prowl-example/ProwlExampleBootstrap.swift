import Foundation
import ProwlKit
import ProwlCore

@MainActor
enum ProwlExampleBootstrap {
    static func install() {
        Task { @MainActor in
            await configure()
            start()
            await seedRules()
        }
    }

    private static func configure() async {
        let storage = ProwlStorage(limit: 300)
        let masker = SensitiveDataMasker(
            sensitiveHeaders: ["authorization", "x-api-key"],
            sensitiveJSONKeys: ["password", "token", "accessToken"]
        )

        Prowl.customSessionDelegate = ProwlExampleSessionDelegate()
        Prowl.responseBodyLoggingTransformer = ProwlExampleResponseTransform()
        Prowl.isSessionPersistenceEnabled = true
        Prowl.endpointRateAlertRules = [
            .init(match: .urlContains("jsonplaceholder.typicode.com/posts"), threshold: 5)
        ]

        await Prowl.configure(
            storage: storage,
            masker: masker,
            isLoggingEnabled: true,
            isSensitiveDataMaskingEnabled: false
        )
    }

    private static func start() {
        Prowl.start(
            ignoredURLs: ["https://httpbin.org/status/418"],
            ignoredURLRegexes: [#"https://.*\.internal\.example/.*"#]
        )
    }

    private static func seedRules() async {
        let existingMocks = await Prowl.mockRules()
        if existingMocks.isEmpty {
            await Prowl.addMockRule(
                ProwlMockRule(
                    targetURLPattern: "jsonplaceholder.typicode.com/posts/999",
                    targetMethod: "GET",
                    mockStatusCode: 200,
                    mockBody: Data(#"{"id":999,"title":"Prowl mock","body":"Seeded by Prowl-example"}"#.utf8),
                    mockHeaders: ["Content-Type": "application/json; charset=utf-8"],
                    responseDelayMillis: 200
                )
            )
        }

        let existingRewrites = await Prowl.requestRewriteRules()
        if existingRewrites.isEmpty {
            await Prowl.addRequestRewriteRule(
                ProwlRequestRewriteRule(
                    targetURLPattern: "jsonplaceholder.typicode.com/posts/1",
                    targetMethod: "GET",
                    headerOverrides: ["X-Prowl-Example": "rewrite-active"]
                )
            )
        }
    }
}
