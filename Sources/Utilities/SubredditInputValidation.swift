import Foundation

struct SubredditInputValidation: Equatable {
    enum Feedback: Equatable {
        case error(String)
        case preview(String)
    }

    let canAdd: Bool
    let feedback: Feedback?

    @MainActor
    static func evaluate(_ input: String, subreddits: [Subreddit]) -> SubredditInputValidation {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SubredditInputValidation(canAdd: false, feedback: nil)
        }

        switch SubredditName.normalize(input) {
        case .failure(let error):
            return SubredditInputValidation(canAdd: false, feedback: .error(error.message))
        case .success(let name):
            guard SubredditPersistenceActions.isNameAvailable(name, subreddits: subreddits) else {
                return SubredditInputValidation(canAdd: false, feedback: .error(SubredditName.ValidationError.duplicate.message))
            }
            return SubredditInputValidation(canAdd: true, feedback: .preview("Will add \(name)"))
        }
    }
}
