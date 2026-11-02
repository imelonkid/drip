import SwiftUI

@main
struct DripApp: App {
    @StateObject private var model = CaffeineModel()

    init() {
        UpdateChecker.shared.start()
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environmentObject(model)
        } label: {
            Image(systemName: model.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
        }
        .menuBarExtraStyle(.window)
    }
}
