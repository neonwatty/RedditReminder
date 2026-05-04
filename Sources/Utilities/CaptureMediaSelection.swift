import Foundation
import UniformTypeIdentifiers

enum CaptureMediaSelection {
    struct Result: Equatable {
        let mediaURLs: [URL]
        let rejectedCount: Int
    }

    static func mediaURLs(from urls: [URL]) -> [URL] {
        result(from: urls).mediaURLs
    }

    static func imageURLs(from urls: [URL]) -> [URL] {
        mediaURLs(from: urls)
    }

    static func result(from urls: [URL]) -> Result {
        let mediaURLs = urls.filter(isMediaURL)
        return Result(mediaURLs: mediaURLs, rejectedCount: urls.count - mediaURLs.count)
    }

    static func isMediaURL(_ url: URL) -> Bool {
        isImageURL(url) || isVideoURL(url)
    }

    static func isImageURL(_ url: URL) -> Bool {
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return contentType.conforms(to: .image)
        }

        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    static func isVideoURL(_ url: URL) -> Bool {
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return contentType.conforms(to: .movie) || contentType.conforms(to: .video)
        }

        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .movie) || type.conforms(to: .video)
    }
}
