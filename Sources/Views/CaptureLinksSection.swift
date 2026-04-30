import SwiftUI

struct CaptureLinksSection: View {
  @Binding var links: [String]
  @Binding var newLinkText: String

  var body: some View {
    FlowLayout(spacing: 6) {
      ForEach(Array(links.enumerated()), id: \.element) { index, link in
        LinkChipView(
          url: link,
          onRemove: {
            links.remove(at: index)
          })
      }

      HStack(spacing: 4) {
        TextField("Add link...", text: $newLinkText)
          .font(.system(size: 10))
          .textFieldStyle(.plain)
          .frame(width: 120)
          .onSubmit { addLink() }
          .accessibilityLabel("Add capture link")
          .accessibilityIdentifier("captureWindow.links.newLink")

        if !newLinkText.isEmpty {
          Button(action: addLink) {
            Image(systemName: "plus.circle.fill")
              .font(.system(size: 12))
              .foregroundStyle(AppColors.redditOrange)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Add link")
          .accessibilityIdentifier("captureWindow.links.add")
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(Color(NSColor.separatorColor), style: StrokeStyle(lineWidth: 0.5, dash: [4]))
      )
    }
  }

  private func addLink() {
    guard let normalized = CaptureHelpers.normalizeLink(newLinkText) else { return }
    links.append(normalized)
    newLinkText = ""
  }
}
