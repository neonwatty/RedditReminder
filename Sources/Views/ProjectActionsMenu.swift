import SwiftUI

struct ProjectActionsMenu: View {
  let project: Project
  let onRename: () -> Void
  let onToggleArchive: () -> Void
  let onDelete: () -> Void

  var body: some View {
    Menu {
      Button(ProjectsTabView.renameAccessibilityLabel, action: onRename)
      Button(
        project.archived
          ? ProjectsTabView.unarchiveAccessibilityLabel : ProjectsTabView.archiveAccessibilityLabel,
        action: onToggleArchive
      )
      Divider()
      Button(ProjectsTabView.deleteAccessibilityLabel, role: .destructive, action: onDelete)
    } label: {
      Image(systemName: "ellipsis.circle")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 32, height: 32)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .help(ProjectsTabView.moreActionsAccessibilityLabel)
    .accessibilityLabel(ProjectsTabView.moreActionsAccessibilityLabel)
    .accessibilityIdentifier("projects.row.\(project.id.uuidString).actions")
  }
}
