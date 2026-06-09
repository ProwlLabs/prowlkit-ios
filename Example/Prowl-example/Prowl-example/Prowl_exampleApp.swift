import ProwlKit
import SwiftUI

@main
struct Prowl_exampleApp: App {
    init() {
        ProwlExampleBootstrap.install()
    }

    var body: some Scene {
        WindowGroup {
            ProwlExampleRootView()
        }
    }
}
