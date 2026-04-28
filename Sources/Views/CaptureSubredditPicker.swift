import SwiftUI

struct CaptureSubredditPicker: View {
    let subreddits: [Subreddit]
    @Binding var selectedSubreddits: Set<UUID>

    var body: some View {
        Menu {
            ForEach(subreddits, id: \.id) { sub in
                Button(action: {
                    if selectedSubreddits.contains(sub.id) {
                        selectedSubreddits.remove(sub.id)
                    } else {
                        selectedSubreddits.insert(sub.id)
                    }
                }) {
                    HStack {
                        Text(sub.name)
                        if selectedSubreddits.contains(sub.id) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                if selectedSubreddits.isEmpty {
                    Text("Select subreddit...")
                        .foregroundStyle(.secondary)
                } else {
                    let names = subreddits
                        .filter { selectedSubreddits.contains($0.id) }
                        .map(\.name)
                        .joined(separator: ", ")
                    Text(names)
                        .foregroundStyle(AppColors.redditOrange)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12))
            .padding(8)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
    }
}
