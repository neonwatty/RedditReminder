import SwiftUI
import SwiftData

struct ProjectsTabView: View {
    @Query(sort: \Project.name) private var projects: [Project]
    @Environment(\.modelContext) private var modelContext

    @State private var newProjectName = ""
    @State private var editingProject: Project?
    @State private var editName = ""

    var body: some View {
        VStack(spacing: 0) {
            addProjectBar
            Divider()
            projectList
        }
    }

    private var addProjectBar: some View {
        HStack(spacing: 8) {
            TextField("New project name...", text: $newProjectName)
                .font(.system(size: 11))
                .textFieldStyle(.plain)
                .padding(7)
                .inputFieldStyle(cornerRadius: 6)
                .onSubmit { addProject() }

            Button(action: addProject) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(canAdd ? AppColors.redditOrange : .secondary)
                    .frame(width: 26, height: 26)
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
            Button("Delete", role: .destructive) { deleteProject(project) }
        }
    }

    private func editingRow(_ project: Project) -> some View {
        Group {
            TextField("Project name", text: $editName)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .onSubmit { finishEditing(project) }

            Button("Done") { finishEditing(project) }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.redditOrange)
                .buttonStyle(.plain)
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
        }
    }

    private var canAdd: Bool {
        ProjectPersistenceActions.isNameAvailable(newProjectName, projects: projects)
    }

    private func isNameAvailable(_ name: String, excluding: Project? = nil) -> Bool {
        ProjectPersistenceActions.isNameAvailable(name, projects: projects, excluding: excluding)
    }

    private func addProject() {
        if ProjectPersistenceActions.addProject(
            named: newProjectName,
            projects: projects,
            modelContext: modelContext
        ) != nil {
            newProjectName = ""
        }
    }

    private func startEditing(_ project: Project) {
        editingProject = project
        editName = project.name
    }

    private func finishEditing(_ project: Project) {
        ProjectPersistenceActions.renameProject(
            project,
            to: editName,
            projects: projects,
            modelContext: modelContext
        )
        editingProject = nil
        editName = ""
    }

    private func deleteProject(_ project: Project) {
        ProjectPersistenceActions.deleteProject(project, modelContext: modelContext)
    }
}
