import SwiftUI

struct SidebarContainer: View {
    let panelController: PanelController

    var body: some View {
        ZStack {
            Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.16, alpha: 1.0))

            switch panelController.state {
            case .strip:
                Text("Strip")
                    .foregroundStyle(.secondary)
            case .glance:
                Text("Glance")
                    .foregroundStyle(.secondary)
            case .browse:
                Text("Browse")
                    .foregroundStyle(.secondary)
            case .capture:
                Text("Capture")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
