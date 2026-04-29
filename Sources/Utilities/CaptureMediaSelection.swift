import Foundation
import UniformTypeIdentifiers

enum CaptureMediaSelection {
    struct Result: Equatable {
        let imageURLs: [URL]
        let rejectedCount: Int
    }

    static func imageURLs(from urls: [URL]) -> [URL] {
        result(from: urls).imageURLs
    }

    static func result(from urls: [URL]) -> Result {
        let imageURLs = urls.filter(isImageURL)
        return Result(imageURLs: imageURLs, rejectedCount: urls.count - imageURLs.count)
    }

    static func isImageURL(_ url: URL) -> Bool {
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return contentType.conforms(to: .image)
        }

        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }
}
