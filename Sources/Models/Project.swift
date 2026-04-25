import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID
    var name: String
    var projectDescription: String?
    var color: String?
    var archived: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Capture.project)
    var captures: [Capture]

    init(
        name: String,
        projectDescription: String? = nil,
        color: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.projectDescription = projectDescription
        self.color = color
        self.archived = false
        self.createdAt = Date()
        self.captures = []
    }
}
