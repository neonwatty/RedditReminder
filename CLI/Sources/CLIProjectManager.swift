import Foundation
import SwiftData

@MainActor
struct CLIProjectManager {
  let options: CLIOptions
  let context: ModelContext

  func list(query: String?) -> CLIResponse {
    .success(data: .projects(fetchProjects(matching: query).map(ProjectDTO.init)))
  }

  func create(name: String) throws -> CLIResponse {
    let projects = fetchProjects(matching: nil)
    guard let trimmed = ProjectPersistenceActions.normalizedName(name) else {
      throw CLIError.validation("Project name cannot be empty.")
    }
    guard ProjectPersistenceActions.isNameAvailable(trimmed, projects: projects) else {
      throw CLIError.validation("Project already exists: \(trimmed)")
    }
    if options.dryRun {
      return .success(data: .dryRun("Would create project \(trimmed)."))
    }
    let project = Project(name: trimmed)
    context.insert(project)
    try context.save()
    return .success(data: .project(ProjectDTO(project)))
  }

  func update(input: ProjectUpdateInput) throws -> CLIResponse {
    let project = try findProject(input.id)
    let projects = fetchProjects(matching: nil)
    let updatedName = try input.name.map { try validatedName($0, project: project, projects: projects) }
    if options.dryRun {
      return .success(data: .dryRun("Would update project \(project.name)."))
    }
    if let updatedName { project.name = updatedName }
    if input.clearDescription { project.projectDescription = nil }
    if let description = input.description { project.projectDescription = description }
    if input.clearColor { project.color = nil }
    if let color = input.color { project.color = color }
    if input.archive { project.archived = true }
    if input.unarchive { project.archived = false }
    try context.save()
    return .success(data: .project(ProjectDTO(project)))
  }

  func delete(id: String) throws -> CLIResponse {
    let project = try findProject(id)
    if options.dryRun {
      return .success(data: .dryRun("Would delete project \(project.name)."))
    }
    let deletedId = project.id.uuidString
    context.delete(project)
    try context.save()
    return .success(data: .deleted(DeletedDTO(id: deletedId)))
  }

  private func fetchProjects(matching query: String?) -> [Project] {
    let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.name)])
    return CLIFilter.items((try? context.fetch(descriptor)) ?? [], query: query) { project in
      [project.id.uuidString, project.name, project.projectDescription ?? "", project.color ?? ""]
        .joined(separator: " ")
    }
  }

  private func findProject(_ input: String) throws -> Project {
    let normalized = ProjectPersistenceActions.normalizedName(input) ?? input
    let projects = fetchProjects(matching: nil)
    if let project = projects.first(where: {
      $0.id.uuidString == input || $0.name.caseInsensitiveCompare(normalized) == .orderedSame
    }) {
      return project
    }
    throw CLIError.notFound("Project not found: \(input)")
  }

  private func validatedName(_ name: String, project: Project, projects: [Project]) throws -> String {
    guard let trimmed = ProjectPersistenceActions.normalizedName(name) else {
      throw CLIError.validation("Project name cannot be empty.")
    }
    guard ProjectPersistenceActions.isNameAvailable(trimmed, projects: projects, excluding: project)
    else {
      throw CLIError.validation("Project already exists: \(trimmed)")
    }
    return trimmed
  }
}
