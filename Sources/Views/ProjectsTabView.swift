import SwiftData
import SwiftUI

struct ProjectsTabView: View {
  nonisolated static let moreActionsAccessibilityLabel = "More project actions"
  nonisolated static let renameAccessibilityLabel = "Rename project"
  nonisolated static let archiveAccessibilityLabel = "Archive project"
  nonisolated static let unarchiveAccessibilityLabel = "Unarchive project"
  nonisolated static let deleteAccessibilityLabel = "Delete project"

  @Query(sort: \Project.name) private var projects: [Project]
  @Environment(\.modelContext) private var modelContext

  @State private var newProjectName = ""
  @State private var editingProject: Project?
  @State private var editName = ""
  @State private var projectFeedbackMessage: String?
  @State private var editFeedbackMessage: String?
  @State private var projectPendingDeletion: Project?

  var body: some View {
    VStack(spacing: 0) {
      addProjectBar
      Divider()
      projectList
    }
    .alert(
      "Delete Project?", isPresented: deleteConfirmationIsPresented,
      presenting: projectPendingDeletion
    ) {
      project in
      Button("Delete", role: .destructive) {
        deleteProject(project)
        projectPendingDeletion = nil
      }
      Button("Cancel", role: .cancel) {
        projectPendingDeletion = nil
      }
    } message: { project in
      Text(deleteConfirmationMessage(for: project))
    }
  }

  private var addProjectBar: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        TextField("New project name...", text: $newProjectName)
          .font(.system(size: 11))
          .textFieldStyle(.plain)
          .padding(7)
          .inputFieldStyle(cornerRadius: 6)
          .onChange(of: newProjectName) {
            projectFeedbackMessage = projectValidationMessage(for: newProjectName)
          }
          .onSubmit { addProject() }

        Button(action: addProject) {
          Image(systemName: "plus")
            .font(.system(size: 14, weight: .light))
            .foregroundStyle(canAdd ? AppColors.redditOrange : .secondary)
            .frame(width: 32, height: 32)
            .background(
              canAdd
                ? AppColors.redditOrange.opacity(0.15)
                : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(!canAdd)
      }

      if let projectFeedbackMessage {
        Text(projectFeedbackMessage)
          .font(.system(size: 10))
          .foregroundStyle(.red)
          .accessibilityIdentifier("projects.add.feedback")
      }
    }
    .padding(12)
  }

  private var projectList: some View {
    ScrollView {
      VStack(spacing: 0) {
        let activeProjects = projects.filter { !$0.archived }
        let archivedProjects = projects.filter { $0.archived }

        if activeProjects.isEmpty && archivedProjects.isEmpty {
          emptyState
        }

        ForEach(activeProjects, id: \.id) { project in
          projectRow(project)
          if project.id != activeProjects.last?.id || !archivedProjects.isEmpty {
            Divider().padding(.horizontal, 12)
          }
        }

        if !archivedProjects.isEmpty {
          archivedHeader
          ForEach(archivedProjects, id: \.id) { project in
            projectRow(project)
            if project.id != archivedProjects.last?.id {
              Divider().padding(.horizontal, 12)
            }
          }
        }
      }
      .padding(.vertical, 8)
    }
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Text("No projects yet")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
      Text("Projects help organize your captures")
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 40)
  }

  private var archivedHeader: some View {
    HStack {
      Text("ARCHIVED")
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.tertiary)
        .tracking(0.3)
      Spacer()
    }
    .padding(.horizontal, 12)
    .padding(.top, 12)
    .padding(.bottom, 4)
  }

  private func projectRow(_ project: Project) -> some View {
    HStack(spacing: 10) {
      if editingProject?.id == project.id {
        editingRow(project)
      } else {
        displayRow(project)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .contentShape(Rectangle())
    .contextMenu {
      Button("Rename") { startEditing(project) }
      Button(project.archived ? "Unarchive" : "Archive") {
        ProjectPersistenceActions.setArchived(
          project,
          archived: !project.archived,
          modelContext: modelContext
        )
      }
      Divider()
      Button("Delete", role: .destructive) { requestDeleteProject(project) }
    }
  }

  private func editingRow(_ project: Project) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        TextField("Project name", text: $editName)
          .font(.system(size: 12))
          .textFieldStyle(.plain)
          .onChange(of: editName) {
            editFeedbackMessage = projectValidationMessage(for: editName, excluding: project)
          }
          .onSubmit { finishEditing(project) }

        Button("Done") { finishEditing(project) }
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(AppColors.redditOrange)
          .buttonStyle(.plain)
      }

      if let editFeedbackMessage {
        Text(editFeedbackMessage)
          .font(.system(size: 10))
          .foregroundStyle(.red)
          .accessibilityIdentifier("projects.edit.feedback")
      }
    }
  }

  private func displayRow(_ project: Project) -> some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(project.name)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(project.archived ? .secondary : .primary)
        if let desc = project.projectDescription, !desc.isEmpty {
          Text(desc)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Text("\(project.captures.count) capture\(project.captures.count == 1 ? "" : "s")")
          .font(.system(size: 10))
          .foregroundStyle(.tertiary)
      }
      Spacer()
      ProjectActionsMenu(
        project: project,
        onRename: { startEditing(project) },
        onToggleArchive: {
          ProjectPersistenceActions.setArchived(
            project,
            archived: !project.archived,
            modelContext: modelContext
          )
        },
        onDelete: { requestDeleteProject(project) }
      )
    }
  }

  private var canAdd: Bool {
    ProjectPersistenceActions.isNameAvailable(newProjectName, projects: projects)
  }

  private func isNameAvailable(_ name: String, excluding: Project? = nil) -> Bool {
    ProjectPersistenceActions.isNameAvailable(name, projects: projects, excluding: excluding)
  }

  private func projectValidationMessage(for name: String, excluding: Project? = nil) -> String? {
    guard let normalized = ProjectPersistenceActions.normalizedName(name) else { return nil }
    return isNameAvailable(normalized, excluding: excluding)
      ? nil : "A project with this name already exists."
  }

  private func addProject() {
    if ProjectPersistenceActions.addProject(
      named: newProjectName,
      projects: projects,
      modelContext: modelContext
    ) != nil {
      newProjectName = ""
      projectFeedbackMessage = nil
    } else {
      projectFeedbackMessage =
        projectValidationMessage(for: newProjectName) ?? "Enter a project name."
    }
  }

  private func startEditing(_ project: Project) {
    editingProject = project
    editName = project.name
    editFeedbackMessage = nil
  }

  private func finishEditing(_ project: Project) {
    guard
      ProjectPersistenceActions.renameProject(
        project,
        to: editName,
        projects: projects,
        modelContext: modelContext
      )
    else {
      editFeedbackMessage =
        projectValidationMessage(for: editName, excluding: project) ?? "Enter a project name."
      return
    }
    editingProject = nil
    editName = ""
    editFeedbackMessage = nil
  }

  private var deleteConfirmationIsPresented: Binding<Bool> {
    Binding(
      get: { projectPendingDeletion != nil },
      set: { isPresented in
        if !isPresented {
          projectPendingDeletion = nil
        }
      }
    )
  }

  private func requestDeleteProject(_ project: Project) {
    projectPendingDeletion = project
  }

  private func deleteConfirmationMessage(for project: Project) -> String {
    let captureCount = project.captures.count
    let captureText = "\(captureCount) capture\(captureCount == 1 ? "" : "s")"
    return "Deleting \(project.name) will also delete \(captureText). This cannot be undone."
  }

  private func deleteProject(_ project: Project) {
    ProjectPersistenceActions.deleteProject(project, modelContext: modelContext)
  }
}
