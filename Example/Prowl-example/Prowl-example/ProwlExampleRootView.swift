import ProwlKit
import ProwlUI
import SwiftUI

struct ProwlExampleRootView: View {
    @StateObject private var playground = ProwlExampleAPIPlayground()

    var body: some View {
        TabView {
            ProwlExampleNetworkLabView()
                .tabItem { Label("Network", systemImage: "network") }

            ProwlExampleAPIPlaygroundView(playground: playground)
                .tabItem { Label("API", systemImage: "terminal") }

            NavigationView {
                ProwlInspectorView()
                    .navigationTitle("Inspector")
            }
            .tabItem { Label("Inspector", systemImage: "list.bullet.rectangle") }
        }
    }
}
