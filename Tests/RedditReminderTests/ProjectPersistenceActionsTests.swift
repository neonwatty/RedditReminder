import Foundation
import SwiftData
import Testing
@testable import RedditReminder

private func makeProjectActionsContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self,
        configurations: config
    )
}

@Test @MainActor func projectNameNormalizationTrimsWhitespace() {
    #expect(ProjectPersistenceActions.normalizedName("  Launch Plan \n") == "Launch Plan")
}

@Test @MainActor func projectNameNormalizationRejectsBlank() {
    #expect(ProjectPersistenceActions.normalizedName(" \n\t ") == nil)
}

@Test @MainActor func projectNameAvailabilityIsCaseInsensitive() {
    let existing = Project(name: "Launch")

    #expect(!ProjectPersistenceActions.isNameAvailable("launch", projects: [existing]))
    #expect(!ProjectPersistenceActions.isNameAvailable(" LAUNCH ", projects: [existing]))
    #expect(ProjectPersistenceActions.isNameAvailable("Roadmap", projects: [existing]))
}

@Test @MainActor func projectNameAvailabilityAllowsCurrentProjectWhenRenaming() {
    let existing = Project(name: "Launch")

    #expect(ProjectPersistenceActions.isNameAvailable("launch", projects: [existing], excluding: existing))
}

@Test @MainActor func addProjectPersistsTrimmedName() throws {
    let container = try makeProjectActionsContainer()
    let context = ModelContext(container)

    let project = ProjectPersistenceActions.addProject(
        named: "  Launch  ",
        projects: [],
        modelContext: context
    )

    let fetched = try context.fetch(FetchDescriptor<Project>())
    #expect(project != nil)
    #expect(fetched.map(\.name) == ["Launch"])
}

@Test @MainActor func addProjectRejectsDuplicateName() throws {
    let container = try makeProjectActionsContainer()
    let context = ModelContext(container)
    let existing = Project(name: "Launch")
    context.insert(existing)
    try context.save()

    let project = ProjectPersistenceActions.addProject(
        named: "launch",
        projects: [existing],
        modelContext: context
    )

    #expect(project == nil)
    #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)
}

@Test @MainActor func renameProjectPersistsTrimmedName() throws {
    let container = try makeProjectActionsContainer()
    let context = ModelContext(container)
    let project = Project(name: "Draft")
    context.insert(project)
    try context.save()

    let ok = ProjectPersistenceActions.renameProject(
        project,
        to: "  Launch  ",
        projects: [project],
        modelContext: context
    )

    #expect(ok)
    #expect(project.name == "Launch")
}

@Test @MainActor func renameProjectRejectsDuplicateName() throws {
    let container = try makeProjectActionsContainer()
    let context = ModelContext(container)
    let first = Project(name: "Launch")
    let second = Project(name: "Roadmap")
    context.insert(first)
    context.insert(second)
    try context.save()

    let ok = ProjectPersistenceActions.renameProject(
        second,
        to: "launch",
        projects: [first, second],
        modelContext: context
    )

    #expect(!ok)
    #expect(second.name == "Roadmap")
}

@Test @MainActor func archiveProjectPersistsState() throws {
    let container = try makeProjectActionsContainer()
    let context = ModelContext(container)
    let project = Project(name: "Launch")
    context.insert(project)
    try context.save()

    let ok = ProjectPersistenceActions.setArchived(project, archived: true, modelContext: context)

    #expect(ok)
    #expect(project.archived)
}

@Test @MainActor func deleteProjectRemovesProjectAndCascadesCaptures() throws {
    let container = try makeProjectActionsContainer()
    let context = ModelContext(container)
    let project = Project(name: "Launch")
    let capture = Capture(text: "Draft", project: project)
    context.insert(project)
    context.insert(capture)
    try context.save()

    let ok = ProjectPersistenceActions.deleteProject(project, modelContext: context)

    #expect(ok)
    #expect(try context.fetchCount(FetchDescriptor<Project>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Capture>()) == 0)
}
