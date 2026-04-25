import SwiftUI

struct StripView: View {
    let queueCount: Int
    let hasUrgentEvent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StickerColors.textSecondary)

                if queueCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color(nsColor: AppColors.reddit))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(StickerColors.border, lineWidth: 2)
                            )
                        Text("\(queueCount)")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }

                if hasUrgentEvent {
                    Circle()
                        .fill(Color(nsColor: AppColors.reddit))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color(nsColor: AppColors.reddit).opacity(0.6), radius: 4)
                }

                Spacer()

                Text("REDDIT")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(StickerColors.textSecondary)
                    .rotationEffect(.degrees(90))
                    .fixedSize()
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
