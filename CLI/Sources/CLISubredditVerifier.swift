import Foundation

struct SubredditVerificationResult {
  let name: String
  let exists: Bool
  let reachable: Bool
  let statusCode: Int?
  let title: String?
  let subscribers: Int?
  let over18: Bool?

  var dto: SubredditVerificationDTO {
    SubredditVerificationDTO(
      name: name,
      exists: exists,
      reachable: reachable,
      statusCode: statusCode,
      title: title,
      subscribers: subscribers,
      over18: over18)
  }
}

struct SubredditVerifier {
  private let baseURL: URL
  private let session: URLSession

  init(environment: [String: String] = ProcessInfo.processInfo.environment) throws {
    let rawBaseURL = environment["REDDITREMINDER_VERIFY_BASE_URL"] ?? "https://www.reddit.com"
    guard let baseURL = URL(string: rawBaseURL) else {
      throw CLIError.runtime("Invalid REDDITREMINDER_VERIFY_BASE_URL: \(rawBaseURL)")
    }
    self.baseURL = baseURL

    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 10
    configuration.timeoutIntervalForResource = 10
    session = URLSession(configuration: configuration)
  }

  func verify(name: String) async throws -> SubredditVerificationResult {
    let bareName = name.replacing(/^r\//, with: "")
    let url = baseURL
      .appendingPathComponent("r")
      .appendingPathComponent(bareName)
      .appendingPathComponent("about.json")

    var request = URLRequest(url: url)
    request.setValue("RedditReminderCLI/0.1", forHTTPHeaderField: "User-Agent")

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      throw CLIError.runtime("Could not verify subreddit \(name): \(error.localizedDescription)")
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw CLIError.runtime("Could not verify subreddit \(name): non-HTTP response.")
    }

    guard httpResponse.statusCode == 200 else {
      return SubredditVerificationResult(
        name: name,
        exists: false,
        reachable: false,
        statusCode: httpResponse.statusCode,
        title: nil,
        subscribers: nil,
        over18: nil)
    }

    guard
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let payload = root["data"] as? [String: Any]
    else {
      throw CLIError.runtime("Could not parse Reddit verification response for \(name).")
    }

    let displayName = payload["display_name_prefixed"] as? String ?? name
    return SubredditVerificationResult(
      name: displayName,
      exists: true,
      reachable: true,
      statusCode: httpResponse.statusCode,
      title: payload["title"] as? String,
      subscribers: payload["subscribers"] as? Int,
      over18: payload["over18"] as? Bool)
  }
}
