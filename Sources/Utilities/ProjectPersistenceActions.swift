import Foundation
import SwiftData

@MainActor
enum ProjectPersistenceActions {
    static func normalizedName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func isNameAvailable(_ name: String, projects: [Project], excluding: Project? = nil) -> Bool {
        guard let trimmed = normalizedName(name) else { return false }
        return !projects.contains {
            $0.id != excluding?.id && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    @discardableResult
    static func addProject(
        named name: String,
        projects: [Project],
        modelContext: ModelContext
    ) -> Project? {
        guard let trimmed = normalizedName(name),
              isNameAvailable(trimmed, projects: projects) else { return nil }

        let project = Project(name: trimmed)
        modelContext.insert(project)
        do {
            try modelContext.save()
            return project
        } catch {
            NSLog("RedditReminder: add project failed: \(error)")
            modelContext.delete(project)
            return nil
        }
    }

    @discardableResult
    static func renameProject(
        _ project: Project,
        to name: String,
        projects: [Project],
        modelContext: ModelContext
    ) -> Bool {
        guard let trimmed = normalizedName(name),
              isNameAvailable(trimmed, projects: projects, excluding: project) else { return false }

        let oldName = project.name
        project.name = trimmed
        do {
            try modelContext.save()
            return true
        } catch {
            NSLog("RedditReminder: rename project failed: \(error)")
            project.name = oldName
            return false
        }
    }

    @discardableResult
    static func setArchived(
        _ project: Project,
        archived: Bool,
        modelContext: ModelContext
    ) -> Bool {
        let oldValue = project.archived
        project.archived = archived
        do {
            try modelContext.save()
            return true
        } catch {
            NSLog("RedditReminder: archive toggle failed: \(error)")
            project.archived = oldValue
            return false
        }
    }

    @discardableResult
    static func deleteProject(_ project: Project, modelContext: ModelContext) -> Bool {
        modelContext.delete(project)
        do {
            try modelContext.save()
            return true
        } catch {
            NSLog("RedditReminder: delete project failed: \(error)")
            modelContext.rollback()
            return false
        }
    }
}
