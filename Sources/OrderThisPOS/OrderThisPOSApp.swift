import SwiftUI

@main
struct OrderThisPOSApp: App {
    @StateObject private var model = POSModel()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model)
                .preferredColorScheme(.light)
        }
    }
}
