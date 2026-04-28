import Foundation
import UniformTypeIdentifiers

enum CaptureMediaSelection {
    static func imageURLs(from urls: [URL]) -> [URL] {
        urls.filter(isImageURL)
    }

    static func isImageURL(_ url: URL) -> Bool {
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return contentType.conforms(to: .image)
        }

        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }
}
