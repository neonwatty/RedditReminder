import SwiftUI

struct StripView: View {
    let queueCount: Int
    let hasUrgentEvent: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if queueCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color(nsColor: AppColors.reddit))
                        .frame(width: 18, height: 18)
                    Text("\(queueCount)")
                        .font(.system(size: 10, weight: .bold))
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
                .font(.system(size: 9, weight: .medium))
                .tracking(2)
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(90))
                .fixedSize()
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 14)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
