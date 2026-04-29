import Testing
import SwiftData
@testable import RedditReminder

@Test @MainActor func createProject() throws {
    let container = try makeCRUDContainer()
    let context = ModelContext(container)

    let project = Project(name: "Bullhorn", projectDescription: "Scheduler app", color: "#FF0000")
    context.insert(project)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Project>())
    #expect(fetched.count == 1)
    #expect(fetched[0].name == "Bullhorn")
    #expect(fetched[0].projectDescription == "Scheduler app")
    #expect(fetched[0].color == "#FF0000")
    #expect(fetched[0].archived == false)
}

@Test @MainActor func updateProject() throws {
    let container = try makeCRUDContainer()
    let context = ModelContext(container)

    let project = Project(name: "Original")
    context.insert(project)
    try context.save()

    project.name = "Updated"
    project.archived = true
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Project>())
    #expect(fetched[0].name == "Updated")
    #expect(fetched[0].archived == true)
}

@Test @MainActor func deleteProjectCascadesCaptures() throws {
    let container = try makeCRUDContainer()
    let context = ModelContext(container)

    let project = Project(name: "Doomed")
    context.insert(project)
    let capture = Capture(text: "Will be deleted", project: project)
    context.insert(capture)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Capture>()) == 1)

    context.delete(project)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Project>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Capture>()) == 0)
}

@Test @MainActor func projectCapturesRelationshipBidirectional() throws {
    let container = try makeCRUDContainer()
    let context = ModelContext(container)

    let project = Project(name: "Bullhorn")
    context.insert(project)
    let c1 = Capture(text: "Cap 1", project: project)
    let c2 = Capture(text: "Cap 2", project: project)
    context.insert(c1)
    context.insert(c2)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Project>())
    #expect(fetched[0].captures.count == 2)
}
